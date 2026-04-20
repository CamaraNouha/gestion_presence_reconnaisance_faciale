# ============================================================
# SCRIPT D'INITIALISATION — Lance les migrations automatiquement
# Exécuté une seule fois au premier démarrage du container
# ============================================================

import subprocess
import sys
import time

def run_migrations():
    """Lance les migrations Alembic."""
    print("Lancement des migrations Alembic...")
    result = subprocess.run(
        ["alembic", "upgrade", "head"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Erreur migrations:", result.stderr)
        sys.exit(1)
    print("Migrations OK !")

if __name__ == "__main__":
    # Attend que PostgreSQL soit prêt
    time.sleep(3)
    run_migrations()
    print("Base de données prête !")