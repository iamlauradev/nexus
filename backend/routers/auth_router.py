from fastapi import APIRouter, HTTPException, Depends, Header
from typing import Optional
from models import UserCreate, UserLogin, UserOut, Token
from auth import hash_password, verify_password, create_token, decode_token
from database import get_conn, fetchone

router = APIRouter(prefix="/auth", tags=["auth"])


def get_current_user(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "No autenticado")
    token = authorization.removeprefix("Bearer ").strip()
    payload = decode_token(token)
    if not payload:
        raise HTTPException(401, "Token inválido o expirado")
    user = fetchone("SELECT * FROM users WHERE id = %s", (int(payload["sub"]),))
    if not user:
        raise HTTPException(401, "Usuario no encontrado")
    return dict(user)


@router.post("/register", response_model=Token)
def register(data: UserCreate):
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
    token = create_token(user["id"], user["username"])
    return Token(access_token=token, user=UserOut(**user))


@router.post("/login", response_model=Token)
def login(data: UserLogin):
    user = fetchone("SELECT * FROM users WHERE username = %s", (data.username,))
    if not user or not verify_password(data.password, user["password_hash"]):
        raise HTTPException(401, "Credenciales incorrectas")
    user = dict(user)
    token = create_token(user["id"], user["username"])
    return Token(access_token=token, user=UserOut(**user))


@router.get("/me", response_model=UserOut)
def me(current_user: dict = Depends(get_current_user)):
    return UserOut(**current_user)
