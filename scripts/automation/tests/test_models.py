"""
Tests for data models
"""

from datetime import datetime

import pytest
from pydantic import ValidationError

from cursor_automation.models import (
    AutomationState,
    Comment,
    Message,
    PRMetadata,
    Thread,
)


def test_message_creation():
    """Test creating a Message"""
    msg = Message(
        role="user",
        author="test_user",
        content="Test content",
        timestamp=datetime(2024, 1, 1),
    )

    assert msg.role == "user"
    assert msg.author == "test_user"
    assert msg.content == "Test content"
    assert msg.location == ""
    assert msg.code_snippet == ""


def test_message_with_location():
    """Test message with code location"""
    msg = Message(
        role="user",
        author="reviewer",
        content="Fix this",
        location="src/main.py:42",
        code_snippet="def foo():\n    pass",
        function_name="def foo():",
        timestamp=datetime(2024, 1, 1),
    )

    assert msg.location == "src/main.py:42"
    assert "def foo" in msg.code_snippet


def test_message_invalid_role():
    """Test that invalid role raises validation error"""
    with pytest.raises(ValidationError):
        Message(
            role="invalid_role",  # type: ignore
            author="test",
            content="test",
            timestamp=datetime(2024, 1, 1),
        )


def test_thread_creation():
    """Test creating a Thread"""
    thread = Thread(thread_id="pr-5-thread-123", pr_number=5)

    assert thread.thread_id == "pr-5-thread-123"
    assert thread.pr_number == 5
    assert thread.status == "active"
    assert thread.cursor_session_id is None
    assert len(thread.messages) == 0


def test_thread_with_messages(sample_message: Message):
    """Test thread with messages"""
    thread = Thread(
        thread_id="pr-5-thread-123", pr_number=5, messages=[sample_message]
    )

    assert len(thread.messages) == 1
    assert thread.messages[0].author == "test_user"


def test_comment_issue_type():
    """Test PR-level comment"""
    comment = Comment(
        id=12345, type="issue", author="user1", body="Test comment", location=""
    )

    assert comment.type == "issue"
    assert comment.id == 12345


def test_comment_review_type():
    """Test inline review comment"""
    comment = Comment(
        id=67890,
        type="review",
        author="user2",
        body="Fix this",
        location="src/test.py:10",
    )

    assert comment.type == "review"
    assert comment.location == "src/test.py:10"


def test_automation_state_empty():
    """Test empty automation state"""
    state = AutomationState()

    assert len(state.processed_comments) == 0
    assert len(state.threads) == 0
    assert len(state.comment_to_thread) == 0


def test_automation_state_with_data():
    """Test automation state with data"""
    state = AutomationState(
        processed_comments={"123": True},
        comment_to_thread={"123": "pr-5-thread-456"},
        threads={"pr-5-thread-456": {"pr_number": 5, "status": "active"}},
    )

    assert state.processed_comments["123"] is True
    assert state.comment_to_thread["123"] == "pr-5-thread-456"


def test_pr_metadata():
    """Test PR metadata"""
    metadata = PRMetadata(
        number=5,
        title="Test PR",
        branch="feature/test",
        body="Test description",
        changed_files=["file1.py", "file2.py"],
    )

    assert metadata.number == 5
    assert metadata.title == "Test PR"
    assert len(metadata.changed_files) == 2

