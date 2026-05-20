import re
from datetime import datetime, timezone
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


def _parse_duration_minutes(duration: str) -> float:
    """Parse duration strings like '23 min', '45 min', '1 hr 30 min', '120 min' into minutes."""
    if not duration:
        return 0.0
    duration = duration.strip()
    total = 0.0
    # Match hours
    hr_match = re.search(r"(\d+)\s*hr", duration, re.IGNORECASE)
    if hr_match:
        total += int(hr_match.group(1)) * 60
    # Match minutes
    min_match = re.search(r"(\d+)\s*min", duration, re.IGNORECASE)
    if min_match:
        total += int(min_match.group(1))
    # If no pattern matched but it's a plain number, treat as minutes
    if total == 0:
        plain = re.match(r"^\d+$", duration)
        if plain:
            total = float(duration)
    return total


@router.post("/", response_model=EntryOut)
def create_entry(data: EntryCreate, current_user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO user_entries
                (user_id, media_id, status, progress, score, rating_label, notes, platform,
                 started_at, completed_at, ep_current, ep_total, rewatch_count)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id, media_id) DO UPDATE SET
                status=EXCLUDED.status, progress=EXCLUDED.progress, score=EXCLUDED.score,
                rating_label=EXCLUDED.rating_label, notes=EXCLUDED.notes, platform=EXCLUDED.platform,
                started_at=EXCLUDED.started_at, completed_at=EXCLUDED.completed_at,
                ep_current=EXCLUDED.ep_current, ep_total=EXCLUDED.ep_total,
                rewatch_count=EXCLUDED.rewatch_count,
                updated_at=NOW()
            RETURNING *
        """, (
            current_user["id"], data.media_id, data.status, data.progress,
            data.score, data.rating_label, data.notes, data.platform,
            data.started_at, data.completed_at, data.ep_current, data.ep_total,
            data.rewatch_count or 0,
        ))
        row = dict(cur.fetchone())
    return _build_entry_out(row)


@router.get("/export")
def export_entries(current_user = Depends(get_current_user)):
    uid = current_user["id"]
    rows = fetchall(
        "SELECT * FROM user_entries WHERE user_id = %s ORDER BY updated_at DESC",
        (uid,),
    )
    entries_out = []
    for row in rows:
        row = dict(row)
        media = None
        if row.get("media_id"):
            m = fetchone("SELECT * FROM media WHERE id = %s", (row["media_id"],))
            if m:
                media = dict(m)
        entries_out.append({
            "media": media,
            "entry": {k: (v.isoformat() if hasattr(v, "isoformat") else v) for k, v in row.items()},
        })
    return {
        "version": "1.0",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "entries": entries_out,
    }


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

    # Top 10 genres
    top_genres_rows = fetchall("""
        SELECT unnest(m.genres) AS genre, COUNT(*) AS count
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE ue.user_id = %s AND m.genres IS NOT NULL
        GROUP BY genre
        ORDER BY count DESC
        LIMIT 10
    """, (uid,))
    top_genres = [{"genre": r["genre"], "count": r["count"]} for r in top_genres_rows]

    # Monthly added (last 12 months)
    monthly_rows = fetchall("""
        SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS month, COUNT(*) AS count
        FROM user_entries
        WHERE user_id = %s
          AND created_at >= NOW() - INTERVAL '12 months'
        GROUP BY month
        ORDER BY month ASC
    """, (uid,))
    monthly_added = [{"month": r["month"], "count": r["count"]} for r in monthly_rows]

    # Score distribution (scores 1-10)
    score_dist_rows = fetchall("""
        SELECT ROUND(score)::int AS score, COUNT(*) AS count
        FROM user_entries
        WHERE user_id = %s AND score IS NOT NULL AND score >= 1 AND score <= 10
        GROUP BY ROUND(score)::int
        ORDER BY score ASC
    """, (uid,))
    score_distribution = [{"score": r["score"], "count": r["count"]} for r in score_dist_rows]

    # Time spent: sum duration × episodes watched for all started entries
    watched_rows = fetchall("""
        SELECT m.type, m.duration, ue.ep_current, ue.status
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE ue.user_id = %s
          AND ue.status != 'plan_to_watch'
          AND m.duration IS NOT NULL
    """, (uid,))
    total_minutes = 0.0
    for r in watched_rows:
        dur = _parse_duration_minutes(r["duration"])
        if not dur:
            continue
        mtype = r["type"] or ""
        if mtype == "MOVIE":
            total_minutes += dur
        elif mtype in ("SERIES", "ANIME", "DORAMA"):
            ep = r["ep_current"] or (1 if r["status"] == "completed" else 0)
            total_minutes += dur * ep
        # manga/comics have no watch time
    time_spent_hours = round(total_minutes / 60.0, 2)
    time_spent_minutes = int(total_minutes)

    # Status breakdown per content type
    content_type_status_rows = fetchall("""
        SELECT m.type, ue.status, COUNT(*) AS count
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE ue.user_id = %s
        GROUP BY m.type, ue.status
    """, (uid,))
    content_type_stats: dict = {}
    for r in content_type_status_rows:
        t = r["type"]
        if t not in content_type_stats:
            content_type_stats[t] = {}
        content_type_stats[t][r["status"]] = r["count"]

    return {
        "total": total,
        "by_status": by_status,
        "by_type": by_type,
        "by_rating": by_rating,
        "completed": by_status.get("completed", 0),
        "watching": by_status.get("watching", 0),
        "plan": by_status.get("plan_to_watch", 0),
        "top_genres": top_genres,
        "monthly_added": monthly_added,
        "score_distribution": score_distribution,
        "time_spent_hours": time_spent_hours,
        "time_spent_minutes": time_spent_minutes,
        "content_type_stats": content_type_stats,
    }


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


@router.get("/check-updates")
def check_updates(current_user = Depends(get_current_user)):
    """Devuelve entradas AIRING donde el episodio total puede haber aumentado."""
    rows = fetchall("""
        SELECT ue.id, ue.ep_current, ue.ep_total, m.title, m.anilist_id, m.tmdb_id, m.type
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE ue.user_id = %s
          AND m.emission_status = 'AIRING'
          AND ue.status = 'watching'
    """, (current_user["id"],))
    return [dict(r) for r in rows]


@router.get("/{entry_id}", response_model=EntryOut)
def get_entry(entry_id: int, current_user = Depends(get_current_user)):
    row = fetchone("SELECT * FROM user_entries WHERE id=%s AND user_id=%s",
                   (entry_id, current_user["id"]))
    if not row:
        raise HTTPException(404, "Entrada no encontrada")
    return _build_entry_out(dict(row))


_HISTORY_FIELDS = (
    "status", "score", "rating_label", "progress",
    "ep_current", "ep_total", "started_at", "completed_at", "rewatch_count",
)


@router.put("/{entry_id}", response_model=EntryOut)
def update_entry(entry_id: int, data: EntryUpdate, current_user = Depends(get_current_user)):
    existing = fetchone("SELECT * FROM user_entries WHERE id=%s AND user_id=%s",
                        (entry_id, current_user["id"]))
    if not existing:
        raise HTTPException(404, "Entrada no encontrada")

    existing_dict = dict(existing)
    fields = data.model_dump(exclude_unset=True)
    if not fields:
        return _build_entry_out(existing_dict)

    set_clause = ", ".join(f"{k} = %s" for k in fields)
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            f"UPDATE user_entries SET {set_clause}, updated_at=NOW() WHERE id=%s AND user_id=%s RETURNING *",
            list(fields.values()) + [entry_id, current_user["id"]]
        )
        row = dict(cur.fetchone())

        # Record history for changed fields
        history_rows = []
        for field in _HISTORY_FIELDS:
            old_val = existing_dict.get(field)
            new_val = row.get(field)
            if str(old_val) != str(new_val):
                history_rows.append((entry_id, current_user["id"], field, str(old_val), str(new_val)))

        if history_rows:
            cur.executemany(
                """INSERT INTO entry_history (entry_id, user_id, field_name, old_value, new_value)
                   VALUES (%s, %s, %s, %s, %s)""",
                history_rows,
            )

    return _build_entry_out(row)


@router.get("/{entry_id}/history")
def get_entry_history(entry_id: int, current_user = Depends(get_current_user)):
    rows = fetchall("""
        SELECT * FROM entry_history
        WHERE entry_id=%s AND user_id=%s
        ORDER BY changed_at DESC LIMIT 50
    """, (entry_id, current_user["id"]))
    return [dict(r) for r in rows]


@router.delete("/{entry_id}")
def delete_entry(entry_id: int, current_user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("DELETE FROM user_entries WHERE id=%s AND user_id=%s", (entry_id, current_user["id"]))
        if cur.rowcount == 0:
            raise HTTPException(404, "Entrada no encontrada")
    return {"ok": True}
