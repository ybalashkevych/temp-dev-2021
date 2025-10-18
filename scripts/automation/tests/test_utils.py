"""
Tests for utility functions
"""

import pytest

from cursor_automation.utils import clean_comment_body, parse_command


def test_parse_command_plan():
    """Test parsing plan command"""
    body = "@ybalashkevych plan\nPlease create an implementation plan"
    assert parse_command(body) == "plan"


def test_parse_command_implement():
    """Test parsing implement command"""
    body1 = "@ybalashkevych implement\nMake the changes"
    assert parse_command(body1) == "implement"

    body2 = "@ybalashkevych fix\nFix this bug"
    assert parse_command(body2) == "implement"


def test_parse_command_ask():
    """Test parsing ask command (default)"""
    body1 = "What does this code do?"
    assert parse_command(body1) == "ask"

    body2 = "@ybalashkevych\nI have a question"
    assert parse_command(body2) == "ask"


def test_clean_comment_body():
    """Test cleaning comment body"""
    body = """
    <details>
    <summary>Details</summary>
    Some content
    </details>

    @ybalashkevych plan
    
    Please implement this feature
    """

    cleaned = clean_comment_body(body)

    assert "<details>" not in cleaned
    assert "<summary>" not in cleaned
    assert "@ybalashkevych plan" not in cleaned
    assert "implement this feature" in cleaned


def test_clean_comment_suggestion_syntax():
    """Test cleaning suggestion syntax"""
    body = """
    ```suggestion
    def foo():
        pass
    ```
    """

    cleaned = clean_comment_body(body)

    assert "```suggestion" not in cleaned
    assert "```" in cleaned
    assert "def foo():" in cleaned

