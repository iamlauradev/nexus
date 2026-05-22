"""
Thin Redis wrapper for caching external API responses.
Falls back gracefully if Redis is unavailable.
"""
import json
import hashlib
import logging
from typing import Any, Optional

import redis as redis_lib

from config import REDIS_HOST, REDIS_PORT, REDIS_DB

logger = logging.getLogger(__name__)

_client: Optional[redis_lib.Redis] = None


def _get_client() -> Optional[redis_lib.Redis]:
    global _client
    if _client is not None:
        return _client
    try:
        _client = redis_lib.Redis(
            host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB,
            decode_responses=True, socket_connect_timeout=2,
        )
        _client.ping()
        return _client
    except Exception as e:
        logger.warning("Redis no disponible, caché desactivado: %s", e)
        _client = None
        return None


def cache_key(namespace: str, *parts: str) -> str:
    raw = ":".join([namespace] + list(parts))
    return hashlib.md5(raw.encode()).hexdigest()


def get(key: str) -> Optional[Any]:
    client = _get_client()
    if client is None:
        return None
    try:
        raw = client.get(key)
        return json.loads(raw) if raw else None
    except Exception:
        return None


def set(key: str, value: Any, ttl: int = 3600) -> None:
    client = _get_client()
    if client is None:
        return
    try:
        client.setex(key, ttl, json.dumps(value, default=str))
    except Exception:
        pass


def get_or_fetch(key: str, fetch_fn, ttl: int = 3600) -> Any:
    """Return cached value or call fetch_fn(), cache the result, and return it."""
    cached = get(key)
    if cached is not None:
        return cached
    result = fetch_fn()
    if result:
        set(key, result, ttl)
    return result
