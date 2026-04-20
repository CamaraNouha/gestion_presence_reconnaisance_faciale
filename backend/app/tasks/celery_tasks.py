# ============================================================
# CELERY — lit l'URL Redis depuis les variables d'environnement
# ============================================================

from celery import Celery
import os

# Lit l'URL Redis depuis les variables d'environnement
REDIS_URL = os.getenv("REDIS_URL", "redis://127.0.0.1:6379/0")

celery_app = Celery(
    "eniad",
    broker=REDIS_URL,
    backend=REDIS_URL
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC"
)

@celery_app.task(name="mark_absents_auto")
def mark_absents_auto(session_id: str):
    from app.database import SessionLocal
    from app.models.session import Session, StatutSession
    from app.models.attendance import Attendance, StatutPresence
    from datetime import datetime

    db = SessionLocal()
    try:
        session = db.query(Session).filter(
            Session.id == session_id
        ).first()

        if not session or session.statut == StatutSession.fermee:
            return {"message": "Session déjà fermée"}

        db.query(Attendance).filter(
            Attendance.session_id == session_id,
            Attendance.statut == None
        ).update({"statut": StatutPresence.absent})

        session.statut = StatutSession.fermee
        session.fin_at = datetime.utcnow()
        db.commit()

        return {"message": f"Absents marqués pour session {session_id}"}
    finally:
        db.close()