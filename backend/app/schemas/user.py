from pydantic import BaseModel
from uuid import UUID
from enum import Enum


class RoleEnum(str, Enum):
    admin = "admin"
    professeur = "professeur"
    etudiant = "etudiant"


class UserCreate(BaseModel):
    nom: str
    prenom: str
    email: str
    apogee: str | None = None
    mot_de_passe: str
    role: RoleEnum


class UserUpdate(BaseModel):
    nom: str | None = None
    prenom: str | None = None
    email: str | None = None


class UserResponse(BaseModel):
    id: UUID
    nom: str
    prenom: str
    email: str
    apogee: str | None
    role: RoleEnum
    actif: bool

    class Config:
        from_attributes = True


# Login par apogée + mot de passe
class LoginRequest(BaseModel):
    apogee: str
    mot_de_passe: str


class Token(BaseModel):
    access_token: str
    token_type: str
    role: str
    user: UserResponse