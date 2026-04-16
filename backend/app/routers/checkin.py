# ============================================================
# ENDPOINT DE POINTAGE — Reconnaissance faciale
#
# Ce router gère le pointage de présence d'un étudiant :
# 1. Reçoit le frame base64 depuis Flutter
# 2. Extrait l'embedding du visage
# 3. Compare avec tous les embeddings stockés en base
# 4. Si trouvé → marque présent, sinon → refuse
# ============================================================

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_
import numpy as np
from uuid import UUID
from datetime import datetime

from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.session import Session as SessionModel, StatutSession
from app.models.attendance import Attendance, StatutPresence
from app.models.face_embedding import FaceEmbedding
from app.models.other import UserModule
from app.schemas.attendance import CheckinRequest
from app.core.dependencies import get_current_user
from app.cv.face_engine import face_engine, SIMILARITY_THRESHOLD

router = APIRouter(prefix="/checkin", tags=["Pointage"])


@router.post("/")
def checkin(
    request: CheckinRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Endpoint principal de pointage.
    
    Reçoit :
    - session_id : ID de la session active
    - latitude/longitude : position GPS de l'étudiant
    - frame_base64 : photo prise par la caméra Flutter
    
    Retourne :
    - statut : "present" ou message d'erreur
    - score : score de similarité
    """

    # ── Étape 1 : Vérifie que la session existe et est ouverte ─
    session = db.query(SessionModel).filter(
        SessionModel.id == request.session_id,
        SessionModel.statut == StatutSession.ouverte
    ).first()

    if not session:
        raise HTTPException(
            status_code=404,
            detail="Session introuvable ou déjà fermée"
        )

    # ── Étape 2 : Vérifie que l'étudiant est inscrit au module ─
    inscription = db.query(UserModule).filter(
        and_(
            UserModule.user_id == current_user.id,
            UserModule.module_id == session.module_id
        )
    ).first()

    if not inscription:
        raise HTTPException(
            status_code=403,
            detail="Vous n'êtes pas inscrit dans ce module"
        )

    # ── Étape 3 : Vérifie que l'étudiant n'a pas déjà pointé ──
    attendance = db.query(Attendance).filter(
        and_(
            Attendance.session_id == request.session_id,
            Attendance.etudiant_id == current_user.id
        )
    ).first()

    if attendance and attendance.statut == StatutPresence.present:
        return {
            "statut": "déjà pointé",
            "message": "Vous avez déjà marqué votre présence"
        }

    # ── Étape 4 : Extrait l'embedding du frame reçu ────────────
    # C'est ici qu'on utilise YuNet + SFace
    embedding_from_camera = face_engine.get_embedding_from_base64(
        request.frame_base64
    )

    if embedding_from_camera is None:
        raise HTTPException(
            status_code=400,
            detail="Aucun visage détecté — placez votre visage face à la caméra"
        )

    # ── Étape 5 : Récupère l'embedding stocké en base ──────────
    # On récupère SEULEMENT l'embedding des étudiants
    # inscrits à ce module pour optimiser la recherche
    inscriptions = db.query(UserModule).filter(
        UserModule.module_id == session.module_id
    ).all()

    student_ids = [i.user_id for i in inscriptions]

    # Récupère tous les embeddings des étudiants du module
    stored_embeddings = db.query(FaceEmbedding).filter(
        FaceEmbedding.user_id.in_(student_ids)
    ).all()

    if not stored_embeddings:
        raise HTTPException(
            status_code=404,
            detail="Aucun embedding trouvé pour ce module"
        )

    # ── Étape 6 : Compare l'embedding avec ceux en base ────────
    best_match_user_id = None
    best_score = 0.0

    for stored in stored_embeddings:
        # Convertit le vecteur stocké en base en tableau NumPy
        stored_vector = np.array(stored.embedding)

        # Compare les 2 embeddings
        is_same, score = face_engine.is_same_person(
            embedding_from_camera,
            stored_vector
        )

        # Garde le meilleur score
        if score > best_score:
            best_score = score
            if is_same:
                best_match_user_id = stored.user_id

    # ── Étape 7 : Analyse le résultat ──────────────────────────
    if best_match_user_id is None:
        # Aucun visage correspondant trouvé
        raise HTTPException(
            status_code=401,
            detail=f"Visage non reconnu (score: {best_score:.3f})"
        )

    # Vérifie que la personne reconnue est bien l'étudiant connecté
    if str(best_match_user_id) != str(current_user.id):
        raise HTTPException(
            status_code=401,
            detail="Le visage ne correspond pas à votre compte"
        )

    # ── Étape 8 : Marque l'étudiant présent ────────────────────
    if attendance:
        # Met à jour l'entrée existante
        attendance.statut = StatutPresence.present
        attendance.pointed_at = datetime.utcnow()
        attendance.latitude = request.latitude
        attendance.longitude = request.longitude
    else:
        # Crée une nouvelle entrée
        attendance = Attendance(
            session_id=request.session_id,
            etudiant_id=current_user.id,
            statut=StatutPresence.present,
            pointed_at=datetime.utcnow(),
            latitude=request.latitude,
            longitude=request.longitude
        )
        db.add(attendance)

    db.commit()

    return {
        "statut": "present",
        "message": "Présence enregistrée avec succès",
        "score": round(best_score, 4),
        "pointed_at": datetime.utcnow().isoformat()
    }