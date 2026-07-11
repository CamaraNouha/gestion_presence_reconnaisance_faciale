# ============================================================
# TOKEN STORE — allowlist des refresh tokens dans Redis
#
# Principe : chaque refresh token émis a un identifiant unique
# (jti) stocké dans Redis avec une expiration (TTL) égale à
# celle du token. La révocation = suppression de la clé.
#  - Rotation : à chaque /auth/refresh, l'ancien jti est
#    supprimé et un nouveau est stocké.
#  - Logout : le jti est supprimé → le refresh token devient
#    inutilisable immédiatement.
# ============================================================

from datetime import datetime

from app.core.redis_client import redis_client

_PREFIX = "refresh:"


def store_refresh(jti: str, user_id: str, expire: datetime) -> None:
    """Enregistre un refresh token valide avec un TTL."""
    ttl = int((expire - datetime.utcnow()).total_seconds())
    if ttl > 0:
        redis_client.set(f"{_PREFIX}{jti}", str(user_id), ex=ttl)


def is_refresh_valid(jti: str, user_id: str) -> bool:
    """Vérifie que le refresh token n'a pas été révoqué/tourné."""
    value = redis_client.get(f"{_PREFIX}{jti}")
    return value is not None and value == str(user_id)


def revoke_refresh(jti: str) -> None:
    """Révoque un refresh token (logout ou rotation)."""
    redis_client.delete(f"{_PREFIX}{jti}")
