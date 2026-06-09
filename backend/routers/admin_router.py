import config
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from database import fetchone, fetchall, execute, get_conn
from routers.auth_router import get_current_user
from email_service import send_email
import secrets as _secrets
from datetime import datetime, timedelta, timezone

router = APIRouter(prefix="/admin", tags=["admin"])


def get_admin_user(current_user: dict = Depends(get_current_user)) -> dict:
    if not current_user.get("is_admin"):
        raise HTTPException(403, "Acceso restringido a administradores")
    return current_user


@router.get("/users")
def list_users(
    page: int = 1,
    limit: int = 20,
    _: dict = Depends(get_admin_user),
):
    offset = (page - 1) * limit
    rows = fetchall(
        """
        SELECT u.id, u.username, u.email, u.is_admin, u.is_active, u.created_at,
               COUNT(e.id) AS entry_count
        FROM users u
        LEFT JOIN user_entries e ON e.user_id = u.id
        GROUP BY u.id
        ORDER BY u.id
        LIMIT %s OFFSET %s
        """,
        (limit, offset),
    )
    total_row = fetchone("SELECT COUNT(*) AS total FROM users")
    return {
        "total": total_row["total"] if total_row else 0,
        "page": page,
        "limit": limit,
        "users": [dict(r) for r in rows],
    }


@router.get("/users/{user_id}")
def get_user(user_id: int, _: dict = Depends(get_admin_user)):
    row = fetchone(
        """
        SELECT u.id, u.username, u.email, u.is_admin, u.is_active, u.created_at,
               COUNT(e.id) AS entry_count
        FROM users u
        LEFT JOIN user_entries e ON e.user_id = u.id
        WHERE u.id = %s
        GROUP BY u.id
        """,
        (user_id,),
    )
    if not row:
        raise HTTPException(404, "Usuario no encontrado")
    return dict(row)


@router.post("/users/{user_id}/reset-password")
def admin_reset_password(user_id: int, _: dict = Depends(get_admin_user)):
    user = fetchone("SELECT id, email FROM users WHERE id = %s", (user_id,))
    if not user:
        raise HTTPException(404, "Usuario no encontrado")
    if not user["email"]:
        raise HTTPException(400, "El usuario no tiene email registrado")
    token = _secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
    execute(
        "INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
        (user_id, token, expires_at),
    )
    link = f"{config.FRONTEND_URL}/reset-password?token={token}"
    body = f"""
    <div style="font-family:sans-serif;max-width:480px;margin:auto">
      <h2 style="color:#7C6FEB">Nexus — Restablece tu contraseña</h2>
      <p>Un administrador ha solicitado el restablecimiento de tu contraseña.</p>
      <p><a href="{link}" style="color:#7C6FEB">{link}</a></p>
      <p style="color:#888;font-size:12px">Expira en 1 hora.</p>
    </div>
    """
    try:
        send_email(user["email"], "Nexus — Restablece tu contraseña", body)
    except Exception:
        pass
    return {"ok": True}


@router.patch("/users/{user_id}/suspend")
def toggle_suspend(user_id: int, _: dict = Depends(get_admin_user)):
    user = fetchone("SELECT id, is_active FROM users WHERE id = %s", (user_id,))
    if not user:
        raise HTTPException(404, "Usuario no encontrado")
    new_state = not user["is_active"]
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("UPDATE users SET is_active=%s WHERE id=%s RETURNING id, is_active", (new_state, user_id))
        row = dict(cur.fetchone())
    return row


@router.get("/stats")
def admin_stats(_: dict = Depends(get_admin_user)):
    total = fetchone("SELECT COUNT(*) AS c FROM users")["c"]
    active_7d = fetchone(
        "SELECT COUNT(DISTINCT user_id) AS c FROM user_entries WHERE updated_at > NOW() - INTERVAL '7 days'"
    )["c"]
    active_30d = fetchone(
        "SELECT COUNT(DISTINCT user_id) AS c FROM user_entries WHERE updated_at > NOW() - INTERVAL '30 days'"
    )["c"]
    entries_total = fetchone("SELECT COUNT(*) AS c FROM user_entries")["c"]
    return {
        "total_users": total,
        "active_7d": active_7d,
        "active_30d": active_30d,
        "entries_total": entries_total,
    }
