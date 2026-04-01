from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from enum import Enum

class StatutSession(str, Enum):
    ouverte = "ouverte"
    fermee = "fermee"

class SessionCreate(BaseModel):
    module_id: UUID
    delai_minutes: int = 15
    latitude: float | None = None
    longitude: float | None = None

class SessionResponse(BaseModel):
    id: UUID
    module_id: UUID
    professeur_id: UUID
    debut_at: datetime
    fin_at: datetime | None
    delai_minutes: int
    latitude: float | None
    longitude: float | None
    statut: StatutSession

    class Config:
        from_attributes = True