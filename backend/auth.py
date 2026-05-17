import hashlib
import secrets
import base64
from datetime import datetime, timedelta, timezone
from typing import Optional
import json

from config import SECRET_KEY, TOKEN_EXPIRE_MINUTES


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
        "exp": int(expire.timestamp()),
    }
    data = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode()
    sig  = hashlib.sha256(f"{data}{SECRET_KEY}".encode()).hexdigest()
    return f"{data}.{sig}"


def decode_token(token: str) -> Optional[dict]:
    try:
        data, sig = token.rsplit(".", 1)
        expected = hashlib.sha256(f"{data}{SECRET_KEY}".encode()).hexdigest()
        if not secrets.compare_digest(sig, expected):
            return None
        payload = json.loads(base64.urlsafe_b64decode(data + "=="))
        if payload["exp"] < datetime.now(timezone.utc).timestamp():
            return None
        return payload
    except Exception:
        return None
