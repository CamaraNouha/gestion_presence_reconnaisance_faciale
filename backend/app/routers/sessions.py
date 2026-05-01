from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel
from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.session import Session as SessionModel, StatutSession
from app.models.attendance import Attendance, StatutPresence
from app.models.other import UserModule
from app.schemas.session import SessionCreate, SessionResponse
from app.schemas.attendance import AttendanceResponse
from app.core.dependencies import require_professeur, get_current_user
from app.services.firebase_service import (send_session_notification, send_session_closed_notification)

router = APIRouter(prefix="/sessions", tags=["Sessions"])

# ─────────────────────────────────────────
# OUVRIR UNE SESSION
# ─────────────────────────────────────────

@router.post("/open", response_model=SessionResponse)
async def open_session(
    session_data: SessionCreate,
    db: Session = Depends(get_db),
    prof: User = Depends(require_professeur)
):
    # Vérifie que le module existe et appartient au prof
    module = db.query(Module).filter(
        Module.id == session_data.module_id,
        Module.professeur_id == prof.id
    ).first()
    if not module:
        raise HTTPException(
            status_code=404,
            detail="Module introuvable ou non assigné à ce professeur"
        )

    # Vérifie qu'aucune session n'est déjà ouverte pour ce module
    existing = db.query(SessionModel).filter(
        SessionModel.module_id == session_data.module_id,
        SessionModel.statut == StatutSession.ouverte
    ).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail="Une session est déjà ouverte pour ce module"
        )

    # Crée la session
    session = SessionModel(
        module_id=session_data.module_id,
        professeur_id=prof.id,
        delai_minutes=session_data.delai_minutes,
        latitude=session_data.latitude,
        longitude=session_data.longitude,
        statut=StatutSession.ouverte
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Crée les entrées attendance pour tous les étudiants inscrits
    inscriptions = db.query(UserModule).filter(
        UserModule.module_id == session_data.module_id
    ).all()

    for inscription in inscriptions:
        attendance = Attendance(
            session_id=session.id,
            etudiant_id=inscription.user_id,
            statut=None  # Pas encore pointé
        )
        db.add(attendance)

    db.commit()

    await send_session_notification(
        module_id=str(session.module_id),
        module_nom=module.nom,
        prof_nom=f"{prof.prenom} {prof.nom}",
        session_id=str(session.id),
        delai_minutes=session_data.delai_minutes
    )

    # Programmer Celery pour marquer absents après délai
    from app.tasks.celery_tasks import mark_absents_auto
    mark_absents_auto.apply_async(
        args=[str(session.id)],
        countdown=session_data.delai_minutes * 60
    )

    return session

# ─────────────────────────────────────────
# FERMER UNE SESSION
# ─────────────────────────────────────────

@router.post("/{session_id}/close", response_model=SessionResponse)
async def close_session(
    session_id: UUID,
    db: Session = Depends(get_db),
    prof: User = Depends(require_professeur)
):
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.professeur_id == prof.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session introuvable")

    if session.statut == StatutSession.fermee:
        raise HTTPException(status_code=400, detail="Session déjà fermée")

    # Ferme la session
    session.statut = StatutSession.fermee
    session.fin_at = datetime.utcnow()

    # Marque absents tous ceux qui n'ont pas pointé
    db.query(Attendance).filter(
        Attendance.session_id == session_id,
        Attendance.statut == None
    ).update({"statut": StatutPresence.absent})

    db.commit()
    db.refresh(session)
    await send_session_closed_notification(
        module_id=str(session.module_id),
        module_nom=session.module.nom
    )
    return session

# ─────────────────────────────────────────
# CONSULTER LES PRÉSENCES D'UNE SESSION
# ─────────────────────────────────────────

@router.get("/{session_id}/attendances", response_model=List[AttendanceResponse])
def get_session_attendances(
    session_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session introuvable")

    attendances = db.query(Attendance).filter(
        Attendance.session_id == session_id
    ).all()
    return attendances

# ─────────────────────────────────────────
# SESSIONS DU PROFESSEUR
# ─────────────────────────────────────────

@router.get("/my-sessions", response_model=List[SessionResponse])
def get_my_sessions(
    db: Session = Depends(get_db),
    prof: User = Depends(require_professeur)
):
    return db.query(SessionModel).filter(
        SessionModel.professeur_id == prof.id
    ).order_by(SessionModel.debut_at.desc()).all()

@router.get("/active", response_model=List[SessionResponse])
def get_active_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(SessionModel).filter(
        SessionModel.statut == StatutSession.ouverte
    ).all()

# ─────────────────────────────────────────
# MODULES DU PROFESSEUR CONNECTÉ
# ─────────────────────────────────────────

@router.get("/prof-modules")
def get_prof_modules(
    db: Session = Depends(get_db),
    prof: User = Depends(require_professeur)
):
    """
    Retourne les modules assignés au professeur connecté.
    """
    modules = db.query(Module).filter(
        Module.professeur_id == prof.id
    ).all()

    return [
        {
            "id": str(m.id),
            "nom": m.nom,
            "code": m.code,
            "semestre": m.semestre,
            "filiere": m.filiere,
            "professeur_id": str(m.professeur_id),
        }
        for m in modules
    ]

# ─────────────────────────────────────────
# MODIFIER LE STATUT D'UN ÉTUDIANT
# ─────────────────────────────────────────

class UpdateAttendanceRequest(BaseModel):
    """
    Requête pour modifier le statut d'un étudiant.
    Le prof peut passer entre 'present' et 'absent'.
    """
    statut: str  # 'present' ou 'absent'


@router.patch("/{session_id}/attendances/{student_id}")
def update_attendance_status(
    session_id: UUID,
    student_id: UUID,
    request: UpdateAttendanceRequest,
    db: Session = Depends(get_db),
    prof: User = Depends(require_professeur)
):
    """
    Permet au professeur de modifier manuellement le statut
    d'un étudiant (ex: corriger un absent en présent).

    Règles :
    - Seul le prof qui possède la session peut modifier
    - Statuts autorisés : 'present' ou 'absent' uniquement
    """

    # Récupère la session
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=404,
            detail="Session introuvable"
        )

    # Vérifie que c'est bien le prof de cette session
    if session.professeur_id != prof.id:
        raise HTTPException(
            status_code=403,
            detail="Vous n'êtes pas le professeur de cette session"
        )

    # Vérifie le statut demandé
    if request.statut not in ['present', 'absent']:
        raise HTTPException(
            status_code=400,
            detail="Statut invalide. Utilisez 'present' ou 'absent'"
        )

    # Récupère ou crée l'attendance
    attendance = db.query(Attendance).filter(
        and_(
            Attendance.session_id == session_id,
            Attendance.etudiant_id == student_id
        )
    ).first()

    if not attendance:
        # Crée un nouvel enregistrement si n'existe pas
        attendance = Attendance(
            session_id=session_id,
            etudiant_id=student_id,
            statut=StatutPresence.present if request.statut == 'present'
                   else StatutPresence.absent,
            pointed_at=datetime.utcnow() if request.statut == 'present'
                       else None,
        )
        db.add(attendance)
    else:
        # Met à jour le statut existant
        if request.statut == 'present':
            attendance.statut = StatutPresence.present
            if attendance.pointed_at is None:
                attendance.pointed_at = datetime.utcnow()
        else:
            attendance.statut = StatutPresence.absent
            attendance.pointed_at = None

    db.commit()
    db.refresh(attendance)

    return {
        "success": True,
        "message": f"Statut modifié en '{request.statut}'",
        "attendance": {
            "id": str(attendance.id),
            "session_id": str(attendance.session_id),
            "etudiant_id": str(attendance.etudiant_id),
            "statut": attendance.statut.value,
            "pointed_at": attendance.pointed_at.isoformat()
                          if attendance.pointed_at else None,
        }
    }