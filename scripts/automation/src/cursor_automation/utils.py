"""
Utility functions and logging setup
"""

import logging
import sys
from pathlib import Path


def setup_logging(log_file: Path | None = None, debug: bool = False) -> logging.Logger:
    """
    Configure logging for the application

    Args:
        log_file: Optional file to write logs to
        debug: Enable debug logging

    Returns:
        Configured logger instance
    """
    level = logging.DEBUG if debug else logging.INFO

    # Create logger
    logger = logging.getLogger("cursor_automation")
    logger.setLevel(level)
    logger.handlers.clear()

    # Console handler with colors
    console_handler = logging.StreamHandler(sys.stderr)
    console_handler.setLevel(level)

    # Format with colors for terminal
    class ColoredFormatter(logging.Formatter):
        COLORS = {
            "DEBUG": "\033[0;36m",  # Cyan
            "INFO": "\033[0;34m",  # Blue
            "WARNING": "\033[1;33m",  # Yellow
            "ERROR": "\033[0;31m",  # Red
            "CRITICAL": "\033[1;31m",  # Bold Red
        }
        RESET = "\033[0m"

        def format(self, record: logging.LogRecord) -> str:
            color = self.COLORS.get(record.levelname, self.RESET)
            record.levelname = f"{color}{record.levelname}{self.RESET}"
            return super().format(record)

    console_formatter = ColoredFormatter(
        "[%(asctime)s] [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
    )
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # File handler if specified
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(level)
        file_formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        file_handler.setFormatter(file_formatter)
        logger.addHandler(file_handler)

    return logger


def clean_comment_body(body: str) -> str:
    """
    Clean GitHub comment body by removing artifacts and mentions

    Args:
        body: Raw comment body

    Returns:
        Cleaned comment text
    """
    import re

    # Remove HTML tags
    body = re.sub(r"<details>|</details>|<summary>|</summary>", "\n", body)

    # Remove suggestion syntax
    body = re.sub(r"```suggestion", "```", body)

    # Remove only the @mention, keep the command and rest of message
    body = re.sub(r"@\w+\s+", "", body, count=1)

    # Strip leading/trailing whitespace
    body = body.strip()

    return body


def parse_command(body: str) -> str:
    """
    Parse command from comment body

    Args:
        body: Comment body text

    Returns:
        Command type: 'ask', 'plan', or 'implement'
    """
    import re

    body_lower = body.lower()

    # Check for explicit commands
    if re.search(r"@\w+\s+plan", body_lower):
        return "plan"
    elif re.search(r"@\w+\s+(fix|implement)", body_lower):
        return "implement"
    else:
        return "ask"

