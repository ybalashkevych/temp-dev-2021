"""
Configuration management for cursor automation
"""

from pathlib import Path
from typing import Any

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Config(BaseSettings):
    """Application configuration loaded from environment variables"""

    github_token: str = Field(default="")
    repo_owner: str = "ybalashkevych"
    repo_name: str = "temp-dev-2021"
    poll_interval: int = 60
    log_dir: Path = Path(__file__).parent.parent.parent / "logs"  # Absolute path to scripts/automation/logs
    cursor_model: str = "claude-4.5-sonnet"
    cursor_api_key: str = Field(default="")
    template_dir: Path = Path(__file__).parent.parent.parent / "templates"

    model_config = SettingsConfigDict(
        env_file=".env", env_prefix="CURSOR_", case_sensitive=False
    )

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        # If github_token not in env, try to get from gh CLI
        if not self.github_token:
            try:
                import subprocess

                result = subprocess.run(
                    ["gh", "auth", "token"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                self.github_token = result.stdout.strip()
            except Exception:
                pass

        # Ensure directories exist
        self.log_dir.mkdir(parents=True, exist_ok=True)

