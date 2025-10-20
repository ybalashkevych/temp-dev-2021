"""
Thread and conversation management
"""

import json
import logging
import re
import time
from pathlib import Path

from .config import Config
from .models import AutomationState, Message, PRMetadata, Thread

logger = logging.getLogger(__name__)


class ThreadManager:
    """Manages conversation threads and state persistence"""

    def __init__(self, config: Config) -> None:
        """
        Initialize thread manager

        Args:
            config: Application configuration
        """
        self.config = config
        self.log_dir = config.log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.state_file = self.log_dir / "automation-state.json"
        self._load_state()

    def _load_state(self) -> None:
        """Load automation state from disk"""
        if self.state_file.exists():
            try:
                with open(self.state_file, "r") as f:
                    data = json.load(f)
                self.state = AutomationState(**data)
                logger.debug(f"Loaded state from {self.state_file}")
            except Exception as e:
                logger.warning(f"Failed to load state, initializing new: {e}")
                self.state = AutomationState()
        else:
            self.state = AutomationState()
            self._save_state()

    def _save_state(self) -> None:
        """Save automation state to disk"""
        try:
            with open(self.state_file, "w") as f:
                json.dump(self.state.model_dump(), f, indent=2)
            logger.debug("Saved state to disk")
        except Exception as e:
            logger.error(f"Failed to save state: {e}")

    def get_thread_file(self, thread_id: str) -> Path:
        """
        Get path to thread JSON file

        Args:
            thread_id: Thread identifier

        Returns:
            Path to thread file
        """
        return self.log_dir / f"{thread_id}.json"

    def load_thread(self, thread_id: str) -> Thread | None:
        """
        Load thread from disk

        Args:
            thread_id: Thread identifier

        Returns:
            Thread object or None if not found
        """
        thread_file = self.get_thread_file(thread_id)
        if not thread_file.exists():
            return None

        try:
            with open(thread_file, "r") as f:
                data = json.load(f)
            thread = Thread(**data)
            logger.debug(f"Loaded thread {thread_id}")
            return thread
        except Exception as e:
            logger.error(f"Failed to load thread {thread_id}: {e}")
            return None

    def save_thread(self, thread: Thread) -> None:
        """
        Save thread to disk

        Args:
            thread: Thread to save
        """
        thread_file = self.get_thread_file(thread.thread_id)
        try:
            with open(thread_file, "w") as f:
                json.dump(thread.model_dump(), f, indent=2, default=str)
            logger.debug(f"Saved thread {thread.thread_id}")
        except Exception as e:
            logger.error(f"Failed to save thread {thread.thread_id}: {e}")

    def get_thread_for_comment(self, comment_id: int) -> str | None:
        """
        Get thread ID associated with a comment

        Args:
            comment_id: Comment ID

        Returns:
            Thread ID or None
        """
        return self.state.comment_to_thread.get(str(comment_id))

    def get_or_create_thread(self, pr_number: int, comment_id: int) -> Thread:
        """
        Get existing thread or create new one for a comment

        Args:
            pr_number: Pull request number
            comment_id: Comment ID

        Returns:
            Thread object
        """
        # Check if comment already has a thread
        existing_thread_id = self.get_thread_for_comment(comment_id)
        if existing_thread_id:
            thread = self.load_thread(existing_thread_id)
            if thread:
                logger.debug(f"Using existing thread: {existing_thread_id}")
                return thread

        # Create new thread
        timestamp = int(time.time())
        thread_id = f"pr-{pr_number}-thread-{timestamp}"

        thread = Thread(thread_id=thread_id, pr_number=pr_number)

        # Register in state
        self.state.comment_to_thread[str(comment_id)] = thread_id
        self.state.threads[thread_id] = {
            "pr_number": pr_number,
            "created_at": thread.created_at.isoformat(),
            "status": "active",
        }
        self._save_state()

        # Save thread file
        self.save_thread(thread)

        logger.info(f"Created new thread: {thread_id}")
        return thread

    def add_message(self, thread_id: str, message: Message) -> None:
        """
        Add message to thread

        Args:
            thread_id: Thread identifier
            message: Message to add
        """
        thread = self.load_thread(thread_id)
        if not thread:
            logger.error(f"Thread {thread_id} not found")
            return

        thread.messages.append(message)
        self.save_thread(thread)
        logger.debug(f"Added message from {message.author} to thread {thread_id}")

    def get_session_id(self, thread_id: str) -> str | None:
        """
        Get Cursor session ID for thread

        Args:
            thread_id: Thread identifier

        Returns:
            Session ID or None
        """
        thread = self.load_thread(thread_id)
        return thread.cursor_session_id if thread else None

    def store_session_id(self, thread_id: str, session_id: str) -> None:
        """
        Store Cursor session ID for thread

        Args:
            thread_id: Thread identifier
            session_id: Cursor session ID
        """
        thread = self.load_thread(thread_id)
        if not thread:
            logger.error(f"Thread {thread_id} not found")
            return

        thread.cursor_session_id = session_id
        self.save_thread(thread)
        logger.debug(f"Stored session ID for thread {thread_id}")

    def extract_code_snippet(
        self, file_path: str, line_num: int, context_lines: int = 10
    ) -> tuple[str, str]:
        """
        Extract code snippet around a line with context

        Args:
            file_path: Path to source file
            line_num: Line number to extract around
            context_lines: Number of lines before/after

        Returns:
            Tuple of (code_snippet, function_name)
        """
        path = Path(file_path)
        if not path.exists():
            return "", ""

        try:
            with open(path, "r") as f:
                lines = f.readlines()

            total_lines = len(lines)
            start = max(0, line_num - context_lines - 1)
            end = min(total_lines, line_num + context_lines)

            # Build snippet with line numbers and marker
            snippet_lines = []
            for i in range(start, end):
                marker = " ← " if i == line_num - 1 else "   "
                snippet_lines.append(f"{i+1:3d}|{marker}{lines[i].rstrip()}")

            snippet = "\n".join(snippet_lines)

            # Try to detect function/class name (Swift-specific)
            function_name = ""
            for i in range(line_num - 1, -1, -1):
                line = lines[i].strip()
                if re.match(
                    r"^(func|class|struct|enum|protocol|extension)\s+", line
                ):
                    function_name = line
                    break

            return snippet, function_name

        except Exception as e:
            logger.warning(f"Failed to extract code snippet from {file_path}: {e}")
            return "", ""

    def build_context(self, pr_metadata: PRMetadata, thread_id: str) -> str:
        """
        Build markdown context document for agent

        Args:
            pr_metadata: Pull request metadata
            thread_id: Thread identifier

        Returns:
            Markdown formatted context
        """
        thread = self.load_thread(thread_id)
        if not thread:
            logger.error(f"Thread {thread_id} not found")
            return ""

        # Build context document
        context_parts = [
            f"# Agent Context for PR #{pr_metadata.number}",
            "",
            "## 1. PR Metadata",
            f"- **Title**: {pr_metadata.title}",
            f"- **Branch**: {pr_metadata.branch}",
            f"- **Files Changed**: {', '.join(pr_metadata.changed_files)}",
            "",
            "## 2. PR Description",
            pr_metadata.body or "_No description provided_",
            "",
            "---",
            "",
            "## 3. Review Conversation",
            "",
        ]

        # Add all messages from thread
        for msg in thread.messages:
            context_parts.append(f"### {msg.role.upper()} ({msg.author}) - {msg.timestamp}")

            if msg.location:
                context_parts.append(f"**Location**: `{msg.location}`")
                context_parts.append("")

            if msg.code_snippet:
                context_parts.append("```")
                context_parts.append(msg.code_snippet)
                context_parts.append("```")
                context_parts.append("")

            context_parts.append(msg.content)
            context_parts.append("")

        return "\n".join(context_parts)

    def set_thread_status(
        self, thread_id: str, status: str
    ) -> None:
        """
        Update thread status

        Args:
            thread_id: Thread identifier
            status: New status ('active', 'completed', 'failed')
        """
        thread = self.load_thread(thread_id)
        if not thread:
            return

        thread.status = status  # type: ignore
        self.save_thread(thread)

        # Also update in state
        if thread_id in self.state.threads:
            self.state.threads[thread_id]["status"] = status
            self._save_state()

        logger.debug(f"Set thread {thread_id} status to: {status}")

