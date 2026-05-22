"""Add emission_status enum and column if missing

Revision ID: 0002
Revises: 0001
Create Date: 2025-01-02 00:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("""
        DO $$ BEGIN
            CREATE TYPE emission_status AS ENUM ('AIRING','FINISHED','UPCOMING','CANCELLED','HIATUS');
        EXCEPTION WHEN duplicate_object THEN NULL;
        END $$;
    """)
    op.execute("""
        ALTER TABLE media
            ADD COLUMN IF NOT EXISTS emission_status TEXT;
    """)


def downgrade() -> None:
    op.execute("ALTER TABLE media DROP COLUMN IF EXISTS emission_status")
