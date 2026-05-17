-- Tracker App Schema

CREATE TYPE media_type AS ENUM (
    'MANGA', 'MANHWA', 'MANHUA', 'WEBTOON',
    'ANIME', 'MOVIE', 'SERIES', 'DORAMA'
);

CREATE TYPE tracking_status AS ENUM (
    'plan_to_watch', 'watching', 'completed', 'on_hold', 'dropped'
);

CREATE TYPE rating_label AS ENUM (
    'must', 'me_encanta', 'muy_bonita', 'bonita',
    'pasable', 'no_me_gusto', 'abandonado', 'sin_valorar'
);

CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    password_hash TEXT NOT NULL,
    avatar_url  TEXT,
    is_admin    BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE media (
    id              SERIAL PRIMARY KEY,
    type            media_type NOT NULL,
    title           TEXT NOT NULL,
    title_original  TEXT,
    year            INTEGER,
    genres          TEXT[],
    synopsis        TEXT,
    cover_url       TEXT,
    duration        TEXT,
    country         TEXT,
    network         TEXT,
    cast_text       TEXT,
    external_score  DECIMAL(4,2),
    tmdb_id         INTEGER,
    anilist_id      INTEGER,
    platform        TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_media_type ON media(type);
CREATE INDEX idx_media_title ON media USING gin(to_tsvector('spanish', title));

CREATE TABLE user_entries (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_id        INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    status          tracking_status NOT NULL DEFAULT 'plan_to_watch',
    progress        TEXT,
    score           DECIMAL(4,1),
    rating_label    rating_label DEFAULT 'sin_valorar',
    notes           TEXT,
    platform        TEXT,
    started_at      DATE,
    completed_at    DATE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, media_id)
);

CREATE INDEX idx_entries_user ON user_entries(user_id);
CREATE INDEX idx_entries_status ON user_entries(user_id, status);
CREATE INDEX idx_entries_type ON user_entries(user_id, media_id);

CREATE OR REPLACE FUNCTION fn_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_media_updated BEFORE UPDATE ON media
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at();
CREATE TRIGGER trg_entries_updated BEFORE UPDATE ON user_entries
    FOR EACH ROW EXECUTE FUNCTION fn_updated_at();

-- Views
CREATE VIEW v_user_catalog AS
SELECT
    ue.id AS entry_id,
    ue.user_id,
    u.username,
    m.id AS media_id,
    m.type,
    m.title,
    m.title_original,
    m.year,
    m.genres,
    m.cover_url,
    m.duration,
    m.country,
    m.network,
    m.external_score,
    m.platform AS media_platform,
    ue.status,
    ue.progress,
    ue.score,
    ue.rating_label,
    ue.notes,
    ue.platform AS watched_on,
    ue.started_at,
    ue.completed_at,
    ue.updated_at
FROM user_entries ue
JOIN users u ON u.id = ue.user_id
JOIN media m ON m.id = ue.media_id;
