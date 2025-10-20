"""
Data models for cursor automation system
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field


class Message(BaseModel):
    """A single message in a conversation thread"""

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})

    role: Literal["user", "assistant"]
    author: str
    content: str
    location: str = ""
    code_snippet: str = ""
    function_name: str = ""
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class Thread(BaseModel):
    """A conversation thread for PR feedback"""

    model_config = ConfigDict(json_encoders={datetime: lambda v: v.isoformat()})

    thread_id: str
    pr_number: int
    cursor_session_id: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    status: Literal["active", "completed", "failed"] = "active"
    messages: list[Message] = Field(default_factory=list)


class Comment(BaseModel):
    """A GitHub comment (PR-level or inline review)"""

    id: int
    type: Literal["issue", "review"]
    author: str
    body: str
    location: str = ""


class AutomationState(BaseModel):
    """Persistent state for tracking processed comments and threads"""

    processed_comments: dict[str, bool] = Field(default_factory=dict)
    threads: dict[str, dict] = Field(default_factory=dict)
    comment_to_thread: dict[str, str] = Field(default_factory=dict)


class PRMetadata(BaseModel):
    """Metadata about a pull request"""

    number: int
    title: str
    branch: str
    body: str
    changed_files: list[str]

