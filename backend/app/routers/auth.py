from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User, RoleEnum
from app.schemas.user import LoginRequest, Token, UserCreate, UserResponse
from app.core.security import hash_password, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/login", response_model=Token)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    # Cherche l'utilisateur par email
    user = db.query(User).filter(User.email == request.email).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou apogée incorrect"
        )
    
    # Vérifie l'apogée (mot de passe pour ce système)
    if not verify_password(request.apogee, user.mot_de_passe_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou apogée incorrect"
        )
    
    if not user.actif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé"
        )
    
    # Crée le token JWT
    token = create_access_token({
        "sub": str(user.id),
        "role": user.role.value,
        "email": user.email
    })
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user.role.value,
        "user": user
    }

@router.post("/register-admin", response_model=UserResponse)
def create_first_admin(user_data: UserCreate, db: Session = Depends(get_db)):
    # Vérifie si un admin existe déjà
    existing = db.query(User).filter(User.role == RoleEnum.admin).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un administrateur existe déjà"
        )
    
    # Vérifie si l'email existe
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email déjà utilisé"
        )
    
    user = User(
        nom=user_data.nom,
        prenom=user_data.prenom,
        email=user_data.email,
        apogee=user_data.apogee,
        mot_de_passe_hash=hash_password(user_data.mot_de_passe),
        role=RoleEnum.admin
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user