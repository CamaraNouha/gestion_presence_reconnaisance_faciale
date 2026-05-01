# ============================================================
# ENDPOINTS UTILISATEUR
# Permet à l'étudiant et au prof de modifier leur profil
# et à l'admin d'uploader la photo d'un étudiant
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
import numpy as np
import cv2

from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.other import UserModule
from app.models.face_embedding import FaceEmbedding
from app.schemas.user import UserResponse, UserUpdate
from app.core.dependencies import get_current_user, require_admin
from app.core.security import hash_password, verify_password
from app.cv.face_engine import face_engine

router = APIRouter(prefix="/users", tags=["Utilisateurs"])


# ─────────────────────────────────────────
# MON PROFIL
# ─────────────────────────────────────────

@router.get("/me", response_model=UserResponse)
def get_my_profile(
    current_user: User = Depends(get_current_user)
):
    """Retourne le profil de l'utilisateur connecté."""
    return current_user


@router.put("/me", response_model=UserResponse)
def update_my_profile(
    user_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Permet à l'utilisateur de modifier son profil."""
    if user_data.nom:
        current_user.nom = user_data.nom
    if user_data.prenom:
        current_user.prenom = user_data.prenom
    if user_data.email:
        existing = db.query(User).filter(
            User.email == user_data.email,
            User.id != current_user.id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email déjà utilisé")
        current_user.email = user_data.email

    db.commit()
    db.refresh(current_user)
    return current_user


# ─────────────────────────────────────────
# CHANGER MOT DE PASSE  ← NOUVEAU
# ─────────────────────────────────────────

@router.put("/me/password")
def change_my_password(
    ancien_mot_de_passe: str = Form(...),
    nouveau_mot_de_passe: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Change le mot de passe de l'utilisateur connecté.
    Nécessite l'ancien mot de passe pour confirmer.
    """
    # Vérifie l'ancien mot de passe
    if not verify_password(ancien_mot_de_passe, current_user.mot_de_passe_hash):
        raise HTTPException(
            status_code=400,
            detail="Ancien mot de passe incorrect"
        )

    # Vérifie longueur minimum
    if len(nouveau_mot_de_passe) < 4:
        raise HTTPException(
            status_code=400,
            detail="Le nouveau mot de passe doit faire au moins 4 caractères"
        )

    # Hash et sauvegarde
    current_user.mot_de_passe_hash = hash_password(nouveau_mot_de_passe)
    db.commit()

    return {
        "success": True,
        "message": "Mot de passe modifié avec succès"
    }


# ─────────────────────────────────────────
# MES PRÉSENCES (étudiant)
# ─────────────────────────────────────────

@router.get("/me/attendances")
def get_my_attendances(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retourne l'historique de présences de l'étudiant."""
    from app.models.attendance import Attendance
    attendances = db.query(Attendance).filter(
        Attendance.etudiant_id == current_user.id
    ).order_by(Attendance.created_at.desc()).all()

    return [
        {
            "id": str(a.id),
            "session_id": str(a.session_id),
            "statut": a.statut.value if a.statut else None,
            "pointed_at": a.pointed_at.isoformat() if a.pointed_at else None,
            "latitude": a.latitude,
            "longitude": a.longitude,
        }
        for a in attendances
    ]


# ─────────────────────────────────────────
# MES MODULES (étudiant)  ← NOUVEAU
# ─────────────────────────────────────────

@router.get("/me/my-modules")
def get_my_modules(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Retourne les modules auxquels l'étudiant connecté est inscrit.
    Inclut les infos du professeur de chaque module.
    """
    if current_user.role != RoleEnum.etudiant:
        raise HTTPException(
            status_code=403,
            detail="Cet endpoint est réservé aux étudiants"
        )

    inscriptions = db.query(UserModule).filter(
        UserModule.user_id == current_user.id
    ).all()

    module_ids = [i.module_id for i in inscriptions]

    if not module_ids:
        return []

    modules = db.query(Module).filter(Module.id.in_(module_ids)).all()

    result = []
    for m in modules:
        prof = db.query(User).filter(User.id == m.professeur_id).first()
        result.append({
            "id": str(m.id),
            "nom": m.nom,
            "code": m.code,
            "semestre": m.semestre,
            "filiere": m.filiere,
            "professeur": {
                "id": str(prof.id) if prof else None,
                "nom": prof.nom if prof else "",
                "prenom": prof.prenom if prof else "",
            } if prof else None,
        })

    return result


# ─────────────────────────────────────────
# UPLOAD PHOTO
# ─────────────────────────────────────────

@router.post("/{user_id}/upload-photo")
async def upload_photo(
    user_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Upload la photo d'un étudiant et génère son embedding facial.
    Utilisé par l'admin après création d'un compte étudiant.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    contents = await file.read()
    img_array = np.frombuffer(contents, dtype=np.uint8)
    image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(status_code=400, detail="Image invalide")

    embedding = face_engine.get_embedding(image)

    if embedding is None:
        raise HTTPException(status_code=400, detail="Aucun visage détecté")

    existing_embedding = db.query(FaceEmbedding).filter(
        FaceEmbedding.user_id == user_id
    ).first()

    if existing_embedding:
        existing_embedding.embedding = embedding.tolist()
    else:
        new_embedding = FaceEmbedding(
            user_id=user_id,
            embedding=embedding.tolist()
        )
        db.add(new_embedding)

    db.commit()

    return {
        "message": "Photo uploadée et embedding généré avec succès",
        "user_id": user_id,
        "embedding_dimensions": len(embedding)
    }