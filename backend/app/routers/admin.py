from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.other import UserModule, Schedule
from app.schemas.user import UserCreate, UserResponse
from app.schemas.module import ModuleCreate, ModuleUpdate, ModuleResponse
from app.schemas.schedule import ScheduleCreate, ScheduleResponse
from app.core.security import hash_password
from app.core.dependencies import require_admin

router = APIRouter(prefix="/admin", tags=["Administration"])

# ─────────────────────────────────────────
# GESTION DES UTILISATEURS
# ─────────────────────────────────────────

@router.post("/users", response_model=UserResponse)
def create_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    # Vérifie email unique
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    # Vérifie apogée unique si fourni
    if user_data.apogee and db.query(User).filter(User.apogee == user_data.apogee).first():
        raise HTTPException(status_code=400, detail="Numéro apogée déjà utilisé")

    user = User(
        nom=user_data.nom,
        prenom=user_data.prenom,
        email=user_data.email,
        apogee=user_data.apogee,
        mot_de_passe_hash=hash_password(user_data.mot_de_passe),
        role=user_data.role
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

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
    user_data: UserCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    user.nom = user_data.nom
    user.prenom = user_data.prenom
    user.email = user_data.email
    if user_data.apogee:
        user.apogee = user_data.apogee
    if user_data.mot_de_passe:
        user.mot_de_passe_hash = hash_password(user_data.mot_de_passe)

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
    db.delete(user)
    db.commit()
    return {"message": "Utilisateur supprimé"}

@router.get("/students", response_model=List[UserResponse])
def get_students(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    return db.query(User).filter(User.role == RoleEnum.etudiant).all()

@router.get("/professors", response_model=List[UserResponse])
def get_professors(
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    return db.query(User).filter(User.role == RoleEnum.professeur).all()

# ─────────────────────────────────────────
# GESTION DES MODULES
# ─────────────────────────────────────────

@router.post("/modules", response_model=ModuleResponse)
def create_module(
    module_data: ModuleCreate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    # Vérifie que le code est unique
    if db.query(Module).filter(Module.code == module_data.code).first():
        raise HTTPException(status_code=400, detail="Code module déjà utilisé")

    # Vérifie que le professeur existe
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
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")
    db.delete(module)
    db.commit()
    return {"message": "Module supprimé"}

# ─────────────────────────────────────────
# INSCRIPTION ÉTUDIANT À UN MODULE
# ─────────────────────────────────────────

@router.post("/modules/{module_id}/students/{student_id}")
def assign_student(
    module_id: UUID,
    student_id: UUID,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    # Vérifie module et étudiant
    module = db.query(Module).filter(Module.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module introuvable")

    student = db.query(User).filter(
        User.id == student_id,
        User.role == RoleEnum.etudiant
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Étudiant introuvable")

    # Vérifie si déjà inscrit
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