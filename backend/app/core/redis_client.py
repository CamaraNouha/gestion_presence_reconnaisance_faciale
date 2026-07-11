# ============================================================
# CLIENT REDIS — partagé par l'app (révocation des refresh tokens)
# Réutilise la même instance Redis que Celery.
# ============================================================

import os
import redis

REDIS_URL = os.getenv("REDIS_URL", "redis://127.0.0.1:6379/0")

# decode_responses=True → les valeurs reviennent en str (pas en bytes)
redis_client = redis.from_url(REDIS_URL, decode_responses=True)
