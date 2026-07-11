from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.core.security import decode_token
from app.models.user import User, RoleEnum
from jose import JWTError

security = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    token = credentials.credentials
    try:
        payload = decode_token(token)
        # Un refresh token ne doit pas servir à accéder aux ressources
        if payload.get("type") == "refresh":
            raise HTTPException(status_code=401, detail="Token invalide")
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Token invalide")
    except JWTError:
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="Utilisateur introuvable")
    if not user.actif:
        raise HTTPException(status_code=403, detail="Compte désactivé")
    return user

def require_admin(current_user: User = Depends(get_current_user)):
    if current_user.role != RoleEnum.admin:
        raise HTTPException(status_code=403, detail="Accès réservé à l'administrateur")
    return current_user

def require_professeur(current_user: User = Depends(get_current_user)):
    if current_user.role != RoleEnum.professeur:
        raise HTTPException(status_code=403, detail="Accès réservé au professeur")
    return current_user

def require_etudiant(current_user: User = Depends(get_current_user)):
    if current_user.role != RoleEnum.etudiant:
        raise HTTPException(status_code=403, detail="Accès réservé à l'étudiant")
    return current_user