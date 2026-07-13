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

# Pool dimensionné pour la charge (100 étudiants simultanés) :
# les valeurs par défaut (5+10) provoquent des TimeoutError sous
# charge. 10+10 par worker × 4 workers = 80 connexions max,
# sous la limite PostgreSQL (100).
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=10,
    pool_timeout=60,
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()