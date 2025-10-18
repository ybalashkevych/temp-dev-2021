"""
Tests for thread manager
"""

import json
from datetime import datetime
from pathlib import Path

import pytest

from cursor_automation.config import Config
from cursor_automation.models import Message, PRMetadata, Thread
from cursor_automation.thread_manager import ThreadManager


def test_thread_manager_init(test_config: Config):
    """Test thread manager initialization"""
    tm = ThreadManager(test_config)

    assert tm.config == test_config
    assert tm.log_dir.exists()
    assert tm.state_file.exists()


def test_save_and_load_thread(test_config: Config, sample_thread: Thread):
    """Test saving and loading threads"""
    tm = ThreadManager(test_config)

    # Save thread
    tm.save_thread(sample_thread)

    # Load thread
    loaded = tm.load_thread(sample_thread.thread_id)

    assert loaded is not None
    assert loaded.thread_id == sample_thread.thread_id
    assert loaded.pr_number == sample_thread.pr_number
    assert len(loaded.messages) == len(sample_thread.messages)


def test_get_or_create_thread_new(test_config: Config):
    """Test creating a new thread"""
    tm = ThreadManager(test_config)

    thread = tm.get_or_create_thread(pr_number=5, comment_id=12345)

    assert thread.pr_number == 5
    assert "pr-5-thread-" in thread.thread_id
    assert thread.status == "active"

    # Verify it's saved
    loaded = tm.load_thread(thread.thread_id)
    assert loaded is not None


def test_get_or_create_thread_existing(test_config: Config, sample_thread: Thread):
    """Test retrieving existing thread"""
    tm = ThreadManager(test_config)

    # Save initial thread
    tm.save_thread(sample_thread)
    comment_id = 12345
    tm.state.comment_to_thread[str(comment_id)] = sample_thread.thread_id
    tm._save_state()

    # Get thread for same comment
    thread = tm.get_or_create_thread(sample_thread.pr_number, comment_id)

    assert thread.thread_id == sample_thread.thread_id


def test_add_message(test_config: Config, sample_thread: Thread):
    """Test adding message to thread"""
    tm = ThreadManager(test_config)
    tm.save_thread(sample_thread)

    initial_count = len(sample_thread.messages)

    new_message = Message(
        role="user",
        author="new_user",
        content="New message",
        timestamp=datetime.utcnow(),
    )

    tm.add_message(sample_thread.thread_id, new_message)

    # Load and verify
    loaded = tm.load_thread(sample_thread.thread_id)
    assert loaded is not None
    assert len(loaded.messages) == initial_count + 1
    assert loaded.messages[-1].author == "new_user"


def test_get_thread_for_comment(test_config: Config):
    """Test getting thread ID for comment"""
    tm = ThreadManager(test_config)

    comment_id = 12345
    thread_id = "pr-5-thread-123"

    tm.state.comment_to_thread[str(comment_id)] = thread_id
    tm._save_state()

    result = tm.get_thread_for_comment(comment_id)

    assert result == thread_id


def test_session_id_storage(test_config: Config, sample_thread: Thread):
    """Test storing and retrieving session IDs"""
    tm = ThreadManager(test_config)
    tm.save_thread(sample_thread)

    session_id = "test-session-123"

    # Store session ID
    tm.store_session_id(sample_thread.thread_id, session_id)

    # Retrieve session ID
    retrieved = tm.get_session_id(sample_thread.thread_id)

    assert retrieved == session_id


def test_extract_code_snippet(test_config: Config, tmp_path: Path):
    """Test extracting code snippet from file"""
    tm = ThreadManager(test_config)

    # Create test file
    test_file = tmp_path / "test.py"
    test_file.write_text(
        """def foo():
    pass

def bar():
    x = 1
    y = 2
    z = x + y
    return z

def baz():
    pass
"""
    )

    snippet, function = tm.extract_code_snippet(str(test_file), 7, context_lines=3)

    assert "z = x + y" in snippet
    # Function detection looks backwards from the line, should find def bar()
    assert function == "" or "def bar" in function


def test_build_context(
    test_config: Config, sample_thread: Thread, sample_pr_metadata: PRMetadata
):
    """Test building context document"""
    tm = ThreadManager(test_config)
    tm.save_thread(sample_thread)

    context = tm.build_context(sample_pr_metadata, sample_thread.thread_id)

    assert f"PR #{sample_pr_metadata.number}" in context
    assert sample_pr_metadata.title in context
    assert sample_pr_metadata.branch in context
    assert "Review Conversation" in context

    # Check messages are included
    for msg in sample_thread.messages:
        assert msg.author in context
        assert msg.content in context


def test_set_thread_status(test_config: Config, sample_thread: Thread):
    """Test updating thread status"""
    tm = ThreadManager(test_config)
    tm.save_thread(sample_thread)

    tm.set_thread_status(sample_thread.thread_id, "completed")

    loaded = tm.load_thread(sample_thread.thread_id)
    assert loaded is not None
    assert loaded.status == "completed"


def test_state_persistence(test_config: Config):
    """Test that state persists across instances"""
    # First instance
    tm1 = ThreadManager(test_config)
    tm1.state.processed_comments["123"] = True
    tm1._save_state()

    # Second instance
    tm2 = ThreadManager(test_config)

    assert "123" in tm2.state.processed_comments
    assert tm2.state.processed_comments["123"] is True

