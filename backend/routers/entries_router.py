from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from models import EntryCreate, EntryUpdate, EntryOut, MediaOut, TrackingStatus, MediaType
from database import get_conn, fetchone, fetchall
from routers.auth_router import get_current_user

router = APIRouter(prefix="/entries", tags=["entries"])


def _build_entry_out(row: dict) -> EntryOut:
    media = None
    if row.get("media_id"):
        m = fetchone("SELECT * FROM media WHERE id = %s", (row["media_id"],))
        if m:
            media = MediaOut(**dict(m))
    return EntryOut(**{k: v for k, v in row.items() if k in EntryOut.model_fields}, media=media)


@router.post("/", response_model=EntryOut)
def create_entry(data: EntryCreate, current_user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO user_entries
                (user_id, media_id, status, progress, score, rating_label, notes, platform, started_at, completed_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id, media_id) DO UPDATE SET
                status=EXCLUDED.status, progress=EXCLUDED.progress, score=EXCLUDED.score,
                rating_label=EXCLUDED.rating_label, notes=EXCLUDED.notes, platform=EXCLUDED.platform,
                started_at=EXCLUDED.started_at, completed_at=EXCLUDED.completed_at,
                updated_at=NOW()
            RETURNING *
        """, (
            current_user["id"], data.media_id, data.status, data.progress,
            data.score, data.rating_label, data.notes, data.platform,
            data.started_at, data.completed_at,
        ))
        row = dict(cur.fetchone())
    return _build_entry_out(row)


@router.get("/", response_model=List[EntryOut])
def list_entries(
    status: Optional[TrackingStatus] = None,
    media_type: Optional[MediaType] = None,
    rating: Optional[str] = None,
    q: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    current_user = Depends(get_current_user),
):
    conditions = ["ue.user_id = %s"]
    params = [current_user["id"]]

    if status:
        conditions.append("ue.status = %s")
        params.append(status)
    if rating:
        conditions.append("ue.rating_label = %s")
        params.append(rating)
    if media_type:
        conditions.append("m.type = %s")
        params.append(media_type)
    if q:
        conditions.append("m.title ILIKE %s")
        params.append(f"%{q}%")

    where = " AND ".join(conditions)
    sql = f"""
        SELECT ue.*, m.type AS media_type, m.title AS media_title, m.cover_url AS media_cover
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE {where}
        ORDER BY ue.updated_at DESC
        LIMIT %s OFFSET %s
    """
    rows = fetchall(sql, params + [limit, offset])
    return [_build_entry_out(dict(r)) for r in rows]


@router.get("/stats")
def get_stats(current_user = Depends(get_current_user)):
    uid = current_user["id"]
    total = fetchone("SELECT COUNT(*) AS n FROM user_entries WHERE user_id=%s", (uid,))["n"]

    by_status = {r["status"]: r["n"] for r in fetchall(
        "SELECT status, COUNT(*) AS n FROM user_entries WHERE user_id=%s GROUP BY status", (uid,))}

    by_type = {r["type"]: r["n"] for r in fetchall(
        "SELECT m.type, COUNT(*) AS n FROM user_entries ue JOIN media m ON m.id=ue.media_id WHERE ue.user_id=%s GROUP BY m.type",
        (uid,))}

    by_rating = {r["rating_label"]: r["n"] for r in fetchall(
        "SELECT rating_label, COUNT(*) AS n FROM user_entries WHERE user_id=%s AND rating_label IS NOT NULL GROUP BY rating_label",
        (uid,))}

    return {
        "total": total,
        "by_status": by_status,
        "by_type": by_type,
        "by_rating": by_rating,
        "completed": by_status.get("completed", 0),
        "watching": by_status.get("watching", 0),
        "plan": by_status.get("plan_to_watch", 0),
    }


@router.get("/{entry_id}", response_model=EntryOut)
def get_entry(entry_id: int, current_user = Depends(get_current_user)):
    row = fetchone("SELECT * FROM user_entries WHERE id=%s AND user_id=%s",
                   (entry_id, current_user["id"]))
    if not row:
        raise HTTPException(404, "Entrada no encontrada")
    return _build_entry_out(dict(row))


@router.put("/{entry_id}", response_model=EntryOut)
def update_entry(entry_id: int, data: EntryUpdate, current_user = Depends(get_current_user)):
    existing = fetchone("SELECT * FROM user_entries WHERE id=%s AND user_id=%s",
                        (entry_id, current_user["id"]))
    if not existing:
        raise HTTPException(404, "Entrada no encontrada")

    fields = {k: v for k, v in data.model_dump().items() if v is not None}
    if not fields:
        return _build_entry_out(dict(existing))

    set_clause = ", ".join(f"{k} = %s" for k in fields)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"UPDATE user_entries SET {set_clause}, updated_at=NOW() WHERE id=%s AND user_id=%s RETURNING *",
            list(fields.values()) + [entry_id, current_user["id"]]
        )
        row = dict(cur.fetchone())
    return _build_entry_out(row)


@router.delete("/{entry_id}")
def delete_entry(entry_id: int, current_user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM user_entries WHERE id=%s AND user_id=%s", (entry_id, current_user["id"]))
        if cur.rowcount == 0:
            raise HTTPException(404, "Entrada no encontrada")
    return {"ok": True}
