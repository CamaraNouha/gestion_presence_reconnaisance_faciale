from logging.config import fileConfig
from sqlalchemy import create_engine, pool
from alembic import context
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import Base
from app.models import *

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# ── Lit l'URL depuis les variables d'environnement ───────────
# Dans Docker    : DATABASE_URL=postgresql+psycopg2://...@db:5432/...
# En local       : DATABASE_URL=postgresql+psycopg2://...@127.0.0.1:5433/...
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://eniad_user:eniad_pass@127.0.0.1:5433/eniad_db"
)

def run_migrations_offline() -> None:
    context.configure(
        url=DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    connectable = create_engine(
        DATABASE_URL,
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata
        )
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()