"""Initial schema — reflects existing production state

Revision ID: 0001
Revises:
Create Date: 2025-01-01 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enums
    media_type = postgresql.ENUM(
        "MANGA", "MANHWA", "MANHUA", "WEBTOON", "ANIME", "MOVIE", "SERIES", "DORAMA",
        name="media_type", create_type=False,
    )
    tracking_status = postgresql.ENUM(
        "plan_to_watch", "watching", "completed", "on_hold", "dropped",
        name="tracking_status", create_type=False,
    )
    rating_label = postgresql.ENUM(
        "must", "me_encanta", "muy_bonita", "bonita", "pasable",
        "no_me_gusto", "abandonado", "sin_valorar",
        name="rating_label", create_type=False,
    )

    op.execute("CREATE TYPE IF NOT EXISTS media_type AS ENUM ('MANGA','MANHWA','MANHUA','WEBTOON','ANIME','MOVIE','SERIES','DORAMA')")
    op.execute("CREATE TYPE IF NOT EXISTS tracking_status AS ENUM ('plan_to_watch','watching','completed','on_hold','dropped')")
    op.execute("CREATE TYPE IF NOT EXISTS rating_label AS ENUM ('must','me_encanta','muy_bonita','bonita','pasable','no_me_gusto','abandonado','sin_valorar')")

    op.create_table(
        "users",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("username", sa.String(50), unique=True, nullable=False),
        sa.Column("display_name", sa.String(100)),
        sa.Column("password_hash", sa.Text, nullable=False),
        sa.Column("avatar_url", sa.Text),
        sa.Column("is_admin", sa.Boolean, server_default="false"),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        if_not_exists=True,
    )

    op.create_table(
        "media",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("type", sa.Enum(name="media_type"), nullable=False),
        sa.Column("title", sa.Text, nullable=False),
        sa.Column("title_original", sa.Text),
        sa.Column("year", sa.Integer),
        sa.Column("genres", postgresql.ARRAY(sa.Text)),
        sa.Column("synopsis", sa.Text),
        sa.Column("cover_url", sa.Text),
        sa.Column("duration", sa.Text),
        sa.Column("country", sa.Text),
        sa.Column("network", sa.Text),
        sa.Column("cast_text", sa.Text),
        sa.Column("external_score", sa.Numeric(4, 2)),
        sa.Column("tmdb_id", sa.Integer),
        sa.Column("anilist_id", sa.Integer),
        sa.Column("platform", sa.Text),
        sa.Column("emission_status", sa.Text),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        if_not_exists=True,
    )

    op.create_table(
        "user_entries",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("media_id", sa.Integer, sa.ForeignKey("media.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.Enum(name="tracking_status"), nullable=False, server_default="plan_to_watch"),
        sa.Column("progress", sa.Text),
        sa.Column("score", sa.Numeric(4, 1)),
        sa.Column("rating_label", sa.Enum(name="rating_label"), server_default="sin_valorar"),
        sa.Column("notes", sa.Text),
        sa.Column("platform", sa.Text),
        sa.Column("started_at", sa.Date),
        sa.Column("completed_at", sa.Date),
        sa.Column("ep_current", sa.Integer),
        sa.Column("ep_total", sa.Integer),
        sa.Column("rewatch_count", sa.Integer, server_default="0"),
        sa.Column("emission_day", sa.SmallInteger),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        sa.UniqueConstraint("user_id", "media_id"),
        if_not_exists=True,
    )

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("token", sa.Text, unique=True, nullable=False),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        if_not_exists=True,
    )

    op.create_table(
        "token_blacklist",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("token_sig", sa.Text, unique=True, nullable=False),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
        if_not_exists=True,
    )

    op.create_table(
        "entry_history",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("entry_id", sa.Integer, sa.ForeignKey("user_entries.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("field_name", sa.Text, nullable=False),
        sa.Column("old_value", sa.Text),
        sa.Column("new_value", sa.Text),
        sa.Column("changed_at", sa.TIMESTAMP(timezone=True), server_default=sa.text("NOW()")),
        if_not_exists=True,
    )

    op.create_table(
        "user_rating_configs",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("user_id", sa.Integer, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("key", sa.Text, nullable=False),
        sa.Column("label", sa.Text, nullable=False),
        sa.Column("color", sa.Text, server_default="'#475569'"),
        sa.Column("sort_order", sa.Integer, server_default="0"),
        sa.UniqueConstraint("user_id", "key"),
        if_not_exists=True,
    )


def downgrade() -> None:
    op.drop_table("user_rating_configs")
    op.drop_table("entry_history")
    op.drop_table("token_blacklist")
    op.drop_table("refresh_tokens")
    op.drop_table("user_entries")
    op.drop_table("media")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS rating_label")
    op.execute("DROP TYPE IF EXISTS tracking_status")
    op.execute("DROP TYPE IF EXISTS media_type")
