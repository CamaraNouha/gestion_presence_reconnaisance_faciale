# ============================================================
# CONFIGURATION PYTEST — exécutée avant l'import des tests
# Fournit les variables d'environnement minimales pour que les
# modules (security, database) s'importent sans .env réel.
# ============================================================

import os
import sys

# Répertoire backend dans le path (pytest lancé depuis backend/)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("SECRET_KEY", "cle-de-test-ci")
os.environ.setdefault("ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
