from fastapi import APIRouter, HTTPException, Depends
from typing import List
from models import RatingConfigCreate, RatingConfigOut
from database import get_conn, fetchall, fetchone
from routers.auth_router import get_current_user

router = APIRouter(prefix="/rating-configs", tags=["rating-configs"])

_DEFAULTS = [
    ("must",        "★ Must",          "#F0C040", 0),
    ("me_encanta",  "♥ Me encanta",    "#58A6FF", 1),
    ("muy_bonita",  "✦ Muy bonita",    "#3FB950", 2),
    ("bonita",      "◆ Bonita",        "#56CC9D", 3),
    ("pasable",     "◇ Pasable",       "#D29922", 4),
    ("no_me_gusto", "✕ No me gustó",   "#F85149", 5),
    ("sin_valorar", "· Sin valorar",   "#484F58", 6),
]


def _ensure_defaults(user_id: int):
    existing = fetchall("SELECT key FROM user_rating_configs WHERE user_id=%s", (user_id,))
    existing_keys = {r["key"] for r in existing}
    with get_conn() as conn:
        cur = conn.cursor()
        for key, label, color, order in _DEFAULTS:
            if key not in existing_keys:
                cur.execute(
                    "INSERT INTO user_rating_configs (user_id,key,label,color,sort_order) VALUES (%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING",
                    (user_id, key, label, color, order),
                )


@router.get("/", response_model=List[RatingConfigOut])
def list_configs(current_user=Depends(get_current_user)):
    uid = current_user["id"]
    rows = fetchall(
        "SELECT * FROM user_rating_configs WHERE user_id=%s ORDER BY sort_order ASC, id ASC",
        (uid,),
    )
    if not rows:
        _ensure_defaults(uid)
        rows = fetchall(
            "SELECT * FROM user_rating_configs WHERE user_id=%s ORDER BY sort_order ASC, id ASC",
            (uid,),
        )
    return [RatingConfigOut(**dict(r)) for r in rows]


@router.post("/", response_model=RatingConfigOut)
def create_config(data: RatingConfigCreate, current_user=Depends(get_current_user)):
    uid = current_user["id"]
    existing = fetchone("SELECT id FROM user_rating_configs WHERE user_id=%s AND key=%s", (uid, data.key))
    if existing:
        raise HTTPException(400, f"Ya existe una valoración con clave '{data.key}'")
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO user_rating_configs (user_id,key,label,color,sort_order) VALUES (%s,%s,%s,%s,%s) RETURNING *",
            (uid, data.key, data.label, data.color, data.sort_order),
        )
        row = cur.fetchone()
    return RatingConfigOut(**dict(row))


@router.put("/{config_id}", response_model=RatingConfigOut)
def update_config(config_id: int, data: RatingConfigCreate, current_user=Depends(get_current_user)):
    uid = current_user["id"]
    row = fetchone("SELECT * FROM user_rating_configs WHERE id=%s AND user_id=%s", (config_id, uid))
    if not row:
        raise HTTPException(404, "Valoración no encontrada")
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "UPDATE user_rating_configs SET label=%s, color=%s, sort_order=%s WHERE id=%s AND user_id=%s RETURNING *",
            (data.label, data.color, data.sort_order, config_id, uid),
        )
        row = cur.fetchone()
    return RatingConfigOut(**dict(row))


@router.delete("/{config_id}")
def delete_config(config_id: int, current_user=Depends(get_current_user)):
    uid = current_user["id"]
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM user_rating_configs WHERE id=%s AND user_id=%s", (config_id, uid))
        if cur.rowcount == 0:
            raise HTTPException(404, "Valoración no encontrada")
    return {"ok": True}
