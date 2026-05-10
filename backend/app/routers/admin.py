from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
import numpy as np
import cv2
import io
import csv
from openpyxl import load_workbook

from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.other import UserModule
from app.models.face_embedding import FaceEmbedding
from app.schemas.user import UserResponse
from app.schemas.module import ModuleCreate, ModuleUpdate, ModuleResponse
from app.core.security import hash_password
from app.core.dependencies import require_admin
from app.cv.face_engine import face_engine

from app.models.face_embedding import FaceEmbedding
from app.models.other import UserModule
from app.models.attendance import Attendance
from app.models.session import Session as SessionModel

router = APIRouter(prefix="/admin", tags=["Administration"])

# ─────────────────────────────────────────
# CRÉER UN UTILISATEUR
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
    Crée un compte utilisateur.
    Pour les étudiants : la photo est ajouté par admin ou eux meme pour la 1ere connexion.
    Pour les professeurs et admins : la photo est optionnelle.
    """

    if db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    if db.query(User).filter(User.apogee == apogee).first():
        raise HTTPException(status_code=400, detail="Numéro apogée déjà utilisé")


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
# IMPORT EN BLOC D'ÉTUDIANTS (CSV ou Excel)
# ─────────────────────────────────────────

@router.post("/users/bulk-import")
async def bulk_import_students(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin)
):
    """
    Importe une liste d'étudiants depuis un fichier CSV ou Excel.
    
    Format attendu (colonnes) :
    - nom, prenom, email, apogee, mot_de_passe (optionnel)
    
    Les étudiants sont créés SANS photo.
    Ils devront ajouter leur photo à leur première connexion.
    """
    
    # Lit le contenu
    contents = await file.read()
    filename = file.filename.lower()
    
    rows = []
    
    try:
        # Détection du format
        if filename.endswith('.csv'):
            # Parse CSV
            text = contents.decode('utf-8-sig')  # Gère le BOM
            reader = csv.DictReader(io.StringIO(text))
            rows = list(reader)
        
        elif filename.endswith('.xlsx') or filename.endswith('.xls'):
            # Parse Excel
            wb = load_workbook(io.BytesIO(contents), read_only=True)
            ws = wb.active
            
            # Récupère les en-têtes (1ère ligne)
            headers = []
            for cell in ws[1]:
                headers.append(str(cell.value).strip().lower() if cell.value else '')
            
            # Récupère les données
            for row in ws.iter_rows(min_row=2, values_only=True):
                if all(v is None for v in row):
                    continue  # Ligne vide
                
                row_dict = {}
                for i, value in enumerate(row):
                    if i < len(headers):
                        row_dict[headers[i]] = str(value).strip() if value else ''
                rows.append(row_dict)
        else:
            raise HTTPException(
                status_code=400,
                detail="Format non supporté. Utilisez CSV ou Excel (.xlsx)"
            )
    
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Erreur lecture fichier : {str(e)}"
        )
    
    if not rows:
        raise HTTPException(
            status_code=400,
            detail="Le fichier est vide ou mal formaté"
        )
    
    # Compteurs
    created = 0
    errors = []
    
    # Traite chaque ligne
    for i, row in enumerate(rows, start=2):  # start=2 car ligne 1 = headers
        try:
            # Récupère les champs (insensible à la casse)
            row_lower = {k.lower().strip(): v for k, v in row.items() if k}
            
            nom = row_lower.get('nom', '').strip()
            prenom = row_lower.get('prenom', '').strip()
            email = row_lower.get('email', '').strip()
            apogee = row_lower.get('apogee', '').strip()
            mot_de_passe = row_lower.get('mot_de_passe', '').strip()
            
            # Validation des champs requis
            if not nom or not prenom or not email or not apogee:
                errors.append({
                    "ligne": i,
                    "erreur": "Champs manquants (nom, prenom, email, apogee requis)"
                })
                continue
            
            # Si pas de mot de passe → utilise l'apogée
            if not mot_de_passe:
                mot_de_passe = apogee
            
            # Vérifie unicité email
            if db.query(User).filter(User.email == email).first():
                errors.append({
                    "ligne": i,
                    "erreur": f"Email déjà utilisé : {email}"
                })
                continue
            
            # Vérifie unicité apogée
            if db.query(User).filter(User.apogee == apogee).first():
                errors.append({
                    "ligne": i,
                    "erreur": f"Apogée déjà utilisé : {apogee}"
                })
                continue
            
            # Crée l'étudiant SANS photo
            user = User(
                nom=nom,
                prenom=prenom,
                email=email,
                apogee=apogee,
                mot_de_passe_hash=hash_password(mot_de_passe),
                role=RoleEnum.etudiant
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            
            created += 1
        
        except Exception as e:
            db.rollback()
            errors.append({
                "ligne": i,
                "erreur": str(e)
            })
    
    return {
        "success": True,
        "total": len(rows),
        "created": created,
        "errors": errors,
        "message": f"{created} étudiant(s) créé(s) sur {len(rows)} ligne(s)"
    }

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
    """
    Supprime un utilisateur avec toutes ses données liées.
    
    Cas selon le rôle :
    - Étudiant : embeddings + inscriptions + présences
    - Professeur : tous ses modules (avec sessions/présences/inscriptions)
    - Admin : profil seulement
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=404,
            detail="Utilisateur introuvable"
        )

    try:
        # 1. Supprime les embeddings faciaux (étudiant)
        db.query(FaceEmbedding).filter(
            FaceEmbedding.user_id == user_id
        ).delete()

        # 2. Supprime les inscriptions aux modules (étudiant)
        db.query(UserModule).filter(
            UserModule.user_id == user_id
        ).delete()

        # 3. Supprime les présences de l'utilisateur (étudiant)
        db.query(Attendance).filter(
            Attendance.etudiant_id == user_id
        ).delete()

        # 4. Si c'est un PROF → supprime tous ses modules
        if user.role == RoleEnum.professeur:
            # Récupère tous les modules du prof
            prof_modules = db.query(Module).filter(
                Module.professeur_id == user_id
            ).all()

            for module in prof_modules:
                # 4a. Récupère les sessions du module
                module_sessions = db.query(SessionModel).filter(
                    SessionModel.module_id == module.id
                ).all()

                # 4b. Supprime les présences de chaque session
                for session in module_sessions:
                    db.query(Attendance).filter(
                        Attendance.session_id == session.id
                    ).delete()

                # 4c. Supprime les sessions du module
                db.query(SessionModel).filter(
                    SessionModel.module_id == module.id
                ).delete()

                # 4d. Supprime les inscriptions étudiants au module
                db.query(UserModule).filter(
                    UserModule.module_id == module.id
                ).delete()

                # 4f. Supprime le module
                db.delete(module)

            # 5. Supprime aussi les sessions où le prof est listé directement
            prof_sessions = db.query(SessionModel).filter(
                SessionModel.professeur_id == user_id
            ).all()
            for session in prof_sessions:
                db.query(Attendance).filter(
                    Attendance.session_id == session.id
                ).delete()
            db.query(SessionModel).filter(
                SessionModel.professeur_id == user_id
            ).delete()

        # 6. Supprime l'utilisateur
        db.delete(user)
        db.commit()

        return {
            "message": f"Utilisateur {user.prenom} {user.nom} supprimé"
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Erreur suppression : {str(e)}"
        )

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



