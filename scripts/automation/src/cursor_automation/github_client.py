"""
GitHub API client for PR and comment operations
"""

import logging
from typing import Any

from github import Github, GithubException
from github.PullRequest import PullRequest
from github.Repository import Repository

from .config import Config
from .models import Comment, PRMetadata

logger = logging.getLogger(__name__)


class GithubClient:
    """Wrapper for GitHub API operations"""

    def __init__(self, config: Config) -> None:
        """
        Initialize GitHub client

        Args:
            config: Application configuration
        """
        self.config = config
        self.github = Github(config.github_token)
        self.repo: Repository = self.github.get_repo(
            f"{config.repo_owner}/{config.repo_name}"
        )
        logger.info(f"Initialized GitHub client for {config.repo_owner}/{config.repo_name}")

    def get_prs_with_label(self, label: str) -> list[int]:
        """
        Get PR numbers with specific label

        Args:
            label: Label to filter by

        Returns:
            List of PR numbers
        """
        try:
            pulls = self.repo.get_pulls(state="open")
            pr_numbers = []

            for pr in pulls:
                label_names = [lbl.name for lbl in pr.labels]
                if label in label_names:
                    pr_numbers.append(pr.number)

            logger.debug(f"Found {len(pr_numbers)} PRs with label '{label}'")
            return pr_numbers

        except GithubException as e:
            logger.error(f"Failed to fetch PRs with label '{label}': {e}")
            return []

    def get_pr_comments(self, pr_number: int) -> list[Comment]:
        """
        Get all comments (PR-level and inline review) for a PR

        Args:
            pr_number: Pull request number

        Returns:
            List of Comment objects
        """
        comments: list[Comment] = []

        try:
            pr = self.repo.get_pull(pr_number)

            # Get PR-level comments (issue comments)
            issue = self.repo.get_issue(pr_number)
            for comment in issue.get_comments():
                # Skip bot comments
                if comment.user.type == "Bot":
                    continue

                comments.append(
                    Comment(
                        id=comment.id,
                        type="issue",
                        author=comment.user.login,
                        body=comment.body,
                        location="",
                    )
                )

            # Get inline review comments (only top-level, not replies)
            for comment in pr.get_review_comments():
                if comment.in_reply_to_id is None:
                    location = f"{comment.path}:{comment.line or comment.original_line}"
                    comments.append(
                        Comment(
                            id=comment.id,
                            type="review",
                            author=comment.user.login,
                            body=comment.body,
                            location=location,
                        )
                    )

            logger.debug(f"Found {len(comments)} comments in PR #{pr_number}")
            return comments

        except GithubException as e:
            logger.error(f"Failed to fetch comments for PR #{pr_number}: {e}")
            return []

    def get_pr_metadata(self, pr_number: int) -> PRMetadata:
        """
        Get metadata about a pull request

        Args:
            pr_number: Pull request number

        Returns:
            PRMetadata object
        """
        try:
            pr = self.repo.get_pull(pr_number)
            files = [f.filename for f in pr.get_files()]

            return PRMetadata(
                number=pr_number,
                title=pr.title,
                branch=pr.head.ref,
                body=pr.body or "",
                changed_files=files[:20],  # Limit to first 20 files
            )

        except GithubException as e:
            logger.error(f"Failed to fetch PR metadata for #{pr_number}: {e}")
            raise

    def check_reactions(self, comment_id: int, comment_type: str) -> set[str]:
        """
        Check existing reactions on a comment

        Args:
            comment_id: Comment ID
            comment_type: 'issue' or 'review'

        Returns:
            Set of reaction types (e.g., {'eyes', 'rocket'})
        """
        try:
            # Use GitHub API directly via PyGithub's requester
            if comment_type == "issue":
                api_endpoint = f"/repos/{self.config.repo_owner}/{self.config.repo_name}/issues/comments/{comment_id}/reactions"
            else:
                api_endpoint = f"/repos/{self.config.repo_owner}/{self.config.repo_name}/pulls/comments/{comment_id}/reactions"
            
            # Make direct API call
            headers, data = self.repo._requester.requestJsonAndCheck("GET", api_endpoint)
            
            reactions = {reaction["content"] for reaction in data}
            return reactions

        except GithubException as e:
            logger.warning(f"Failed to check reactions for comment {comment_id}: {e}")
            return set()

    def has_processed_reactions(self, comment_id: int, comment_type: str) -> bool:
        """
        Check if comment has both 'eyes' and 'rocket' reactions

        Args:
            comment_id: Comment ID
            comment_type: 'issue' or 'review'

        Returns:
            True if comment has been fully processed
        """
        reactions = self.check_reactions(comment_id, comment_type)
        return "eyes" in reactions and "rocket" in reactions

    def add_reaction(self, comment_id: int, comment_type: str, reaction: str) -> bool:
        """
        Add reaction to a comment

        Args:
            comment_id: Comment ID
            comment_type: 'issue' or 'review'
            reaction: Reaction type ('eyes', 'rocket', '+1', '-1')

        Returns:
            True if successful
        """
        try:
            # Use GitHub API directly via PyGithub's requester
            if comment_type == "issue":
                api_endpoint = f"/repos/{self.config.repo_owner}/{self.config.repo_name}/issues/comments/{comment_id}/reactions"
            else:
                api_endpoint = f"/repos/{self.config.repo_owner}/{self.config.repo_name}/pulls/comments/{comment_id}/reactions"
            
            # Make direct API call
            self.repo._requester.requestJsonAndCheck(
                "POST",
                api_endpoint,
                input={"content": reaction},
                headers={"Accept": "application/vnd.github+json"}
            )
            
            logger.debug(f"Added {reaction} reaction to comment {comment_id}")
            return True

        except GithubException as e:
            logger.warning(f"Failed to add {reaction} reaction to comment {comment_id}: {e}")
            return False

    def post_comment(self, pr_number: int, body: str) -> int | None:
        """
        Post a comment to a PR

        Args:
            pr_number: Pull request number
            body: Comment body

        Returns:
            Comment ID if successful, None otherwise
        """
        try:
            issue = self.repo.get_issue(pr_number)
            comment = issue.create_comment(body)
            logger.info(f"Posted comment {comment.id} to PR #{pr_number}")
            return comment.id

        except GithubException as e:
            logger.error(f"Failed to post comment to PR #{pr_number}: {e}")
            return None

    def post_reply(self, pr_number: int, comment_id: int, body: str) -> int | None:
        """
        Post a reply to a review comment

        Args:
            pr_number: Pull request number
            comment_id: Parent comment ID
            body: Reply body

        Returns:
            Reply comment ID if successful, None otherwise
        """
        try:
            pr = self.repo.get_pull(pr_number)
            parent_comment = pr.get_review_comment(comment_id)

            # Create reply
            reply = pr.create_review_comment_reply(comment_id, body)
            logger.info(f"Posted reply {reply.id} to comment {comment_id}")
            return reply.id

        except GithubException as e:
            logger.error(f"Failed to post reply to comment {comment_id}: {e}")
            return None

