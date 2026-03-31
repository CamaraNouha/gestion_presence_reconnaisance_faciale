from sqlalchemy import Column, String, DateTime, Integer, ForeignKey, Time
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import uuid
from datetime import datetime

class UserModule(Base):
    __tablename__ = "user_modules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    module_id = Column(UUID(as_uuid=True), ForeignKey("modules.id"), nullable=False)
    date_inscription = Column(DateTime, default=datetime.utcnow)

    etudiant = relationship("User", back_populates="inscriptions")
    module = relationship("Module", back_populates="inscriptions")

class Schedule(Base):
    __tablename__ = "schedules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    module_id = Column(UUID(as_uuid=True), ForeignKey("modules.id"), nullable=False)
    jour = Column(Integer, nullable=False)  # 0=Lundi, 5=Samedi
    heure_debut = Column(Time, nullable=False)
    heure_fin = Column(Time, nullable=False)
    salle = Column(String, nullable=False)
    groupe = Column(String, nullable=True)

    module = relationship("Module", back_populates="schedules")

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False)
    type = Column(String, nullable=False)
    sent_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String, default="sent")

    session = relationship("Session", back_populates="notifications")