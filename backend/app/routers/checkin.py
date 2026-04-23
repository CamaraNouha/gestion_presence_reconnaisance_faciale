# ============================================================
# ENDPOINT DE POINTAGE — Reconnaissance faciale
#
# Ce router gère le pointage de présence d'un étudiant :
# 1. Reçoit le frame base64 depuis Flutter
# 2. Extrait l'embedding du visage
# 3. Compare avec tous les embeddings stockés en base
# 4. Si trouvé → marque présent, sinon → refuse
#vérification géolocalisation
# par rayon autour de la position du professeur
# ============================================================


from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_
import numpy as np
from uuid import UUID
from datetime import datetime
import math

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

# ── Rayon maximum autorisé en mètres ─────────────────────────
# 50m = tolérance pour une salle de classe normale
# Le prof est au bureau, les étudiants au fond = ~10-15m
# On met 50m pour avoir une marge confortable
RAYON_MAX_METRES = 50.0


def calculer_distance_metres(
    lat1: float, lon1: float,
    lat2: float, lon2: float
) -> float:
    """
    Calcule la distance en mètres entre 2 points GPS
    en utilisant la formule de Haversine.

    Args:
        lat1, lon1 : coordonnées du professeur (session)
        lat2, lon2 : coordonnées de l'étudiant (pointage)

    Returns:
        Distance en mètres
    """

    # Rayon de la Terre en mètres
    R = 6_371_000

    # Convertit les degrés en radians
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    # Formule Haversine
    a = (math.sin(delta_phi / 2) ** 2 +
         math.cos(phi1) * math.cos(phi2) *
         math.sin(delta_lambda / 2) ** 2)

    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    # Distance en mètres
    return R * c


@router.post("/")
def checkin(
    request: CheckinRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Endpoint de pointage de présence.
    Vérifie :
    1. Session ouverte
    2. Étudiant inscrit au module
    3. Géolocalisation dans le rayon autorisé
    4. Reconnaissance faciale
    """

    # ── Étape 1 : Vérifie que la session est ouverte ──────────
    session = db.query(SessionModel).filter(
        SessionModel.id == request.session_id,
        SessionModel.statut == StatutSession.ouverte
    ).first()

    if not session:
        raise HTTPException(
            status_code=404,
            detail="Session introuvable ou déjà fermée"
        )

    # ── Étape 2 : Vérifie l'inscription au module ─────────────
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

    # ── Étape 3 : Vérifie déjà pointé ────────────────────────
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

    # ── Étape 4 : Vérifie la géolocalisation ─────────────────
    # Seulement si le prof a défini sa position ET
    # que l'étudiant envoie sa position
    if (session.latitude is not None and
        session.longitude is not None and
        request.latitude is not None and
        request.longitude is not None):

        # Calcule la distance entre étudiant et prof
        distance = calculer_distance_metres(
            session.latitude, session.longitude,
            request.latitude, request.longitude
        )

        # Vérifie que l'étudiant est dans le rayon autorisé
        if distance > RAYON_MAX_METRES:
            raise HTTPException(
                status_code=403,
                detail=f"Vous êtes trop loin de la salle ({distance:.0f}m). "
                       f"Rayon autorisé : {RAYON_MAX_METRES:.0f}m"
            )

    # ── Étape 5 : Reconnaissance faciale ─────────────────────
    embedding_from_camera = face_engine.get_embedding_from_base64(
        request.frame_base64
    )

    if embedding_from_camera is None:
        raise HTTPException(
            status_code=400,
            detail="Aucun visage détecté — placez votre visage face à la caméra"
        )

    # ── Étape 6 : Récupère les embeddings du module ───────────
    inscriptions = db.query(UserModule).filter(
        UserModule.module_id == session.module_id
    ).all()
    student_ids = [i.user_id for i in inscriptions]

    stored_embeddings = db.query(FaceEmbedding).filter(
        FaceEmbedding.user_id.in_(student_ids)
    ).all()

    if not stored_embeddings:
        raise HTTPException(
            status_code=404,
            detail="Aucun embedding trouvé pour ce module"
        )

    # ── Étape 7 : Compare les embeddings ──────────────────────
    best_match_user_id = None
    best_score = 0.0

    for stored in stored_embeddings:
        stored_vector = np.array(stored.embedding)
        is_same, score = face_engine.is_same_person(
            embedding_from_camera,
            stored_vector
        )
        if score > best_score:
            best_score = score
            if is_same:
                best_match_user_id = stored.user_id

    # ── Étape 8 : Vérifie le résultat ─────────────────────────
    if best_match_user_id is None:
        raise HTTPException(
            status_code=401,
            detail=f"Visage non reconnu (score: {best_score:.3f})"
        )

    if str(best_match_user_id) != str(current_user.id):
        raise HTTPException(
            status_code=401,
            detail="Le visage ne correspond pas à votre compte"
        )

    # ── Étape 9 : Marque présent ──────────────────────────────
    if attendance:
        attendance.statut = StatutPresence.present
        attendance.pointed_at = datetime.utcnow()
        attendance.latitude = request.latitude
        attendance.longitude = request.longitude
    else:
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
        "score_facial": round(best_score, 4),
        "pointed_at": datetime.utcnow().isoformat()
    }