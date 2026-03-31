from sqlalchemy import Column, String, Boolean, Enum, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
from app.database import Base
import uuid
import enum
from datetime import datetime

class RoleEnum(str, enum.Enum):
    admin = "admin"
    professeur = "professeur"
    etudiant = "etudiant"

class User(Base):
    __tablename__="users"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nom=Column(String, nullable=False)
    prenom=Column(String, nullable=False)
    email=Column(String, unique=True, nullable=False)
    apogee=Column(String, unique=True, nullable=False)
    mot_de_passe_hash=Column(String, nullable=False)
    role=Column(Enum(RoleEnum), nullable=False)
    actif=Column(Boolean, default=True)
    created_at=Column(DateTime, default=datetime.utcnow)

    # Relations
    face_embedding = relationship("FaceEmbedding", back_populates="user", uselist=False)
    modules_enseignes=relationship("Module", back_populates="professeur")
    inscriptions=relationship("UserModule", back_populates="etudiant")
    attendances=relationship("Attendance", back_populates="etudiant")
