# ============================================================
# DATABASE — lit l'URL depuis les variables d'environnement
# Quand on est dans Docker, l'URL pointe vers le container 'db'
# Quand on est en local, l'URL pointe vers 127.0.0.1:5433
# ============================================================

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Lit l'URL depuis les variables d'environnement
# Si non définie, utilise l'URL locale par défaut
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://eniad_user:eniad_pass@127.0.0.1:5433/eniad_db"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()