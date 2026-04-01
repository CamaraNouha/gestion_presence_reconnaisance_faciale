from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class ModuleCreate(BaseModel):
    nom: str
    code: str
    semestre: str
    filiere: str
    professeur_id: UUID

class ModuleUpdate(BaseModel):
    nom: str | None = None
    code: str | None = None
    semestre: str | None = None
    filiere: str | None = None
    professeur_id: UUID | None = None

class ModuleResponse(BaseModel):
    id: UUID
    nom: str
    code: str
    semestre: str
    filiere: str
    professeur_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True