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

        # Get or create thread
        thread = self.thread_manager.get_or_create_thread(pr_number, comment.id)
        logger.info(f"Using thread: {thread.thread_id}")

        # Extract code snippet if location provided
        code_snippet = ""
        function_name = ""
        if comment.location:
            parts = comment.location.split(":")
            if len(parts) == 2:
                file_path, line_str = parts
                try:
                    line_num = int(line_str)
                    code_snippet, function_name = (
                        self.thread_manager.extract_code_snippet(file_path, line_num)
                    )
                except ValueError:
                    pass

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
                # Add success reactions (use same type as original comment)
                self.github.add_reaction(agent_comment_id, comment.type, "rocket")
                self.github.add_reaction(agent_comment_id, comment.type, "+1")

            # Mark original comment as fully processed
            self.github.add_reaction(comment.id, comment.type, "rocket")

            # Update thread status
            self.thread_manager.set_thread_status(thread.thread_id, "completed")

        else:
            logger.error("Agent failed to process feedback")
            # Add failure reaction
            self.github.add_reaction(comment.id, comment.type, "-1")

            # Mark as processed to prevent retry loops (add rocket)
            self.github.add_reaction(comment.id, comment.type, "rocket")

            # Post failure message
            failure_msg = (
                f"❌ **Processing Failed**\n\n"
                f"Thread: `{thread.thread_id}`\n"
                f"Please check the logs for details."
            )
            self.github.post_comment(pr_number, failure_msg)

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

