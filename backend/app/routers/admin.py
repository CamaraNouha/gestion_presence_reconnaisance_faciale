from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
import numpy as np
import cv2

from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.other import UserModule, Schedule
from app.models.face_embedding import FaceEmbedding
from app.schemas.user import UserResponse
from app.schemas.module import ModuleCreate, ModuleUpdate, ModuleResponse
from app.schemas.schedule import ScheduleCreate, ScheduleResponse
from app.core.security import hash_password
from app.core.dependencies import require_admin
from app.cv.face_engine import face_engine

from app.models.face_embedding import FaceEmbedding
from app.models.other import UserModule
from app.models.attendance import Attendance
from app.models.session import Session as SessionModel

router = APIRouter(prefix="/admin", tags=["Administration"])

# ─────────────────────────────────────────
# CRÉER UN UTILISATEUR AVEC PHOTO
# ─────────────────────────────────────────

@router.post("/users", response_model=UserResponse)
async def create_user(
    nom: str = Form(...),
    prenom: str = Form(...),
    email: str = Form(...),
    apogee: str = Form(...),
    mot_de_passe: str = Form(...),
    role: str = Form(...),
    photo: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Crée un compte utilisateur avec photo en une seule requête.
    Pour les étudiants : la photo est obligatoire.
    Pour les professeurs et admins : la photo est optionnelle.
    """

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    if db.query(User).filter(User.apogee == apogee).first():
        raise HTTPException(status_code=400, detail="Numéro apogée déjà utilisé")

    if role == "etudiant" and photo is None:
        raise HTTPException(
            status_code=400,
            detail="La photo est obligatoire pour les étudiants"
        )

    try:
        role_enum = RoleEnum(role)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Rôle invalide : {role}. Valeurs acceptées admin, professeur, etudiant"
        )

    user = User(
        nom=nom,
        prenom=prenom,
        email=email,
        apogee=apogee,
        mot_de_passe_hash=hash_password(mot_de_passe),
        role=role_enum
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if photo is not None:
        contents = await photo.read()
        img_array = np.frombuffer(contents, dtype=np.uint8)
        image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)

        if image is None:
            raise HTTPException(status_code=400, detail="Image invalide")

        embedding = face_engine.get_embedding(image)

        if embedding is None:
            db.delete(user)
            db.commit()
            raise HTTPException(status_code=400, detail="Aucun visage détecté")

        face_emb = FaceEmbedding(
            user_id=user.id,
            embedding=embedding.tolist()
        )
        db.add(face_emb)
        db.commit()

    return user


# ─────────────────────────────────────────
# LISTE DES UTILISATEURS
# ─────────────────────────────────────────

@router.get("/users", response_model=List[UserResponse])
def get_all_users(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    return db.query(User).all()

@router.get("/users/{user_id}", response_model=UserResponse)
def get_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user

@router.put("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    nom: str = Form(...),
    prenom: str = Form(...),
    email: str = Form(...),
    apogee: Optional[str] = Form(None),
    mot_de_passe: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    user.nom = nom
    user.prenom = prenom
    user.email = email
    if apogee:
        user.apogee = apogee
    if mot_de_passe:
        user.mot_de_passe_hash = hash_password(mot_de_passe)

    db.commit()
    db.refresh(user)
    return user

@router.delete("/users/{user_id}")
def delete_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    try:
        db.query(FaceEmbedding).filter(FaceEmbedding.user_id == user_id).delete()
        db.query(UserModule).filter(UserModule.user_id == user_id).delete()
        db.query(Attendance).filter(Attendance.etudiant_id == user_id).delete()

        if user.role == RoleEnum.professeur:
            sessions = db.query(SessionModel).filter(
                SessionModel.professeur_id == user_id
            ).all()
            for session in sessions:
                db.query(Attendance).filter(
                    Attendance.session_id == session.id
                ).delete()
            db.query(SessionModel).filter(
                SessionModel.professeur_id == user_id
            ).delete()

        db.delete(user)
        db.commit()

        return {"message": f"Utilisateur {user.prenom} {user.nom} supprimé"}

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Erreur suppression : {str(e)}")


# ─────────────────────────────────────────
# MODULES
# ─────────────────────────────────────────

@router.post("/modules", response_model=ModuleResponse)
def create_module(
    module_data: ModuleCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    if db.query(Module).filter(Module.code == module_data.code).first():
        raise HTTPException(status_code=400, detail="Code module déjà utilisé")

    prof = db.query(User).filter(
        User.id == module_data.professeur_id,
        User.role == RoleEnum.professeur
    ).first()
    if not prof:
        raise HTTPException(status_code=404, detail="Professeur introuvable")

    module = Module(**module_data.model_dump())
    db.add(module)
    db.commit()
    db.refresh(module)
    return module

@router.get("/modules", response_model=List[ModuleResponse])
def get_modules(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    return db.query(Module).all()

@router.put("/modules/{module_id}", response_model=ModuleResponse)
def update_module(
    module_id: UUID,
    module_data: ModuleUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")
    for key, value in module_data.model_dump(exclude_none=True).items():
        setattr(module, key, value)
    db.commit()
    db.refresh(module)
    return module

@router.delete("/modules/{module_id}")
def delete_module(
    module_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Supprime un module avec toutes ses données liées :
    - Sessions du module
    - Présences des sessions
    - Inscriptions des étudiants
    - Créneaux d'emploi du temps
    """
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")

    try:
        # 1. Récupère toutes les sessions du module
        sessions = db.query(SessionModel).filter(
            SessionModel.module_id == module_id
        ).all()

        # 2. Supprime les présences de chaque session
        for session in sessions:
            db.query(Attendance).filter(
                Attendance.session_id == session.id
            ).delete()

        # 3. Supprime les sessions
        db.query(SessionModel).filter(
            SessionModel.module_id == module_id
        ).delete()

        # 4. Supprime les inscriptions étudiants au module
        db.query(UserModule).filter(
            UserModule.module_id == module_id
        ).delete()

        # 5. Supprime les créneaux d'emploi du temps
        db.query(Schedule).filter(
            Schedule.module_id == module_id
        ).delete()

        # 6. Supprime le module
        db.delete(module)
        db.commit()

        return {"message": f"Module {module.nom} supprimé avec succès"}

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Erreur suppression : {str(e)}"
        )


