"""
Main daemon for monitoring PRs and processing feedback
"""

import logging
import signal
import sys
import time
from datetime import datetime

from .config import Config
from .agent_client import AgentClient
from .github_client import GithubClient
from .models import Comment, Message
from .thread_manager import ThreadManager
from .utils import clean_comment_body, parse_command

logger = logging.getLogger(__name__)


class CursorDaemon:
    """Background daemon that monitors GitHub PRs for feedback"""

    def __init__(self, config: Config) -> None:
        """
        Initialize daemon

        Args:
            config: Application configuration
        """
        self.config = config
        self.github = GithubClient(config)
        self.thread_manager = ThreadManager(config)
        self.agent = AgentClient(config, self.thread_manager, self.github)
        self.running = True

        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._handle_shutdown)
        signal.signal(signal.SIGINT, self._handle_shutdown)

    def _handle_shutdown(self, signum: int, frame: object) -> None:
        """Handle shutdown signals"""
        logger.info("Received shutdown signal")
        self.running = False

    def run(self) -> None:
        """Main monitoring loop"""
        logger.info("=" * 50)
        logger.info("Cursor Automation Daemon Starting")
        logger.info("=" * 50)
        logger.info(f"Repository: {self.config.repo_owner}/{self.config.repo_name}")
        logger.info(f"Poll interval: {self.config.poll_interval}s")
        logger.info(f"Process ID: {os.getpid()}")
        logger.info("")

        iteration = 0

        while self.running:
            iteration += 1
            logger.info(f"=== Check #{iteration} ===")

            try:
                self.process_all_prs()
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}", exc_info=True)

            if self.running:
                logger.info(f"Sleeping for {self.config.poll_interval}s...")
                logger.info("")
                time.sleep(self.config.poll_interval)

        logger.info("Daemon stopped")

    def process_all_prs(self) -> None:
        """Get and process all PRs awaiting cursor response"""
        prs = self.github.get_prs_with_label("awaiting-cursor-response")

        if not prs:
            logger.info("No PRs awaiting response")
            return

        logger.info(f"Found {len(prs)} PR(s) awaiting response")

        for pr_number in prs:
            try:
                self.process_pr(pr_number)
            except Exception as e:
                logger.error(f"Error processing PR #{pr_number}: {e}", exc_info=True)

    def process_pr(self, pr_number: int) -> None:
        """
        Process all unprocessed feedback in a PR

        Args:
            pr_number: Pull request number
        """
        logger.info(f"Processing PR #{pr_number}...")

        comments = self.github.get_pr_comments(pr_number)

        unprocessed = [
            c
            for c in comments
            if not self.github.has_processed_reactions(c.id, c.type)
        ]

        if not unprocessed:
            logger.info(f"No unprocessed feedback in PR #{pr_number}")
            return

        logger.info(f"Found {len(unprocessed)} unprocessed comment(s)")

        for comment in unprocessed:
            try:
                self.process_comment(pr_number, comment)
            except Exception as e:
                logger.error(
                    f"Error processing comment {comment.id}: {e}", exc_info=True
                )

    def process_comment(self, pr_number: int, comment: Comment) -> None:
        """
        Process a single comment/feedback

        Args:
            pr_number: Pull request number
            comment: Comment object
        """
        # Parse command and clean body
        command = parse_command(comment.body)
        cleaned_body = clean_comment_body(comment.body)

        logger.info(
            f"Processing comment {comment.id} from {comment.author} (command: {command})"
        )

        # Add 👀 reaction (guard against re-processing)
        self.github.add_reaction(comment.id, comment.type, "eyes")

        # Get or create thread (reuse parent thread if this is a reply)
        thread = self.thread_manager.get_or_create_thread(
            pr_number, comment.id, comment.in_reply_to_id
        )
        logger.info(f"Using thread: {thread.thread_id}")

        # Extract code snippet if location provided
        code_snippet = ""
        function_name = ""
        if comment.location:
            parts = comment.location.split(":")
            file_path = ""
            line_num = None
            end_line = None
            
            if len(parts) == 2:
                # Format: file:line
                file_path, line_str = parts
                try:
                    line_num = int(line_str)
                except ValueError:
                    pass
            elif len(parts) >= 3:
                # Format could be: startLine:endLine:file or file:startLine:endLine
                # Try: startLine:endLine:file (both first parts are digits)
                if parts[0].isdigit() and parts[1].isdigit():
                    try:
                        line_num = int(parts[0])
                        end_line = int(parts[1])
                        file_path = ":".join(parts[2:])  # Re-join path in case it has colons
                    except (ValueError, IndexError):
                        pass
                else:
                    # Format: file:startLine:endLine
                    try:
                        file_path = parts[0]
                        line_num = int(parts[1])
                        if len(parts) > 2:
                            end_line = int(parts[2])
                    except (ValueError, IndexError):
                        pass
            
            if file_path and line_num:
                code_snippet, function_name = (
                    self.thread_manager.extract_code_snippet(file_path, line_num, end_line=end_line)
                )

        # Add user message to thread
        user_message = Message(
            role="user",
            author=comment.author,
            content=cleaned_body,
            location=comment.location,
            code_snippet=code_snippet,
            function_name=function_name,
            timestamp=datetime.utcnow(),
        )
        self.thread_manager.add_message(thread.thread_id, user_message)

        # Build context and invoke agent
        pr_metadata = self.github.get_pr_metadata(pr_number)
        context = self.thread_manager.build_context(pr_metadata, thread.thread_id)

        logger.info(f"Invoking agent in '{command}' mode...")
        response, status = self.agent.invoke_agent(
            pr_number, thread.thread_id, command, context
        )

        if status == 0:
            logger.info("Agent completed successfully")

            # Add agent response to thread
            agent_message = Message(
                role="assistant",
                author="cursor-agent",
                content=response,
                location="",
                timestamp=datetime.utcnow(),
            )
            self.thread_manager.add_message(thread.thread_id, agent_message)

            # Post response to PR (reply to thread for inline comments)
            response_text = self._format_response(command, response)
            
            # Reply to inline comment threads, or post PR-level for regular comments
            if comment.type == "review":
                # Inline comment - reply in the same thread
                agent_comment_id = self.github.post_reply(pr_number, comment.id, response_text)
                logger.info(f"Posted reply to inline comment thread: {agent_comment_id}")
            else:
                # PR-level comment
                agent_comment_id = self.github.post_comment(pr_number, response_text)
                logger.info(f"Posted PR-level comment: {agent_comment_id}")

            if agent_comment_id:
                # Mark agent response as processed to prevent re-processing
                self.github.add_reaction(agent_comment_id, comment.type, "eyes")
                self.github.add_reaction(agent_comment_id, comment.type, "rocket")

            # Mark original comment as fully processed
            self.github.add_reaction(comment.id, comment.type, "rocket")

            # Update thread status
            self.thread_manager.set_thread_status(thread.thread_id, "completed")

        elif status == 2:
            # Manual intervention needed
            logger.warning("Agent requires manual intervention")
            
            # Add warning reaction (not failure)
            self.github.add_reaction(comment.id, comment.type, "confused")

            # Build helpful manual intervention message
            work_dir = self.config.log_dir / f".agent-work-{thread.thread_id}"
            instructions_file = work_dir / "instructions.md"
            context_file = work_dir / "context.md"
            
            manual_msg = (
                f"⚠️ **Manual Intervention Required**\n\n"
                f"The Cursor agent could not be invoked automatically. This typically happens when:\n\n"
                f"- Cursor CLI is not available or not configured\n"
                f"- API quota/rate limits have been reached\n"
                f"- Authentication issues with Cursor API\n"
                f"- Unexpected Cursor CLI errors\n\n"
                f"**Thread**: `{thread.thread_id}`\n\n"
                f"**To complete this request manually:**\n\n"
                f"1. Review the instructions: `{instructions_file}`\n"
                f"2. Review the full context: `{context_file}`\n"
                f"3. Complete the request in Cursor IDE\n"
                f"4. Reply to this comment with your response\n\n"
                f"**Error details:**\n```\n{response}\n```\n\n"
                f"**Troubleshooting:**\n"
                f"- Check Cursor CLI: `cursor --version`\n"
                f"- Verify API key: `echo $CURSOR_API_KEY`\n"
                f"- Check logs: `{self.config.log_dir}`\n\n"
                f"*Once resolved, use `@ybalashkevych {command}` to retry*"
            )
            
            # Reply in-thread for review comments, PR-level for others
            if comment.type == "review":
                agent_comment_id = self.github.post_reply(pr_number, comment.id, manual_msg)
            else:
                agent_comment_id = self.github.post_comment(pr_number, manual_msg)
            
            # Add reactions to bot comment to mark as processed
            if agent_comment_id:
                self.github.add_reaction(agent_comment_id, comment.type, "eyes")
                self.github.add_reaction(agent_comment_id, comment.type, "rocket")
            
            # Mark original comment as processed as well
            self.github.add_reaction(comment.id, comment.type, "rocket")

            # Update thread status to pending (not failed - can be retried)
            self.thread_manager.set_thread_status(thread.thread_id, "pending")

        else:
            # Hard failure (status == 1)
            logger.error("Agent failed to process feedback")
            # Add failure reaction
            self.github.add_reaction(comment.id, comment.type, "-1")

            # Mark as processed to prevent retry loops (add rocket)
            self.github.add_reaction(comment.id, comment.type, "rocket")

            # Post failure message with error details
            failure_msg = (
                f"❌ **Processing Failed**\n\n"
                f"Thread: `{thread.thread_id}`\n\n"
                f"**Error:**\n```\n{response}\n```\n\n"
                f"Check logs for more details: `{self.config.log_dir}`\n\n"
                f"*This error has been marked as processed. If you want to retry, "
                f"please investigate the error first, then use `@ybalashkevych {command}` in a new comment.*"
            )
            
            # Reply in-thread for review comments, PR-level for others
            if comment.type == "review":
                agent_comment_id = self.github.post_reply(pr_number, comment.id, failure_msg)
            else:
                agent_comment_id = self.github.post_comment(pr_number, failure_msg)
            
            # Add reactions to bot comment to mark as processed
            if agent_comment_id:
                self.github.add_reaction(agent_comment_id, comment.type, "eyes")
                self.github.add_reaction(agent_comment_id, comment.type, "rocket")

            # Update thread status
            self.thread_manager.set_thread_status(thread.thread_id, "failed")

    def _format_response(self, command: str, response: str) -> str:
        """
        Format agent response based on command type

        Args:
            command: Command type
            response: Agent response

        Returns:
            Formatted response text
        """
        if command == "ask":
            return (
                f"🤔 **Questions & Clarifications**\n\n"
                f"{response}\n\n"
                f"---\n"
                f"*Reply with answers or use `@ybalashkevych plan` to see implementation plan*"
            )
        elif command == "plan":
            return (
                f"📋 **Implementation Plan**\n\n"
                f"{response}\n\n"
                f"---\n"
                f"*Use `@ybalashkevych implement` to proceed with changes*"
            )
        elif command == "implement":
            return (
                f"✅ **Changes Implemented**\n\n"
                f"{response}\n\n"
                f"---\n"
                f"*Changes have been committed and pushed. Ready for review.*"
            )
        else:
            return response


import os

