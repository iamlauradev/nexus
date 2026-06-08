import os
from pathlib import Path

def _load_env():
    env = Path(__file__).parent.parent / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip())

_load_env()

DB_HOST     = os.environ.get("DB_HOST", "localhost")
DB_PORT     = int(os.environ.get("DB_PORT", 5432))
DB_NAME     = os.environ.get("DB_NAME", "nexusdb")
DB_USER     = os.environ.get("DB_USER", "nexus")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

SECRET_KEY  = os.environ.get("SECRET_KEY", "")
TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", 15))

TMDB_API_KEY   = os.environ.get("TMDB_API_KEY", "")
ANILIST_URL    = os.environ.get("ANILIST_URL", "https://graphql.anilist.co")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

REDIS_HOST     = os.environ.get("REDIS_HOST", "nexus_redis")
REDIS_PORT     = int(os.environ.get("REDIS_PORT", 6379))
REDIS_DB       = int(os.environ.get("REDIS_DB", 0))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
_auth = f":{REDIS_PASSWORD}@" if REDIS_PASSWORD else ""
REDIS_URL      = f"redis://{_auth}{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"

# TTLs in seconds for external API response caching
CACHE_TTL_SEARCH  = int(os.environ.get("CACHE_TTL_SEARCH",  3600))   # 1 hour
CACHE_TTL_DETAILS = int(os.environ.get("CACHE_TTL_DETAILS", 86400))  # 24 hours
