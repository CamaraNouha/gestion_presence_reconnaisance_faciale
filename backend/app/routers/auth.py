from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User, RoleEnum
from app.schemas.user import (
    LoginRequest, Token, TokenRefresh, RefreshRequest,
    UserCreate, UserResponse,
)
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
)
from app.core.token_store import (
    store_refresh, is_refresh_valid, revoke_refresh,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=Token)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    Connexion par apogée + mot de passe.
    L'apogée sert d'identifiant unique (comme un username).
    Le rôle est détecté automatiquement.
    """
    # Cherche l'utilisateur par apogée
    user = db.query(User).filter(User.apogee == request.apogee).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apogée ou mot de passe incorrect"
        )

    # Vérifie le mot de passe
    if not verify_password(request.mot_de_passe, user.mot_de_passe_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apogée ou mot de passe incorrect"
        )

    # Vérifie que le compte est actif
    if not user.actif:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé"
        )

    # Crée le token d'accès (courte durée)
    token = create_access_token({
        "sub": str(user.id),
        "role": user.role.value,
        "apogee": user.apogee,
        "email": user.email
    })

    # Crée le refresh token (longue durée) et l'enregistre dans Redis
    refresh_token, jti, expire = create_refresh_token(str(user.id))
    store_refresh(jti, str(user.id), expire)

    return {
        "access_token": token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "role": user.role.value,
        "user": user
    }


@router.post("/refresh", response_model=TokenRefresh)
def refresh_token(request: RefreshRequest, db: Session = Depends(get_db)):
    """
    Échange un refresh token valide contre un nouveau couple
    (access_token, refresh_token). Rotation : l'ancien refresh
    token est révoqué à chaque appel.
    """
    # 1. Décode et valide le refresh token
    try:
        payload = decode_token(request.refresh_token)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide ou expiré"
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token fourni n'est pas un refresh token"
        )

    user_id = payload.get("sub")
    jti = payload.get("jti")
    if not user_id or not jti:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide"
        )

    # 2. Vérifie qu'il n'a pas été révoqué (présent dans Redis)
    if not is_refresh_valid(jti, user_id):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token révoqué. Veuillez vous reconnecter."
        )

    # 3. Vérifie que l'utilisateur existe toujours et est actif
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.actif:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur introuvable ou désactivé"
        )

    # 4. Rotation : révoque l'ancien, émet un nouveau couple
    revoke_refresh(jti)

    new_access = create_access_token({
        "sub": str(user.id),
        "role": user.role.value,
        "apogee": user.apogee,
        "email": user.email
    })
    new_refresh, new_jti, expire = create_refresh_token(str(user.id))
    store_refresh(new_jti, str(user.id), expire)

    return {
        "access_token": new_access,
        "refresh_token": new_refresh,
        "token_type": "bearer",
    }


@router.post("/logout")
def logout(request: RefreshRequest):
    """
    Révoque le refresh token (le supprime de Redis).
    L'access token restant expirera de lui-même (courte durée).
    """
    try:
        payload = decode_token(request.refresh_token)
        jti = payload.get("jti")
        if jti:
            revoke_refresh(jti)
    except JWTError:
        # Token déjà expiré/invalide → rien à révoquer
        pass

    return {"message": "Déconnexion réussie"}


@router.post("/register-admin", response_model=UserResponse)
def create_first_admin(user_data: UserCreate, db: Session = Depends(get_db)):
    """
    Crée le premier administrateur du système.
    Cet endpoint ne fonctionne que s'il n'y a aucun admin.
    """
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

    # Vérifie si l'apogée existe
    if db.query(User).filter(User.apogee == user_data.apogee).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Apogée déjà utilisé"
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