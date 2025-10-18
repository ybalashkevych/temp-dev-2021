"""
Pytest fixtures and test configuration
"""

from datetime import datetime
from pathlib import Path
from unittest.mock import Mock

import pytest
from github import Github
from github.Repository import Repository

from cursor_automation.config import Config
from cursor_automation.models import Comment, Message, PRMetadata, Thread


@pytest.fixture
def temp_log_dir(tmp_path: Path) -> Path:
    """Temporary log directory for tests"""
    log_dir = tmp_path / "logs"
    log_dir.mkdir()
    return log_dir


@pytest.fixture
def test_config(temp_log_dir: Path) -> Config:
    """Test configuration"""
    return Config(
        github_token="test_token",
        repo_owner="test_owner",
        repo_name="test_repo",
        poll_interval=10,
        log_dir=temp_log_dir,
        cursor_model="test-model",
        template_dir=Path("scripts/automation/templates"),
    )


@pytest.fixture
def mock_github() -> Mock:
    """Mock GitHub API client"""
    mock = Mock(spec=Github)
    mock_repo = Mock(spec=Repository)
    mock.get_repo.return_value = mock_repo
    return mock


@pytest.fixture
def sample_comment() -> Comment:
    """Sample comment for testing"""
    return Comment(
        id=12345,
        type="issue",
        author="test_user",
        body="@ybalashkevych plan\nPlease implement feature X",
        location="",
    )


@pytest.fixture
def sample_inline_comment() -> Comment:
    """Sample inline review comment"""
    return Comment(
        id=67890,
        type="review",
        author="reviewer",
        body="This logic seems incorrect",
        location="src/main.py:42",
    )


@pytest.fixture
def sample_thread() -> Thread:
    """Sample thread for testing"""
    return Thread(
        thread_id="pr-5-thread-123456",
        pr_number=5,
        cursor_session_id="session-abc123",
        status="active",
        created_at=datetime(2024, 1, 1, 12, 0, 0),
        messages=[
            Message(
                role="user",
                author="test_user",
                content="Please add feature X",
                location="",
                timestamp=datetime(2024, 1, 1, 12, 0, 0),
            ),
            Message(
                role="assistant",
                author="cursor-agent",
                content="I'll help with that",
                location="",
                timestamp=datetime(2024, 1, 1, 12, 5, 0),
            ),
        ],
    )


@pytest.fixture
def sample_pr_metadata() -> PRMetadata:
    """Sample PR metadata"""
    return PRMetadata(
        number=5,
        title="Add new feature",
        branch="feature/new-feature",
        body="This PR adds feature X to improve Y",
        changed_files=["src/main.py", "tests/test_main.py"],
    )


@pytest.fixture
def sample_message() -> Message:
    """Sample message for testing"""
    return Message(
        role="user",
        author="test_user",
        content="Test message content",
        location="src/test.py:10",
        code_snippet="1 | def test():\n2 |     pass",
        function_name="def test():",
        timestamp=datetime(2024, 1, 1, 12, 0, 0),
    )

