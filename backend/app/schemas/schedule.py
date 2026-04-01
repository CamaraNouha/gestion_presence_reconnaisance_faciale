from pydantic import BaseModel
from uuid import UUID
from datetime import time

class ScheduleCreate(BaseModel):
    module_id: UUID
    jour: int  # 0=Lundi, 5=Samedi
    heure_debut: time
    heure_fin: time
    salle: str
    groupe: str | None = None

class ScheduleResponse(BaseModel):
    id: UUID
    module_id: UUID
    jour: int
    heure_debut: time
    heure_fin: time
    salle: str
    groupe: str | None

    class Config:
        from_attributes = True