# ─────────────────────────────────────────
# ÉTUDIANTS INSCRITS À UN MODULE  ← NOUVEAU
# ─────────────────────────────────────────

@router.get("/modules/{module_id}/students", response_model=List[UserResponse])
def get_module_students(
    module_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Retourne la liste des étudiants inscrits à un module.
    Utilisé par l'écran 'Inscriptions modules' du dashboard admin.
    """
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")

    inscriptions = db.query(UserModule).filter(
        UserModule.module_id == module_id
    ).all()

    student_ids = [i.user_id for i in inscriptions]

    if not student_ids:
        return []

    students = db.query(User).filter(
        User.id.in_(student_ids),
        User.role == RoleEnum.etudiant
    ).all()

    return students


# ─────────────────────────────────────────
# INSCRIPTIONS
# ─────────────────────────────────────────

@router.post("/modules/{module_id}/students/{student_id}")
def assign_student(
    module_id: UUID,
    student_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")

    student = db.query(User).filter(
        User.id == student_id,
        User.role == RoleEnum.etudiant
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Étudiant introuvable")

    existing = db.query(UserModule).filter(
        UserModule.user_id == student_id,
        UserModule.module_id == module_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Étudiant déjà inscrit")

    inscription = UserModule(user_id=student_id, module_id=module_id)
    db.add(inscription)
    db.commit()
    return {"message": "Étudiant inscrit au module"}

@router.delete("/modules/{module_id}/students/{student_id}")
def remove_student(
    module_id: UUID,
    student_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    inscription = db.query(UserModule).filter(
        UserModule.user_id == student_id,
        UserModule.module_id == module_id
    ).first()
    if not inscription:
        raise HTTPException(status_code=404, detail="Inscription introuvable")
    db.delete(inscription)
    db.commit()
    return {"message": "Étudiant retiré du module"}


# ─────────────────────────────────────────
# EMPLOI DU TEMPS
# ─────────────────────────────────────────

@router.post("/schedules", response_model=ScheduleResponse)
def create_schedule(
    schedule_data: ScheduleCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    schedule = Schedule(**schedule_data.model_dump())
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return schedule

@router.get("/schedules", response_model=List[ScheduleResponse])
def get_schedules(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    return db.query(Schedule).all()

@router.delete("/schedules/{schedule_id}")
def delete_schedule(
    schedule_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    schedule = db.query(Schedule).filter(Schedule.id == schedule_id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Créneau introuvable")
    db.delete(schedule)
    db.commit()
    return {"message": "Créneau supprimé"}