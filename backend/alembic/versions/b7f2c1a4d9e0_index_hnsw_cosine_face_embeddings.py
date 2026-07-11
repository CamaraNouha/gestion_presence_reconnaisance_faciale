"""index hnsw cosine sur face_embeddings

Revision ID: b7f2c1a4d9e0
Revises: 23d8e10fb7c0
Create Date: 2026-07-11 00:00:00.000000

Ajoute un index HNSW (vector_cosine_ops) sur la colonne embedding
pour accélérer la recherche du plus proche voisin (opérateur <=>)
utilisée lors du pointage.
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = 'b7f2c1a4d9e0'
down_revision: Union[str, Sequence[str], None] = '23d8e10fb7c0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_face_embeddings_embedding_hnsw "
        "ON face_embeddings USING hnsw (embedding vector_cosine_ops)"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("DROP INDEX IF EXISTS ix_face_embeddings_embedding_hnsw")
