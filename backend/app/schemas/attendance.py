from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from enum import Enum

class StatutPresence(str, Enum):
    present = "present"
    absent = "absent"

class AttendanceResponse(BaseModel):
    id: UUID
    session_id: UUID
    etudiant_id: UUID
    statut: StatutPresence | None
    pointed_at: datetime | None
    latitude: float | None
    longitude: float | None

    class Config:
        from_attributes = True

class CheckinRequest(BaseModel):
    session_id: UUID
    latitude: float | None = None
    longitude: float | None = None
    frame_base64: str