from sqlalchemy import Column, String, DateTime, Integer, Float, ForeignKey, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import uuid
import enum
from datetime import datetime

class StatutSession(str, enum.Enum):
    ouverte = "ouverte"
    fermee = "fermee"

class Session(Base):
    __tablename__ = "sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    module_id = Column(UUID(as_uuid=True), ForeignKey("modules.id"), nullable=False)
    professeur_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    debut_at = Column(DateTime, default=datetime.utcnow)
    fin_at = Column(DateTime, nullable=True)
    delai_minutes = Column(Integer, default=15)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    statut = Column(Enum(StatutSession), default=StatutSession.ouverte)

    # Relations
    module = relationship("Module", back_populates="sessions")
    attendances = relationship("Attendance", back_populates="session")
    notifications = relationship("Notification", back_populates="session")