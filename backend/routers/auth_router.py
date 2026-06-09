import config
from fastapi import APIRouter, HTTPException, Depends, Header, Request
from typing import Optional
from pydantic import BaseModel
from models import (
    UserCreate, UserLogin, UserOut, TokenPair, ProfileUpdate, PasswordChange,
    EmailUpdate, ForgotPasswordRequest, ResetPasswordRequest,
)
from auth import (
    hash_password, verify_password, create_token, decode_token,
    create_refresh_token, is_token_blacklisted, get_token_sig,
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
    if is_token_blacklisted(get_token_sig(token)):
        raise HTTPException(401, "Token revocado")
    user = fetchone("SELECT * FROM users WHERE id = %s", (int(payload["sub"]),))
    if not user:
        raise HTTPException(401, "Usuario no encontrado")
    user = dict(user)
    if not user.get("is_active", True):
        raise HTTPException(401, "Cuenta suspendida")
    return user


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
    if data.email:
        email_taken = fetchone("SELECT id FROM users WHERE email = %s", (data.email,))
        if email_taken:
            raise HTTPException(400, "Email ya en uso")
    pw_hash = hash_password(data.password)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (username, display_name, password_hash, email) VALUES (%s, %s, %s, %s) RETURNING *",
            (data.username, data.display_name or data.username, pw_hash, data.email)
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
    stored = user["password_hash"]
    if not (stored.startswith("$2b$") or stored.startswith("$2a$")):
        execute("UPDATE users SET password_hash = %s WHERE id = %s",
                (hash_password(data.password), user["id"]))
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
    new_refresh_str, new_refresh_expires = create_refresh_token(user["id"])
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM refresh_tokens WHERE token = %s", (body.refresh_token,))
        cur.execute(
            "INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
            (user["id"], new_refresh_str, new_refresh_expires),
        )
    return {"access_token": new_access_token, "refresh_token": new_refresh_str, "token_type": "bearer"}


@router.post("/logout")
def logout(body: LogoutRequest, authorization: Optional[str] = Header(None)):
    # Blacklist the access token if present
    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        payload = decode_token(token)
        if payload:
            import datetime as _dt
            sig = get_token_sig(token)
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


@router.put("/profile", response_model=UserOut)
def update_profile(data: ProfileUpdate, current_user: dict = Depends(get_current_user)):
    fields = {}
    if 'display_name' in data.model_fields_set:
        fields['display_name'] = data.display_name
    if 'avatar_url' in data.model_fields_set:
        if data.avatar_url is not None:
            # Validar que la URL sea externa (anti-SSRF básico)
            from urllib.parse import urlparse
            parsed = urlparse(data.avatar_url)
            if parsed.scheme not in ('http', 'https'):
                raise HTTPException(400, "URL de avatar no válida")
        fields['avatar_url'] = data.avatar_url
    if not fields:
        raise HTTPException(400, "Nada que actualizar")
    sets = ', '.join(f"{k}=%s" for k in fields)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"UPDATE users SET {sets} WHERE id=%s RETURNING *",
            list(fields.values()) + [current_user['id']]
        )
        user = dict(cur.fetchone())
    return UserOut(**user)


@router.post("/change-password")
def change_password(data: PasswordChange, current_user: dict = Depends(get_current_user)):
    if not verify_password(data.current_password, current_user['password_hash']):
        raise HTTPException(400, "Contraseña actual incorrecta")
    new_hash = hash_password(data.new_password)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE users SET password_hash=%s WHERE id=%s", (new_hash, current_user['id']))
    return {"ok": True}


@router.patch("/me/email", response_model=UserOut)
def update_email(data: EmailUpdate, current_user: dict = Depends(get_current_user)):
    existing = fetchone("SELECT id FROM users WHERE email = %s AND id != %s", (data.email, current_user['id']))
    if existing:
        raise HTTPException(400, "Email ya en uso")
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE users SET email=%s WHERE id=%s RETURNING *", (data.email, current_user['id']))
        user = dict(cur.fetchone())
    return UserOut(**user)


@router.post("/forgot-password")
@limiter.limit("5/minute")
def forgot_password(request: Request, data: ForgotPasswordRequest):
    import secrets as _secrets
    from datetime import datetime, timedelta, timezone
    from email_service import send_email
    user = fetchone("SELECT id, email FROM users WHERE email = %s", (data.email,))
    if user:
        token = _secrets.token_urlsafe(32)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        execute(
            "INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
            (user['id'], token, expires_at),
        )
        link = f"{config.FRONTEND_URL}/reset-password?token={token}"
        body = f"""
        <div style="font-family:sans-serif;max-width:480px;margin:auto">
          <h2 style="color:#7C6FEB">Nexus — Recuperación de contraseña</h2>
          <p>Has solicitado restablecer tu contraseña. Haz clic en el enlace de abajo:</p>
          <p><a href="{link}" style="color:#7C6FEB">{link}</a></p>
          <p style="color:#888;font-size:12px">Este enlace expira en 1 hora. Si no solicitaste esto, ignora este correo.</p>
        </div>
        """
        try:
            send_email(data.email, "Nexus — Restablece tu contraseña", body)
        except Exception:
            pass
    return {"ok": True}


@router.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    from datetime import datetime, timezone
    row = fetchone(
        "SELECT * FROM password_reset_tokens WHERE token = %s AND used = FALSE AND expires_at > NOW()",
        (data.token,),
    )
    if not row:
        raise HTTPException(400, "Token inválido o expirado")
    new_hash = hash_password(data.new_password)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE users SET password_hash=%s WHERE id=%s", (new_hash, row['user_id']))
        cur.execute("UPDATE password_reset_tokens SET used=TRUE WHERE id=%s", (row['id'],))
    return {"ok": True}
