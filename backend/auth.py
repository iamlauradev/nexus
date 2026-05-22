import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

import jwt as pyjwt

from config import SECRET_KEY, TOKEN_EXPIRE_MINUTES

_ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    h = hashlib.sha256(f"{salt}{password}{SECRET_KEY}".encode()).hexdigest()
    return f"{salt}:{h}"


def verify_password(password: str, stored: str) -> bool:
    try:
        salt, h = stored.split(":", 1)
        expected = hashlib.sha256(f"{salt}{password}{SECRET_KEY}".encode()).hexdigest()
        return secrets.compare_digest(h, expected)
    except Exception:
        return False


def create_token(user_id: int, username: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "usr": username,
        "exp": expire,
    }
    return pyjwt.encode(payload, SECRET_KEY, algorithm=_ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return pyjwt.decode(token, SECRET_KEY, algorithms=[_ALGORITHM])
    except pyjwt.ExpiredSignatureError:
        return None
    except pyjwt.InvalidTokenError:
        return None


def get_token_sig(token: str) -> str:
    """Returns the signature segment of a JWT (last dot-separated component)."""
    return token.rsplit(".", 1)[-1]


def create_refresh_token(user_id: int) -> Tuple[str, datetime]:
    """Generates an opaque refresh token (64 bytes) with 7-day expiry."""
    token_string = secrets.token_urlsafe(64)
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    return token_string, expires_at


def is_token_blacklisted(token_sig: str) -> bool:
    """Returns True if the given token signature is in the blacklist."""
    from database import fetchone
    row = fetchone(
        "SELECT 1 FROM token_blacklist WHERE token_sig = %s AND expires_at > NOW()",
        (token_sig,),
    )
    return row is not None
