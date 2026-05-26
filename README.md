# Nexus

A self-hosted media tracker with an RPG-inspired dark UI. Track anime, manga, manhwa, manhua, webtoons, novels, movies, series, and doramas — all in one place.

The same Flutter codebase runs as a **web app** (served via Nginx) and an **Android APK**. The backend is a FastAPI + PostgreSQL + Redis stack designed for homelab Docker deployment.

## Features

- **9 media types** — Anime, Manga, Manhwa, Manhua, Webtoon, Novel, Movie, Series, Dorama
- **Tracking statuses** — Plan, Watching / Reading, Completed, On Hold, Dropped
- **Metadata search** — TMDB integration for movies/series/doramas; AniList for manga/anime (no key required)
- **Custom rating system** — configurable labels and colors per user (default: Must, Love It, Very Pretty, Pretty, Passable, Disliked, Abandoned)
- **Library check on search** — search results show whether a title is already in your library and its status
- **Statistics** — totals by type, status, rating, top genres, monthly additions, score distribution, time spent
- **Emission calendar** — home screen shows entries currently airing with their day of the week
- **Completed this month** view and a random-pick feature on the home screen
- **Quick actions** — increment progress or change status with one tap from the list
- **Import / Export** — JSON export and import of your full library
- **Excel import script** — one-time bulk import from a spreadsheet
- **Responsive layout** — bottom tab bar on mobile, collapsible sidebar on desktop/web
- **Dark / light theme** toggle
- **Multi-user** — each user has their own private library; admin flag for management
- **bcrypt password hashing** with legacy SHA-256 migration path
- **JWT auth** with refresh token support and rate limiting
- **Redis caching** for external API responses (1h for search, 24h for details)

## Tech stack

| Layer | Technology |
|---|---|
| Mobile / web frontend | Flutter 3 (Dart) |
| State management | Provider + Riverpod (migration in progress) |
| Routing | go_router |
| Backend API | Python 3.12, FastAPI |
| Database | PostgreSQL 16, Alembic migrations |
| Caching | Redis 7 |
| Containerisation | Docker + Docker Compose |
| Reverse proxy | Traefik (optional) |
| CI / Android build | GitHub Actions |

## Architecture

```
nexus/
├── backend/
│   ├── main.py               # FastAPI app, CORS, middleware
│   ├── models.py             # Pydantic schemas and enums
│   ├── database.py           # SQLAlchemy engine + session
│   ├── auth.py               # Password hashing, JWT creation/verification
│   ├── cache_service.py      # Redis client wrapper
│   ├── routers/
│   │   ├── auth_router.py    # Register, login, refresh, profile
│   │   ├── media_router.py   # Media CRUD + external search (TMDB, AniList)
│   │   ├── entries_router.py # User library entries + stats
│   │   ├── import_router.py  # JSON import
│   │   └── rating_config_router.py
│   └── alembic/              # DB migrations
├── frontend/
│   ├── lib/
│   │   ├── main.dart         # App entry, router, navigation shell
│   │   ├── screens/          # One file per screen
│   │   ├── providers/        # Riverpod state providers
│   │   ├── services/         # API client, auth provider
│   │   ├── theme/            # RPG theme (colors, typography)
│   │   └── widgets/          # Shared UI components
│   └── android/              # Android-specific config
├── sql/
│   └── 001_schema.sql        # Initial schema (used by Alembic)
├── import/
│   └── excel_import.py       # One-time bulk import from spreadsheet
├── build_apk.sh              # Build APK locally via Docker
└── docker-compose.yml
```

## Self-hosting

### Requirements

- Docker and Docker Compose
- A PostgreSQL instance (included in the compose file for standalone setups, or point to an external one)
- The following environment variables set in a `.env` file

### Environment variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `DB_HOST` | No | `localhost` | PostgreSQL host |
| `DB_PORT` | No | `5432` | PostgreSQL port |
| `DB_NAME` | No | `nexusdb` | Database name |
| `DB_USER` | No | `nexus` | Database user |
| `DB_PASSWORD` | Yes | — | Database password |
| `SECRET_KEY` | Yes | — | Secret for JWT signing — use a long random string |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | No | `10080` (7 days) | JWT expiry |
| `TMDB_API_KEY` | No | — | TMDB API v4 Bearer token — enables movie/series/dorama search |
| `REDIS_HOST` | No | `nexus_redis` | Redis host |
| `REDIS_PORT` | No | `6379` | Redis port |
| `REDIS_PASSWORD` | No | — | Redis password |
| `BACKEND_PORT` | No | `8500` | Host port for the API |
| `FRONTEND_PORT` | No | `3500` | Host port for the web app |
| `API_EXTERNAL_URL` | No | — | Public URL of the backend, used by the Flutter build |

### Quick start

```bash
# 1. Create .env (minimum required)
cat > .env << 'EOF'
DB_PASSWORD=your_secure_db_password
SECRET_KEY=$(openssl rand -hex 32)
EOF

# 2. Start everything
docker compose up -d
```

The web app is available at `http://localhost:3500` and the API docs at `http://localhost:8500/docs`.

### First user

Register via the app's login screen → "Sign up". Admin access is granted manually at the database level (`UPDATE users SET is_admin = true WHERE username = 'your_username'`).

### Importing an existing spreadsheet

If you have a legacy Excel/spreadsheet collection, use the one-time import script:

```bash
pip install openpyxl psycopg2-binary
python3 import/excel_import.py --excel "my_collection.xlsx" --user your_username
```

## Android APK

### Option A — GitHub Actions (recommended)

Trigger the **Build APK** workflow from the Actions tab. You can optionally provide:
- A custom API URL pointing to your backend
- A version name
- An optional signing keystore (set `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` as repo secrets for a signed build)

### Option B — Local build via Docker

```bash
API_URL=http://your-server:8500 ./build_apk.sh
# APK: frontend/build/app/outputs/flutter-apk/app-release.apk
```

Requires Docker. Uses the official `cirruslabs/flutter:stable` image — no local Flutter installation needed.

## API

Interactive docs are available at `/docs` (Swagger UI) and `/redoc` when the backend is running.

Main endpoints:

| Method | Path | Description |
|---|---|---|
| `POST` | `/auth/register` | Create account |
| `POST` | `/auth/login` | Get token pair |
| `POST` | `/auth/refresh` | Refresh access token |
| `GET` | `/media/search` | Search TMDB / AniList / local DB |
| `GET` | `/entries/` | Get all user library entries |
| `POST` | `/entries/` | Add entry to library |
| `PUT` | `/entries/{entry_id}` | Update entry |
| `GET` | `/entries/stats` | Library statistics |
| `GET` | `/media/` | Browse all media in DB |

## License

MIT — see [LICENSE](LICENSE).
