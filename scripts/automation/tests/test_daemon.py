"""
Tests for daemon
"""

from datetime import datetime
from unittest.mock import Mock, patch

import pytest

from cursor_automation.config import Config
from cursor_automation.daemon import CursorDaemon
from cursor_automation.models import Comment


@pytest.fixture
def mock_daemon_dependencies():
    """Mock all daemon dependencies"""
    with patch("cursor_automation.daemon.GithubClient") as mock_github_class:
        with patch("cursor_automation.daemon.ThreadManager") as mock_thread_class:
            with patch("cursor_automation.daemon.AgentClient") as mock_agent_class:
                mock_github = Mock()
                mock_thread_manager = Mock()
                mock_agent = Mock()

                mock_github_class.return_value = mock_github
                mock_thread_class.return_value = mock_thread_manager
                mock_agent_class.return_value = mock_agent

                yield {
                    "github": mock_github,
                    "thread_manager": mock_thread_manager,
                    "agent": mock_agent,
                }


def test_daemon_initialization(test_config: Config, mock_daemon_dependencies):
    """Test daemon initialization"""
    daemon = CursorDaemon(test_config)

    assert daemon.config == test_config
    assert daemon.running is True


def test_process_all_prs_empty(test_config: Config, mock_daemon_dependencies):
    """Test processing when no PRs are awaiting response"""
    daemon = CursorDaemon(test_config)
    daemon.github.get_prs_with_label.return_value = []

    daemon.process_all_prs()

    daemon.github.get_prs_with_label.assert_called_once_with(
        "awaiting-cursor-response"
    )


def test_process_all_prs_with_prs(test_config: Config, mock_daemon_dependencies):
    """Test processing multiple PRs"""
    daemon = CursorDaemon(test_config)
    daemon.github.get_prs_with_label.return_value = [5, 6]

    with patch.object(daemon, "process_pr") as mock_process_pr:
        daemon.process_all_prs()

        assert mock_process_pr.call_count == 2
        mock_process_pr.assert_any_call(5)
        mock_process_pr.assert_any_call(6)


def test_process_pr_no_unprocessed_comments(
    test_config: Config, mock_daemon_dependencies
):
    """Test processing PR with no unprocessed comments"""
    daemon = CursorDaemon(test_config)

    comment = Comment(
        id=123, type="issue", author="user1", body="Test", location=""
    )

    daemon.github.get_pr_comments.return_value = [comment]
    daemon.github.has_processed_reactions.return_value = True

    with patch.object(daemon, "process_comment") as mock_process_comment:
        daemon.process_pr(5)

        mock_process_comment.assert_not_called()


def test_process_pr_with_unprocessed_comment(
    test_config: Config, mock_daemon_dependencies
):
    """Test processing PR with unprocessed comment"""
    daemon = CursorDaemon(test_config)

    comment = Comment(
        id=123, type="issue", author="user1", body="@ybalashkevych plan", location=""
    )

    daemon.github.get_pr_comments.return_value = [comment]
    daemon.github.has_processed_reactions.return_value = False

    with patch.object(daemon, "process_comment") as mock_process_comment:
        daemon.process_pr(5)

        mock_process_comment.assert_called_once_with(5, comment)


def test_process_comment_success(
    test_config: Config, mock_daemon_dependencies, sample_thread, sample_pr_metadata
):
    """Test successful comment processing"""
    daemon = CursorDaemon(test_config)

    comment = Comment(
        id=123,
        type="issue",
        author="user1",
        body="@ybalashkevych plan\nPlease help",
        location="",
    )

    # Setup mocks
    daemon.thread_manager.get_or_create_thread.return_value = sample_thread
    daemon.github.get_pr_metadata.return_value = sample_pr_metadata
    daemon.thread_manager.build_context.return_value = "Context here"
    daemon.agent.invoke_agent.return_value = ("Agent response", 0)
    daemon.github.post_comment.return_value = 456

    daemon.process_comment(5, comment)

    # Verify reactions were added
    daemon.github.add_reaction.assert_any_call(123, "issue", "eyes")
    daemon.github.add_reaction.assert_any_call(123, "issue", "rocket")

    # Verify thread was created
    daemon.thread_manager.get_or_create_thread.assert_called_once_with(5, 123)

    # Verify message was added
    assert daemon.thread_manager.add_message.call_count == 2  # User + agent message

    # Verify agent was invoked
    daemon.agent.invoke_agent.assert_called_once()

    # Verify response was posted
    daemon.github.post_comment.assert_called_once()


def test_process_comment_failure(
    test_config: Config, mock_daemon_dependencies, sample_thread, sample_pr_metadata
):
    """Test comment processing with agent failure"""
    daemon = CursorDaemon(test_config)

    comment = Comment(
        id=123, type="issue", author="user1", body="@ybalashkevych plan", location=""
    )

    # Setup mocks
    daemon.thread_manager.get_or_create_thread.return_value = sample_thread
    daemon.github.get_pr_metadata.return_value = sample_pr_metadata
    daemon.thread_manager.build_context.return_value = "Context"
    daemon.agent.invoke_agent.return_value = ("Error", 1)

    daemon.process_comment(5, comment)

    # Verify failure reaction
    daemon.github.add_reaction.assert_any_call(123, "issue", "-1")

    # Verify failure message posted
    args = daemon.github.post_comment.call_args[0]
    assert "Processing Failed" in args[1]


def test_format_response_ask(test_config: Config, mock_daemon_dependencies):
    """Test formatting response for ask command"""
    daemon = CursorDaemon(test_config)

    formatted = daemon._format_response("ask", "What do you want?")

    assert "Questions & Clarifications" in formatted
    assert "What do you want?" in formatted


def test_format_response_plan(test_config: Config, mock_daemon_dependencies):
    """Test formatting response for plan command"""
    daemon = CursorDaemon(test_config)

    formatted = daemon._format_response("plan", "Here's the plan")

    assert "Implementation Plan" in formatted
    assert "Here's the plan" in formatted


def test_format_response_implement(test_config: Config, mock_daemon_dependencies):
    """Test formatting response for implement command"""
    daemon = CursorDaemon(test_config)

    formatted = daemon._format_response("implement", "Changes made")

    assert "Changes Implemented" in formatted
    assert "Changes made" in formatted

