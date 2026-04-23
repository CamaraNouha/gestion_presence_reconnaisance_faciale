# ============================================================
# ENDPOINTS UTILISATEUR
# Permet à l'étudiant et au prof de modifier leur profil
# et à l'admin d'uploader la photo d'un étudiant
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
import numpy as np
import cv2

from app.database import get_db
from app.models.user import User
from app.models.face_embedding import FaceEmbedding
from app.schemas.user import UserResponse, UserUpdate
from app.core.dependencies import get_current_user, require_admin
from app.cv.face_engine import face_engine

router = APIRouter(prefix="/users", tags=["Utilisateurs"])


@router.get("/me", response_model=UserResponse)
def get_my_profile(
    current_user: User = Depends(get_current_user)
):
    """
    Retourne le profil de l'utilisateur connecté.
    """
    return current_user


@router.put("/me", response_model=UserResponse)
def update_my_profile(
    user_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Permet à l'utilisateur de modifier son profil.
    """
    # Met à jour seulement les champs fournis
    if user_data.nom:
        current_user.nom = user_data.nom
    if user_data.prenom:
        current_user.prenom = user_data.prenom
    if user_data.email:
        # Vérifie que le nouvel email n'est pas déjà utilisé
        existing = db.query(User).filter(
            User.email == user_data.email,
            User.id != current_user.id
        ).first()
        if existing:
            raise HTTPException(
                status_code=400,
                detail="Email déjà utilisé"
            )
        current_user.email = user_data.email

    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/{user_id}/upload-photo")
async def upload_photo(
    user_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Upload la photo d'un étudiant et génère son embedding facial.
    
    C'est cette endpoint que l'admin utilise après avoir créé
    un compte étudiant pour enregistrer son visage dans le système.
    
    L'embedding généré sera stocké en base et utilisé
    lors du pointage pour identifier l'étudiant.
    """

    # Vérifie que l'utilisateur existe
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Lit le contenu de l'image uploadée
    contents = await file.read()

    # Convertit les bytes en image OpenCV
    img_array = np.frombuffer(contents, dtype=np.uint8)
    image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(status_code=400, detail="Image invalide")

    # Extrait l'embedding facial
    embedding = face_engine.get_embedding(image)

    if embedding is None:
        raise HTTPException(
            status_code=400,
            detail="Aucun visage détecté "
        )

    # Sauvegarde ou met à jour l'embedding en base
    existing_embedding = db.query(FaceEmbedding).filter(
        FaceEmbedding.user_id == user_id
    ).first()

    if existing_embedding:
        # Met à jour l'embedding existant
        existing_embedding.embedding = embedding.tolist()
    else:
        # Crée un nouvel embedding
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