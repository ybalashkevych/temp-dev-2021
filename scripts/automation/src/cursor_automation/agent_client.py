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

    def invoke_agent(
        self, pr_number: int, thread_id: str, command: str, context: str
    ) -> tuple[str, int]:
        """
        Invoke Cursor agent with given context

        Args:
            pr_number: Pull request number
            thread_id: Thread identifier
            command: Command type ('ask', 'plan', 'implement')
            context: Context markdown

        Returns:
            Tuple of (response, status_code)
            status_code: 0=success, 1=failure, 2=manual intervention needed
        """
        work_dir = self.config.log_dir / f".agent-work-{thread_id}"
        work_dir.mkdir(parents=True, exist_ok=True)

        # Save context
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
        instructions = self.build_instructions(pr_number, thread_id, command, branch)
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

        # Try to invoke Cursor CLI
        logger.info(f"Invoking Cursor agent in '{command}' mode")

        # Combine instructions and context
        combined_prompt = f"# Instructions\n\n{instructions}\n\n---\n\n# Context\n\n{context}"
        combined_file = work_dir / "combined-prompt.md"
        combined_file.write_text(combined_prompt)

        # Try session resumption first
        session_id = self.thread_manager.get_session_id(thread_id)
        response = ""
        status = 0

        if session_id:
            logger.info(f"Attempting to resume session: {session_id}")
            try:
                response = self._resume_session(session_id, combined_file)
                logger.info("Session resumed successfully")
                response_file = work_dir / "agent-response.txt"
                response_file.write_text(f"SUCCESS: {response}")
                return response, 0
            except Exception as e:
                logger.warning(f"Session resume failed: {e}, creating new session")

        # Create new session
        try:
            response, new_session_id = self._create_new_session(combined_file)
            if new_session_id:
                self.thread_manager.store_session_id(thread_id, new_session_id)
            logger.info("Cursor agent completed successfully")
            response_file = work_dir / "agent-response.txt"
            response_file.write_text(f"SUCCESS: {response}")
            return response, 0
        except subprocess.CalledProcessError as e:
            error_output = e.stderr if e.stderr else e.stdout if e.stdout else str(e)
            
            # Check for specific errors
            if "resource_exhausted" in str(error_output).lower():
                logger.error("Cursor API quota exhausted or rate limited")
                error_msg = "Cursor API quota exhausted. Please wait or upgrade your plan."
            else:
                logger.error(f"Cursor invocation failed: {error_output}")
                error_msg = f"Cursor CLI error: {error_output}"
            
            response_file = work_dir / "agent-response.txt"
            response_file.write_text(f"FAILED: {error_msg}")
            return error_msg, 1
        except Exception as e:
            logger.error(f"Cursor invocation failed: {e}")
            response_file = work_dir / "agent-response.txt"
            response_file.write_text("PENDING_MANUAL_INVOCATION")
            return f"Manual invocation required. See: {instructions_file}", 2

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
        self, pr_number: int, thread_id: str, command: str, branch: str
    ) -> str:
        """
        Build instructions from templates

        Args:
            pr_number: Pull request number
            thread_id: Thread identifier
            command: Command type
            branch: Branch name

        Returns:
            Formatted instructions
        """
        import datetime

        template_dir = self.config.template_dir
        timestamp = datetime.datetime.utcnow().isoformat() + "Z"

        # Read templates
        parts = []

        for template_name in [
            "instructions-header.md",
            f"instructions-{command}.md",
            "instructions-footer.md",
        ]:
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

    def _resume_session(self, session_id: str, prompt_file: Path) -> str:
        """
        Resume existing Cursor session

        Args:
            session_id: Cursor session ID
            prompt_file: File containing prompt

        Returns:
            Agent response
        """
        cmd = [
            "cursor",
            "agent",
            "--session",
            session_id,
            "--resume",
            "--print",
            "--model",
            self.config.cursor_model,
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

        return result.stdout.strip()

    def _create_new_session(self, prompt_file: Path) -> tuple[str, str | None]:
        """
        Create new Cursor session

        Args:
            prompt_file: File containing prompt

        Returns:
            Tuple of (response, session_id)
        """
        cmd = [
            "cursor",
            "agent",
            "--print",
            "--model",
            self.config.cursor_model,
            "--output-format",
            "text",
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

        # Try to extract session ID from output
        import re

        session_match = re.search(r"Session[:\s]+([a-zA-Z0-9-]+)", response)
        session_id = session_match.group(1) if session_match else None

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

