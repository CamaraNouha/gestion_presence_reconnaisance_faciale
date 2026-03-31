from pydantic import BaseModel, EmailStr
from uuid import UUID
from enum import Enum

class RoleEnum(str, Enum):
    admin = "admin"
    professeur = "professeur"
    etudiant = "etudiant"

class UserCreate(BaseModel):
    nom: str
    prenom: str
    email: EmailStr
    apogee: str | None = None
    mot_de_passe: str
    role: RoleEnum

class UserUpdate(BaseModel):
    nom: str | None = None
    prenom: str | None = None
    email: EmailStr | None = None

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

class LoginRequest(BaseModel):
    email: EmailStr
    apogee: str

class Token(BaseModel):
    access_token: str
    token_type: str
    role: str
    user: UserResponse