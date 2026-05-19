from fastapi import APIRouter, HTTPException, Depends, Header, Request
from typing import Optional
from pydantic import BaseModel
from models import UserCreate, UserLogin, UserOut, TokenPair
from auth import (
    hash_password, verify_password, create_token, decode_token,
    create_refresh_token, is_token_blacklisted,
)
from database import get_conn, fetchone, execute
from limiter import limiter

router = APIRouter(prefix="/auth", tags=["auth"])


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "No autenticado")
    token = authorization.removeprefix("Bearer ").strip()
    payload = decode_token(token)
    if not payload:
        raise HTTPException(401, "Token inválido o expirado")
    # Check blacklist using the token signature (the part after the last '.')
    _, sig = token.rsplit(".", 1)
    if is_token_blacklisted(sig):
        raise HTTPException(401, "Token revocado")
    user = fetchone("SELECT * FROM users WHERE id = %s", (int(payload["sub"]),))
    if not user:
        raise HTTPException(401, "Usuario no encontrado")
    return dict(user)


def _store_refresh_token(user_id: int, token_string: str, expires_at) -> None:
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
            (user_id, token_string, expires_at),
        )


@router.post("/register", response_model=TokenPair)
@limiter.limit("5/minute")
def register(request: Request, data: UserCreate):
    existing = fetchone("SELECT id FROM users WHERE username = %s", (data.username,))
    if existing:
        raise HTTPException(400, "Nombre de usuario ya en uso")
    pw_hash = hash_password(data.password)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (username, display_name, password_hash) VALUES (%s, %s, %s) RETURNING *",
            (data.username, data.display_name or data.username, pw_hash)
        )
        user = dict(cur.fetchone())
    access_token = create_token(user["id"], user["username"])
    refresh_token_str, refresh_expires = create_refresh_token(user["id"])
    _store_refresh_token(user["id"], refresh_token_str, refresh_expires)
    return TokenPair(
        access_token=access_token,
        refresh_token=refresh_token_str,
        user=UserOut(**user),
    )


@router.post("/login", response_model=TokenPair)
@limiter.limit("10/minute")
def login(request: Request, data: UserLogin):
    user = fetchone("SELECT * FROM users WHERE username = %s", (data.username,))
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(401, "Credenciales incorrectas")
    user = dict(user)
    access_token = create_token(user["id"], user["username"])
    refresh_token_str, refresh_expires = create_refresh_token(user["id"])
    _store_refresh_token(user["id"], refresh_token_str, refresh_expires)
    return TokenPair(
        access_token=access_token,
        refresh_token=refresh_token_str,
        user=UserOut(**user),
    )


@router.post("/refresh")
def refresh_token(body: RefreshRequest):
    row = fetchone(
        "SELECT * FROM refresh_tokens WHERE token = %s AND expires_at > NOW()",
        (body.refresh_token,),
    )
    if not row:
        raise HTTPException(401, "Refresh token inválido o expirado")
    row = dict(row)
    user = fetchone("SELECT * FROM users WHERE id = %s", (row["user_id"],))
    if not user:
        raise HTTPException(401, "Usuario no encontrado")
    user = dict(user)
    new_access_token = create_token(user["id"], user["username"])
    return {"access_token": new_access_token, "token_type": "bearer"}


@router.post("/logout")
def logout(body: LogoutRequest, authorization: Optional[str] = Header(None)):
    # Blacklist the access token if present
    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        payload = decode_token(token)
        if payload:
            _, sig = token.rsplit(".", 1)
            import datetime as _dt
            expires_at = _dt.datetime.fromtimestamp(payload["exp"], tz=_dt.timezone.utc)
            with get_conn() as conn:
                cur = conn.cursor()
                cur.execute(
                    """INSERT INTO token_blacklist (token_sig, expires_at)
                       VALUES (%s, %s) ON CONFLICT DO NOTHING""",
                    (sig, expires_at),
                )
    # Delete the refresh token from DB
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM refresh_tokens WHERE token = %s", (body.refresh_token,))
    return {"ok": True}


@router.get("/me", response_model=UserOut)
def me(current_user: dict = Depends(get_current_user)):
    return UserOut(**current_user)
