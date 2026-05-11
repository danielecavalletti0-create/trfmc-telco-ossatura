from pydantic import BaseModel, Field
from typing import Any, Dict, Optional
from datetime import datetime
from uuid import uuid4
from app.shared.timebase import now_utc

class CloudEvent(BaseModel):
    specversion: str = "1.0"
    id: str = Field(default_factory=lambda: str(uuid4()))
    source: str
    type: str
    time: datetime = Field(default_factory=now_utc)
    datacontenttype: str = "application/json"
    subject: Optional[str] = None
    data: Dict[str, Any] = Field(default_factory=dict)

def ce_type(domain: str, event_name: str) -> str:
    return f"trfmc.{domain}.{event_name}".lower().replace("_", ".")
