"""
Cursor agent integration and invocation
"""

import logging
import subprocess
from pathlib import Path

from .config import Config
from .github_client import GithubClient
from .thread_manager import ThreadManager

logger = logging.getLogger(__name__)


class AgentClient:
    """Handles Cursor agent invocation and git operations"""

    def __init__(
        self, config: Config, thread_manager: ThreadManager, github: GithubClient
    ) -> None:
        """
        Initialize agent client

        Args:
            config: Application configuration
            thread_manager: Thread manager instance
            github: GitHub client instance
        """
        self.config = config
        self.thread_manager = thread_manager
        self.github = github

    def _get_model_for_mode(self, command: str) -> str:
        """
        Get the appropriate model for the given command mode

        Args:
            command: Command type ('ask', 'plan', 'implement')

        Returns:
            Model name to use
        """
        models = {
            "ask": self.config.cursor_model_ask,
            "plan": self.config.cursor_model_plan,
            "implement": self.config.cursor_model_implement,
        }
        return models.get(command, self.config.cursor_model_fallback)

    def invoke_agent(
        self, pr_number: int, thread_id: str, command: str, context: str
    ) -> tuple[str, int]:
        """
        Invoke Cursor agent with given context

        Args:
            pr_number: Pull request number
            thread_id: Thread identifier
            command: Command type ('ask', 'plan', 'implement')
            context: Full context markdown (used for new sessions or fallback)

        Returns:
            Tuple of (response, status_code)
            status_code: 0=success, 1=failure, 2=manual intervention needed
        """
        work_dir = self.config.log_dir / f".agent-work-{thread_id}"
        work_dir.mkdir(parents=True, exist_ok=True)

        # Save full context (for debugging/fallback)
        context_file = work_dir / "context.md"
        context_file.write_text(context)

        # Get PR branch and checkout
        try:
            pr_metadata = self.github.get_pr_metadata(pr_number)
            branch = pr_metadata.branch
            self.checkout_pr_branch(branch)
        except Exception as e:
            logger.error(f"Failed to checkout PR branch: {e}")
            return f"Failed to checkout branch: {e}", 1

        # Build instructions
        is_new_session = not self.thread_manager.get_session_id(thread_id)
        instructions = self.build_instructions(pr_number, thread_id, command, branch, is_new_session)
        instructions_file = work_dir / "instructions.md"
        instructions_file.write_text(instructions)

        # Save request metadata
        import json

        request_data = {
            "pr_number": pr_number,
            "thread_id": thread_id,
            "command": command,
            "branch": branch,
            "timestamp": str(self.thread_manager.load_thread(thread_id).created_at)
            if self.thread_manager.load_thread(thread_id)
            else "",
        }
        request_file = work_dir / "agent-request.json"
        request_file.write_text(json.dumps(request_data, indent=2))

        # Check if we have an existing session
        session_id = self.thread_manager.get_session_id(thread_id)

        # Determine context to use based on session existence
        if session_id:
            # Resuming session - use minimal context (just new message)
            logger.info("Resuming session - using minimal context (new message only)")
            thread = self.thread_manager.load_thread(thread_id)
            if thread and thread.messages:
                # Get the last user message (the new one just added)
                last_message = thread.messages[-1]
                if last_message.role == "user":
                    minimal_context = f"New request from {last_message.author}:\n\n{last_message.content}"
                    if last_message.location:
                        minimal_context = f"**Location**: `{last_message.location}`\n\n" + minimal_context
                    if last_message.code_snippet:
                        minimal_context += f"\n\n```\n{last_message.code_snippet}\n```"
                    context_to_use = minimal_context
                else:
                    # Fallback to full context if last message isn't from user
                    logger.warning("Last message is not from user, using full context")
                    context_to_use = context
            else:
                # Fallback to full context if can't get thread
                logger.warning("Could not load thread, using full context")
                context_to_use = context
        else:
            # New session - use full context
            logger.info("Creating new session - using full context")
            context_to_use = context

        # Try to invoke Cursor CLI
        logger.info(f"Invoking Cursor agent in '{command}' mode")

        # Combine instructions and context
        combined_prompt = f"# Instructions\n\n{instructions}\n\n---\n\n# Context\n\n{context_to_use}"
        combined_file = work_dir / "combined-prompt.md"
        combined_file.write_text(combined_prompt)

        response = ""
        status = 0

        if session_id:
            logger.info(f"Attempting to resume session: {session_id}")
            try:
                response = self._resume_session(session_id, combined_file, command)
                logger.info("Session resumed successfully")
                response_file = work_dir / "agent-response.txt"
                response_file.write_text(f"SUCCESS: {response}")
                return response, 0
            except Exception as e:
                logger.warning(f"Session resume failed: {e}, creating new session with full context")
                # Rebuild with full context for fallback
                combined_prompt = f"# Instructions\n\n{instructions}\n\n---\n\n# Context\n\n{context}"
                combined_file.write_text(combined_prompt)

        # Create new session
        try:
            response, new_session_id = self._create_new_session(combined_file, command)
            if new_session_id:
                self.thread_manager.store_session_id(thread_id, new_session_id)
            logger.info("Cursor agent completed successfully")
            response_file = work_dir / "agent-response.txt"
            response_file.write_text(f"SUCCESS: {response}")
            return response, 0
        except subprocess.CalledProcessError as e:
            error_output = e.stderr if e.stderr else e.stdout if e.stdout else str(e)

            # Check for specific errors and provide detailed diagnostics
            if "resource_exhausted" in str(error_output).lower():
                logger.error("Cursor API quota exhausted or rate limited")
                error_msg = (
                    "Cursor API quota exhausted or rate limited.\n"
                    "Solutions:\n"
                    "- Wait for quota to reset\n"
                    "- Upgrade your Cursor plan\n"
                    "- Check API key configuration"
                )
            elif "authentication" in str(error_output).lower() or "unauthorized" in str(error_output).lower():
                logger.error("Cursor authentication failed")
                error_msg = (
                    "Cursor authentication failed.\n"
                    "Solutions:\n"
                    "- Verify CURSOR_API_KEY environment variable is set\n"
                    "- Check API key is valid: cursor auth status\n"
                    "- Re-authenticate: cursor auth login"
                )
            elif "not found" in str(error_output).lower() or "no such file" in str(error_output).lower():
                logger.error("Cursor CLI or files not found")
                error_msg = (
                    "Cursor CLI or required files not found.\n"
                    "Solutions:\n"
                    "- Install Cursor CLI: https://cursor.sh/cli\n"
                    "- Verify cursor is in PATH: which cursor\n"
                    "- Check file permissions"
                )
            else:
                logger.error(f"Cursor invocation failed: {error_output}")
                error_msg = (
                    f"Cursor CLI error:\n{error_output}\n\n"
                    f"Check logs for details: {work_dir}"
                )

            response_file = work_dir / "agent-response.txt"
            response_file.write_text(f"FAILED: {error_msg}")
            return error_msg, 1
        except FileNotFoundError as e:
            # Cursor CLI not installed or not in PATH
            logger.error(f"Cursor CLI not found: {e}")
            error_msg = (
                "Cursor CLI not found in PATH.\n"
                "Installation required:\n"
                "1. Install Cursor: https://cursor.sh\n"
                "2. Install CLI: cursor --install-cli\n"
                "3. Verify: cursor --version\n"
                f"4. See instructions: {instructions_file}"
            )
            response_file = work_dir / "agent-response.txt"
            response_file.write_text("PENDING_MANUAL_INVOCATION")
            return error_msg, 2
        except PermissionError as e:
            # Permission issues with files or Cursor CLI
            logger.error(f"Permission error: {e}")
            error_msg = (
                "Permission denied when invoking Cursor CLI.\n"
                "Solutions:\n"
                "- Check file permissions on cursor executable\n"
                "- Verify write permissions in work directory\n"
                f"- Work directory: {work_dir}\n"
                f"- See instructions: {instructions_file}"
            )
            response_file = work_dir / "agent-response.txt"
            response_file.write_text("PENDING_MANUAL_INVOCATION")
            return error_msg, 2
        except Exception as e:
            # Catch-all for unexpected errors
            logger.error(f"Unexpected error during Cursor invocation: {e}", exc_info=True)
            import traceback
            error_details = traceback.format_exc()

            error_msg = (
                f"Unexpected error occurred:\n{str(e)}\n\n"
                f"Error type: {type(e).__name__}\n"
                f"Work directory: {work_dir}\n"
                f"Instructions: {instructions_file}\n"
                f"Context: {context_file}\n\n"
                f"Full traceback saved to logs."
            )

            # Save detailed error to file
            error_file = work_dir / "error.log"
            error_file.write_text(f"Error: {str(e)}\n\nTraceback:\n{error_details}")

            response_file = work_dir / "agent-response.txt"
            response_file.write_text("PENDING_MANUAL_INVOCATION")
            return error_msg, 2

    def checkout_pr_branch(self, branch: str) -> None:
        """
        Checkout PR branch

        Args:
            branch: Branch name
        """
        try:
            # Fetch and checkout
            subprocess.run(
                ["git", "fetch", "origin", branch], check=True, capture_output=True
            )
            subprocess.run(
                ["git", "checkout", branch], check=True, capture_output=True
            )
            subprocess.run(
                ["git", "pull", "origin", branch], check=True, capture_output=True
            )
            logger.info(f"Checked out branch: {branch}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Git checkout failed: {e.stderr.decode()}")
            raise

    def build_instructions(
        self, pr_number: int, thread_id: str, command: str, branch: str, is_new_session: bool = True
    ) -> str:
        """
        Build instructions from templates

        Args:
            pr_number: Pull request number
            thread_id: Thread identifier
            command: Command type
            branch: Branch name
            is_new_session: Whether this is a new session (include header) or resumed (skip header)

        Returns:
            Formatted instructions
        """
        import datetime

        template_dir = self.config.template_dir
        timestamp = datetime.datetime.utcnow().isoformat() + "Z"

        # Read templates
        parts = []

        # Only include header for new sessions
        template_names = (
            ["instructions-header.md", f"instructions-{command}.md"]
            if is_new_session
            else [f"instructions-{command}.md"]
        )

        for template_name in template_names:
            template_file = template_dir / template_name
            if template_file.exists():
                content = template_file.read_text()

                # Replace placeholders
                content = content.replace("{{PR_NUMBER}}", str(pr_number))
                content = content.replace("{{THREAD_ID}}", thread_id)
                content = content.replace("{{BRANCH}}", branch)
                content = content.replace("{{MODE}}", command)
                content = content.replace("{{TIMESTAMP}}", timestamp)

                parts.append(content)
            else:
                logger.warning(f"Template not found: {template_name}")

        return "\n\n".join(parts)

    def _resume_session(self, session_id: str, prompt_file: Path, command: str) -> str:
        """
        Resume existing Cursor session with mode-specific model

        Args:
            session_id: Cursor session ID
            prompt_file: File containing prompt
            command: Command type ('ask', 'plan', 'implement')

        Returns:
            Agent response
        """
        logger.info(f"Resuming Cursor session: {session_id}")
        model = self._get_model_for_mode(command)
        logger.info(f"Using model for '{command}' mode: {model}")

        cmd = [
            "cursor",
            "agent",
            "--resume",
            session_id,
            "--print",
            "--output-format",
            "text",
            "--model",
            model,
            "--force",
        ]

        # Add API key if configured
        if self.config.cursor_api_key:
            cmd.extend(["--api-key", self.config.cursor_api_key])

        result = subprocess.run(
            cmd,
            stdin=open(prompt_file, "r"),
            capture_output=True,
            text=True,
            check=True,
        )

        response = result.stdout.strip()
        logger.debug(f"Resume session response length: {len(response)} chars")
        return response

    def _create_new_session(self, prompt_file: Path, command: str) -> tuple[str, str | None]:
        """
        Create new Cursor session with mode-specific model

        Args:
            prompt_file: File containing prompt
            command: Command type ('ask', 'plan', 'implement')

        Returns:
            Tuple of (response, session_id)
        """
        # Step 1: Create a new chat session to get session ID
        logger.info("Creating new Cursor chat session")
        create_cmd = ["cursor", "agent", "create-chat"]

        # Add API key if configured
        if self.config.cursor_api_key:
            create_cmd.extend(["--api-key", self.config.cursor_api_key])

        try:
            create_result = subprocess.run(
                create_cmd,
                capture_output=True,
                text=True,
                check=True,
            )
            session_id = create_result.stdout.strip()
            logger.info(f"Created new session: {session_id}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create chat session: {e}")
            raise

        # Step 2: Send the initial message using the new session
        logger.info(f"Sending initial message to session {session_id}")
        model = self._get_model_for_mode(command)
        logger.info(f"Using model for '{command}' mode: {model}")

        resume_cmd = [
            "cursor",
            "agent",
            "--resume",
            session_id,
            "--print",
            "--output-format",
            "text",
            "--model",
            model,
            "--force",
        ]

        # Add API key if configured
        if self.config.cursor_api_key:
            resume_cmd.extend(["--api-key", self.config.cursor_api_key])

        result = subprocess.run(
            resume_cmd,
            stdin=open(prompt_file, "r"),
            capture_output=True,
            text=True,
            check=True,
        )

        response = result.stdout.strip()
        logger.debug(f"New session response length: {len(response)} chars")

        return response, session_id

    def update_pr_description(self, pr_number: int, changes_summary: str) -> bool:
        """
        Update PR description with changes summary

        Args:
            pr_number: Pull request number
            changes_summary: Summary of changes

        Returns:
            True if successful
        """
        try:
            pr_metadata = self.github.get_pr_metadata(pr_number)
            current_body = pr_metadata.body

            # Remove old automated section
            import re

            current_body = re.sub(
                r"---\s*## Automated Changes.*", "", current_body, flags=re.DOTALL
            )

            # Get recent commits
            try:
                result = subprocess.run(
                    ["git", "log", "origin/main..HEAD", "--oneline", "--no-decorate"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                commits = result.stdout.strip()
            except Exception:
                commits = "Unable to fetch commits"

            # Build new section
            import datetime

            timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

            changes_section = f"""

---

## Automated Changes

### Recent Commits
{commits}

### Summary
{changes_summary}

**Last Updated**: {timestamp}
**Status**: ✅ Changes committed and pushed
"""

            new_body = current_body.strip() + changes_section

            # Update via GitHub API
            repo = self.github.repo
            pr = repo.get_pull(pr_number)
            pr.edit(body=new_body)

            logger.info(f"Updated PR #{pr_number} description")
            return True

        except Exception as e:
            logger.error(f"Failed to update PR description: {e}")
            return False

