from pydantic import BaseModel, Field


class TimeCursorSetRequest(BaseModel):
    mission_id: str = "MISSION-FULL-TELCO-BOOT-001"
    cursor_ms: int = Field(..., ge=0)
    reason: str = "manual_update"


class TimeCursorStatus(BaseModel):
    mission_id: str
    cursor_ms: int
    status: str
