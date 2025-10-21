"""
Tests for agent client
"""

from pathlib import Path
from unittest.mock import Mock, patch

import pytest

from cursor_automation.agent_client import AgentClient
from cursor_automation.config import Config
from cursor_automation.github_client import GithubClient
from cursor_automation.models import PRMetadata
from cursor_automation.thread_manager import ThreadManager


@pytest.fixture
def mock_github_client(test_config: Config) -> Mock:
    """Mock GitHub client"""
    with patch("cursor_automation.github_client.Github"):
        return GithubClient(test_config)


@pytest.fixture
def agent_client(
    test_config: Config, mock_github_client: GithubClient
) -> AgentClient:
    """Create agent client with mocked dependencies"""
    thread_manager = ThreadManager(test_config)
    return AgentClient(test_config, thread_manager, mock_github_client)


def test_agent_client_init(agent_client: AgentClient, test_config: Config):
    """Test agent client initialization"""
    assert agent_client.config == test_config
    assert agent_client.thread_manager is not None
    assert agent_client.github is not None


def test_build_instructions(
    agent_client: AgentClient, test_config: Config, tmp_path: Path
):
    """Test building instructions from templates"""
    # Create mock templates
    template_dir = tmp_path / "templates"
    template_dir.mkdir()

    (template_dir / "instructions-header.md").write_text(
        "PR: {{PR_NUMBER}}\nThread: {{THREAD_ID}}"
    )
    (template_dir / "instructions-plan.md").write_text("Mode: {{MODE}}")

    agent_client.config.template_dir = template_dir

    instructions = agent_client.build_instructions(
        pr_number=5, thread_id="pr-5-thread-123", command="plan", branch="feature/test"
    )

    assert "PR: 5" in instructions
    assert "Thread: pr-5-thread-123" in instructions
    assert "Mode: plan" in instructions


@patch("subprocess.run")
def test_checkout_pr_branch(mock_run: Mock, agent_client: AgentClient):
    """Test checking out PR branch"""
    mock_run.return_value = Mock(returncode=0)

    agent_client.checkout_pr_branch("feature/test")

    # Verify git commands were called
    assert mock_run.call_count == 3
    calls = [call[0][0] for call in mock_run.call_args_list]

    assert ["git", "fetch", "origin", "feature/test"] in calls
    assert ["git", "checkout", "feature/test"] in calls
    assert ["git", "pull", "origin", "feature/test"] in calls


@patch("subprocess.run")
def test_create_new_session(mock_run: Mock, agent_client: AgentClient, tmp_path: Path):
    """Test creating new Cursor session"""
    prompt_file = tmp_path / "prompt.md"
    prompt_file.write_text("Test prompt")

    mock_run.return_value = Mock(
        stdout="Session: test-session-123\nAgent response here", returncode=0
    )

    response, session_id = agent_client._create_new_session(prompt_file)

    assert "Agent response" in response
    assert session_id == "test-session-123"


@patch("subprocess.run")
def test_resume_session(mock_run: Mock, agent_client: AgentClient, tmp_path: Path):
    """Test resuming Cursor session"""
    prompt_file = tmp_path / "prompt.md"
    prompt_file.write_text("Test prompt")

    mock_run.return_value = Mock(stdout="Resumed response", returncode=0)

    response = agent_client._resume_session("session-123", prompt_file)

    assert response == "Resumed response"

    # Verify correct arguments
    args = mock_run.call_args[0][0]
    assert "cursor" in args
    assert "--session" in args
    assert "session-123" in args
    assert "--resume" in args


def test_invoke_agent_work_directory_created(
    agent_client: AgentClient, sample_pr_metadata: PRMetadata, sample_thread
):
    """Test that work directory is created during agent invocation"""
    with patch.object(agent_client.github, "get_pr_metadata") as mock_get_metadata:
        with patch.object(agent_client, "checkout_pr_branch"):
            with patch.object(agent_client, "build_instructions") as mock_build:
                with patch.object(agent_client, "_create_new_session") as mock_session:
                    mock_get_metadata.return_value = sample_pr_metadata
                    mock_build.return_value = "Test instructions"
                    mock_session.return_value = ("Response", "session-123")

                    # Save thread first
                    agent_client.thread_manager.save_thread(sample_thread)

                    agent_client.invoke_agent(
                        5, sample_thread.thread_id, "plan", "Test context"
                    )

                    # Verify work directory exists
                    work_dir = (
                        agent_client.config.log_dir
                        / f".agent-work-{sample_thread.thread_id}"
                    )
                    assert work_dir.exists()
                    assert (work_dir / "context.md").exists()
                    assert (work_dir / "instructions.md").exists()

