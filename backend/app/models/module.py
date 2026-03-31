from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import uuid
from datetime import datetime

class Module(Base):
    __tablename__ = "modules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nom = Column(String, nullable=False)
    code = Column(String, unique=True, nullable=False)
    semestre = Column(String, nullable=False)
    filiere = Column(String, nullable=False)
    professeur_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    professeur = relationship("User", back_populates="modules_enseignes")
    inscriptions = relationship("UserModule", back_populates="module")
    sessions = relationship("Session", back_populates="module")
    schedules = relationship("Schedule", back_populates="module")