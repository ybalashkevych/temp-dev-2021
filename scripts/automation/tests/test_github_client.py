"""
Tests for GitHub client
"""

from unittest.mock import Mock, patch

import pytest
from github import GithubException

from cursor_automation.config import Config
from cursor_automation.github_client import GithubClient


def test_github_client_initialization(test_config: Config):
    """Test GitHub client initialization"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        mock_github = Mock()
        mock_github_class.return_value = mock_github
        mock_github.get_repo.return_value = Mock()

        client = GithubClient(test_config)

        assert client.config == test_config
        mock_github_class.assert_called_once_with(test_config.github_token)


def test_get_prs_with_label(test_config: Config):
    """Test fetching PRs with label"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        # Setup mocks
        mock_label1 = Mock()
        mock_label1.name = "awaiting-cursor-response"

        mock_label2 = Mock()
        mock_label2.name = "other-label"

        mock_pr1 = Mock()
        mock_pr1.number = 5
        mock_pr1.labels = [mock_label1]

        mock_pr2 = Mock()
        mock_pr2.number = 6
        mock_pr2.labels = [mock_label2]

        mock_repo = Mock()
        mock_repo.get_pulls.return_value = [mock_pr1, mock_pr2]

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        prs = client.get_prs_with_label("awaiting-cursor-response")

        assert len(prs) == 1
        assert prs[0] == 5


def test_get_pr_comments(test_config: Config):
    """Test fetching PR comments"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        # Setup issue comment
        mock_issue_comment = Mock()
        mock_issue_comment.id = 123
        mock_issue_comment.user.login = "user1"
        mock_issue_comment.user.type = "User"
        mock_issue_comment.body = "Test comment"

        # Setup review comment
        mock_review_comment = Mock()
        mock_review_comment.id = 456
        mock_review_comment.user.login = "user2"
        mock_review_comment.body = "Review comment"
        mock_review_comment.in_reply_to_id = None
        mock_review_comment.path = "src/test.py"
        mock_review_comment.line = 10
        mock_review_comment.original_line = 10

        # Setup mocks
        mock_issue = Mock()
        mock_issue.get_comments.return_value = [mock_issue_comment]

        mock_pr = Mock()
        mock_pr.get_review_comments.return_value = [mock_review_comment]

        mock_repo = Mock()
        mock_repo.get_issue.return_value = mock_issue
        mock_repo.get_pull.return_value = mock_pr

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        comments = client.get_pr_comments(5)

        assert len(comments) == 2
        assert comments[0].id == 123
        assert comments[0].type == "issue"
        assert comments[1].id == 456
        assert comments[1].type == "review"
        assert comments[1].location == "src/test.py:10"


def test_check_reactions(test_config: Config):
    """Test checking comment reactions"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        # Mock the API response
        mock_requester = Mock()
        mock_requester.requestJsonAndCheck.return_value = (
            {},  # headers
            [{"content": "eyes"}, {"content": "rocket"}]  # data
        )

        mock_repo = Mock()
        mock_repo._requester = mock_requester

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        reactions = client.check_reactions(123, "issue")

        assert "eyes" in reactions
        assert "rocket" in reactions
        assert len(reactions) == 2


def test_has_processed_reactions(test_config: Config):
    """Test checking if comment is fully processed"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        # Mock the API response with both eyes and rocket
        mock_requester = Mock()
        mock_requester.requestJsonAndCheck.return_value = (
            {},
            [{"content": "eyes"}, {"content": "rocket"}]
        )

        mock_repo = Mock()
        mock_repo._requester = mock_requester

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        result = client.has_processed_reactions(123, "issue")

        assert result is True


def test_add_reaction(test_config: Config):
    """Test adding reaction to comment"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        # Mock the API response
        mock_requester = Mock()
        mock_requester.requestJsonAndCheck.return_value = ({}, {})

        mock_repo = Mock()
        mock_repo._requester = mock_requester

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        result = client.add_reaction(123, "issue", "eyes")

        assert result is True
        # Verify the API was called with correct parameters
        mock_requester.requestJsonAndCheck.assert_called_once()


def test_post_comment(test_config: Config):
    """Test posting a comment"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        mock_new_comment = Mock()
        mock_new_comment.id = 789

        mock_issue = Mock()
        mock_issue.create_comment.return_value = mock_new_comment

        mock_repo = Mock()
        mock_repo.get_issue.return_value = mock_issue

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        comment_id = client.post_comment(5, "Test comment body")

        assert comment_id == 789
        mock_issue.create_comment.assert_called_once_with("Test comment body")


def test_get_pr_metadata(test_config: Config):
    """Test fetching PR metadata"""
    with patch("cursor_automation.github_client.Github") as mock_github_class:
        mock_file = Mock()
        mock_file.filename = "src/test.py"

        mock_pr = Mock()
        mock_pr.title = "Test PR"
        mock_pr.head.ref = "feature/test"
        mock_pr.body = "Test description"
        mock_pr.get_files.return_value = [mock_file]

        mock_repo = Mock()
        mock_repo.get_pull.return_value = mock_pr

        mock_github = Mock()
        mock_github.get_repo.return_value = mock_repo
        mock_github_class.return_value = mock_github

        client = GithubClient(test_config)
        metadata = client.get_pr_metadata(5)

        assert metadata.number == 5
        assert metadata.title == "Test PR"
        assert metadata.branch == "feature/test"
        assert len(metadata.changed_files) == 1

