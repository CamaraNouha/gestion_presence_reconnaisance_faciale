from sqlalchemy import Column, DateTime, Float, ForeignKey, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import uuid
import enum
from datetime import datetime

class StatutPresence(str, enum.Enum):
    present = "present"
    absent = "absent"

class Attendance(Base):
    __tablename__ = "attendances"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False)
    etudiant_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    statut = Column(Enum(StatutPresence), nullable=True)
    pointed_at = Column(DateTime, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relations
    session = relationship("Session", back_populates="attendances")
    etudiant = relationship("User", back_populates="attendances")