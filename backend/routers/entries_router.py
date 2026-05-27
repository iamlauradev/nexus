import re
from collections import defaultdict
from datetime import datetime, timezone, date as dt_date
from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from models import EntryCreate, EntryUpdate, EntryOut, MediaOut, TrackingStatus, MediaType
from database import get_conn, fetchone, fetchall
from routers.auth_router import get_current_user

router = APIRouter(prefix="/entries", tags=["entries"])

_GENRE_ES: dict = {
    "action": "Acción", "adventure": "Aventura", "animation": "Animación",
    "comedy": "Comedia", "crime": "Crimen", "documentary": "Documental",
    "drama": "Drama", "family": "Familia", "fantasy": "Fantasía",
    "history": "Historia", "horror": "Terror", "music": "Música",
    "mystery": "Misterio", "romance": "Romance", "science fiction": "Ciencia ficción",
    "sci-fi": "Ciencia ficción", "thriller": "Suspense", "war": "Guerra",
    "western": "Western", "supernatural": "Sobrenatural", "sports": "Deportes",
    "psychological": "Psicológico",
}

def _normalize_genre(g: str) -> str:
    return _GENRE_ES.get(g.strip().lower(), g.strip())


def _build_entry_out(row: dict) -> EntryOut:
    media = None
    if row.get("media_id"):
        m = fetchone("SELECT * FROM media WHERE id = %s", (row["media_id"],))
        if m:
            media = MediaOut(**dict(m))
    return EntryOut(**{k: v for k, v in row.items() if k in EntryOut.model_fields}, media=media)


def _build_entries_out(rows) -> list:
    """Batch version: one media query for all entries instead of N+1."""
    rows = [dict(r) for r in rows]
    media_ids = list({r["media_id"] for r in rows if r.get("media_id")})
    media_map = {}
    if media_ids:
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute("SELECT * FROM media WHERE id = ANY(%s)", (media_ids,))
            media_map = {m["id"]: MediaOut(**dict(m)) for m in cur.fetchall()}
    return [
        EntryOut(
            **{k: v for k, v in row.items() if k in EntryOut.model_fields},
            media=media_map.get(row.get("media_id")),
        )
        for row in rows
    ]


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
    # Auto-fill dates based on status
    started_at = data.started_at
    completed_at = data.completed_at
    today = dt_date.today()
    if data.status == "watching" and started_at is None:
        started_at = today
    elif data.status == "completed":
        if started_at is None:
            started_at = today
        if completed_at is None:
            completed_at = today

    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO user_entries
                (user_id, media_id, status, progress, score, rating_label, notes, platform,
                 started_at, completed_at, ep_current, ep_total, rewatch_count, emission_day)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id, media_id) DO UPDATE SET
                status=EXCLUDED.status, progress=EXCLUDED.progress, score=EXCLUDED.score,
                rating_label=EXCLUDED.rating_label, notes=EXCLUDED.notes, platform=EXCLUDED.platform,
                started_at=EXCLUDED.started_at, completed_at=EXCLUDED.completed_at,
                ep_current=EXCLUDED.ep_current, ep_total=EXCLUDED.ep_total,
                rewatch_count=EXCLUDED.rewatch_count, emission_day=EXCLUDED.emission_day,
                updated_at=NOW()
            RETURNING *
        """, (
            current_user["id"], data.media_id, data.status, data.progress,
            data.score, data.rating_label, data.notes, data.platform,
            started_at, completed_at, data.ep_current, data.ep_total,
            data.rewatch_count or 0, data.emission_day,
        ))
        row = dict(cur.fetchone())
    return _build_entry_out(row)


@router.get("/export")
def export_entries(current_user = Depends(get_current_user)):
    uid = current_user["id"]
    rows = [dict(r) for r in fetchall(
        "SELECT * FROM user_entries WHERE user_id = %s ORDER BY updated_at DESC",
        (uid,),
    )]

    # Batch-fetch all media in one query instead of N individual queries
    media_ids = list({r["media_id"] for r in rows if r.get("media_id")})
    media_map: dict = {}
    if media_ids:
        media_rows = fetchall("SELECT * FROM media WHERE id = ANY(%s)", (media_ids,))
        media_map = {r["id"]: dict(r) for r in media_rows}

    entries_out = []
    for row in rows:
        entries_out.append({
            "media": media_map.get(row.get("media_id")),
            "entry": {k: (v.isoformat() if hasattr(v, "isoformat") else v) for k, v in row.items()},
        })
    return {
        "version": "1.0",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "entries": entries_out,
    }


@router.get("/platforms")
def get_platforms(current_user = Depends(get_current_user)):
    uid = current_user["id"]
    rows = fetchall(
        "SELECT DISTINCT platform FROM user_entries WHERE user_id = %s AND platform IS NOT NULL AND platform != '' ORDER BY platform",
        (uid,),
    )
    return [r["platform"] for r in rows]


@router.get("/stats")
def get_stats(year: Optional[int] = Query(None), current_user = Depends(get_current_user)):
    uid = current_user["id"]
    yf     = " AND EXTRACT(year FROM created_at) = %s" if year else ""
    yf_ue  = " AND EXTRACT(year FROM ue.created_at) = %s" if year else ""
    yp     = (year,) if year else ()

    with get_conn() as conn:
        cur = conn.cursor()

        cur.execute(f"SELECT COUNT(*) AS n FROM user_entries WHERE user_id=%s{yf}", (uid,) + yp)
        total = cur.fetchone()["n"]

        cur.execute(f"SELECT status, COUNT(*) AS n FROM user_entries WHERE user_id=%s{yf} GROUP BY status", (uid,) + yp)
        by_status = {r["status"]: r["n"] for r in cur.fetchall()}

        cur.execute(f"""SELECT m.type, COUNT(*) AS n FROM user_entries ue
            JOIN media m ON m.id=ue.media_id WHERE ue.user_id=%s{yf_ue} GROUP BY m.type""", (uid,) + yp)
        by_type = {r["type"]: r["n"] for r in cur.fetchall()}

        cur.execute(f"""SELECT rating_label, COUNT(*) AS n FROM user_entries
            WHERE user_id=%s AND rating_label IS NOT NULL{yf} GROUP BY rating_label""", (uid,) + yp)
        by_rating = {r["rating_label"]: r["n"] for r in cur.fetchall()}

        cur.execute(f"""
            SELECT m.type, unnest(m.genres) AS genre, COUNT(*) AS count
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND m.genres IS NOT NULL AND array_length(m.genres, 1) > 0{yf_ue}
            GROUP BY m.type, genre ORDER BY count DESC
        """, (uid,) + yp)
        raw_genres: dict = defaultdict(int)
        _COMICS = {"MANGA", "MANHWA", "MANHUA", "WEBTOON"}
        _CAT_LABEL = {"MOVIE": "Películas", "SERIES": "Series", "DORAMA": "Doramas", "ANIME": "Anime"}
        cats_raw: dict = defaultdict(lambda: defaultdict(int))
        for r in cur.fetchall():
            norm = _normalize_genre(r["genre"])
            raw_genres[norm] += r["count"]
            cat = "Cómics" if r["type"] in _COMICS else _CAT_LABEL.get(r["type"], r["type"])
            cats_raw[cat][norm] += r["count"]
        top_genres = sorted(
            [{"genre": k, "count": v} for k, v in raw_genres.items()],
            key=lambda x: -x["count"]
        )[:15]
        top_genres_by_category = {
            cat: sorted([{"genre": g, "count": c} for g, c in genres.items()], key=lambda x: -x["count"])[:5]
            for cat, genres in cats_raw.items()
        }

        cur.execute("""
            SELECT eh.changed_at, eh.old_value, eh.new_value, m.title, m.type, m.cover_url
            FROM entry_history eh
            JOIN user_entries ue ON ue.id = eh.entry_id
            JOIN media m ON m.id = ue.media_id
            WHERE eh.user_id = %s AND eh.field_name = 'status'
            ORDER BY eh.changed_at DESC LIMIT 15
        """, (uid,))
        recent_activity = [
            {
                "title": r["title"], "type": r["type"], "cover_url": r["cover_url"],
                "from": r["old_value"], "to": r["new_value"],
                "when": r["changed_at"].isoformat(),
            }
            for r in cur.fetchall()
        ]

        cur.execute(f"""
            SELECT COUNT(*) AS n FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND (m.genres IS NULL OR m.genres = '{{}}'){yf_ue}
        """, (uid,) + yp)
        no_genre_count = cur.fetchone()["n"]

        cur.execute("""
            SELECT COUNT(*) AS n FROM user_entries ue
            WHERE ue.user_id = %s AND ue.status = 'completed'
              AND date_part('year', ue.completed_at) = date_part('year', CURRENT_DATE)
        """, (uid,))
        completed_this_year = cur.fetchone()["n"]

        if year:
            cur.execute("""
                SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS month, COUNT(*) AS count
                FROM user_entries WHERE user_id = %s AND EXTRACT(year FROM created_at) = %s
                GROUP BY month ORDER BY month ASC
            """, (uid, year))
        else:
            cur.execute("""
                SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS month, COUNT(*) AS count
                FROM user_entries WHERE user_id = %s AND created_at >= NOW() - INTERVAL '12 months'
                GROUP BY month ORDER BY month ASC
            """, (uid,))
        monthly_added = [{"month": r["month"], "count": r["count"]} for r in cur.fetchall()]

        cur.execute(f"""
            SELECT ROUND(score)::int AS score, COUNT(*) AS count
            FROM user_entries
            WHERE user_id = %s AND score IS NOT NULL AND score >= 1 AND score <= 10{yf}
            GROUP BY ROUND(score)::int ORDER BY score ASC
        """, (uid,) + yp)
        score_distribution = [{"score": r["score"], "count": r["count"]} for r in cur.fetchall()]

        cur.execute(f"""
            SELECT m.type, m.duration, ue.ep_current, ue.status
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND ue.status != 'plan_to_watch'{yf_ue}
        """, (uid,) + yp)
        watched_rows = cur.fetchall()

        cur.execute(f"""
            SELECT m.type, ue.status, COUNT(*) AS count
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s{yf_ue} GROUP BY m.type, ue.status
        """, (uid,) + yp)
        content_type_stats: dict = {}
        for r in cur.fetchall():
            t = r["type"]
            if t not in content_type_stats:
                content_type_stats[t] = {}
            content_type_stats[t][r["status"]] = r["count"]

        cur.execute(f"""
            SELECT m.type, ROUND(AVG(ue.score)::numeric, 2) AS avg_score
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND ue.score IS NOT NULL{yf_ue} GROUP BY m.type
        """, (uid,) + yp)
        avg_score_by_type = {r["type"]: float(r["avg_score"]) for r in cur.fetchall()}

        cur.execute(f"""
            SELECT ue.rewatch_count, m.title, m.type
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND ue.rewatch_count > 0{yf_ue}
            ORDER BY ue.rewatch_count DESC LIMIT 5
        """, (uid,) + yp)
        top_rewatched = [{"title": r["title"], "type": r["type"], "count": r["rewatch_count"]} for r in cur.fetchall()]

        cur.execute("""
            SELECT (FLOOR(m.year / 10) * 10)::int AS decade, COUNT(*) AS count
            FROM user_entries ue JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND m.year IS NOT NULL GROUP BY decade ORDER BY decade ASC
        """, (uid,))
        decade_distribution = [{"decade": r["decade"], "count": r["count"]} for r in cur.fetchall()]

    total_minutes = 0.0
    for r in watched_rows:
        mtype = r["type"] or ""
        dur = _parse_duration_minutes(r["duration"]) if r["duration"] else None
        if mtype == "MOVIE":
            if dur:
                total_minutes += dur
        elif mtype in ("SERIES", "ANIME", "DORAMA"):
            if dur:
                ep = r["ep_current"] or (1 if r["status"] == "completed" else 0)
                total_minutes += dur * ep
        elif mtype in ("MANGA", "MANHWA", "MANHUA", "WEBTOON"):
            ep = r["ep_current"] or 0
            chapter_min = dur if dur else 5
            total_minutes += chapter_min * ep
    time_spent_hours = round(total_minutes / 60.0, 2)
    time_spent_minutes = int(total_minutes)

    return {
        "total": total,
        "by_status": by_status,
        "by_type": by_type,
        "by_rating": by_rating,
        "completed": by_status.get("completed", 0),
        "watching": by_status.get("watching", 0),
        "plan": by_status.get("plan_to_watch", 0),
        "top_genres": top_genres,
        "top_genres_by_category": top_genres_by_category,
        "no_genre_count": no_genre_count,
        "recent_activity": recent_activity,
        "monthly_added": monthly_added,
        "score_distribution": score_distribution,
        "time_spent_hours": time_spent_hours,
        "time_spent_minutes": time_spent_minutes,
        "content_type_stats": content_type_stats,
        "avg_score_by_type": avg_score_by_type,
        "top_rewatched": top_rewatched,
        "decade_distribution": decade_distribution,
        "completed_this_year": completed_this_year,
    }


@router.get("/random-pick", response_model=EntryOut)
def random_pick(
    media_type: Optional[MediaType] = None,
    genre: Optional[str] = None,
    current_user = Depends(get_current_user),
):
    uid = current_user["id"]
    conditions = ["ue.user_id = %s", "ue.status = 'plan_to_watch'"]
    params: list = [uid]
    if media_type:
        conditions.append("m.type = %s")
        params.append(media_type)
    if genre:
        conditions.append("%s = ANY(m.genres)")
        params.append(genre)
    where = " AND ".join(conditions)
    row = fetchone(f"""
        SELECT ue.* FROM user_entries ue JOIN media m ON m.id = ue.media_id
        WHERE {where} ORDER BY RANDOM() LIMIT 1
    """, params)
    if not row:
        raise HTTPException(404, "No hay entradas pendientes")
    return _build_entry_out(dict(row))


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
        conditions.append("(m.title ILIKE %s OR m.title_original ILIKE %s)")
        params.extend([f"%{q}%", f"%{q}%"])

    where = " AND ".join(conditions)
    sql = f"""
        SELECT ue.*
        FROM user_entries ue
        JOIN media m ON m.id = ue.media_id
        WHERE {where}
        ORDER BY ue.updated_at DESC
        LIMIT %s OFFSET %s
    """
    rows = fetchall(sql, params + [limit, offset])
    return _build_entries_out(rows)


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

    # Auto-fill dates on status change
    if "status" in fields:
        today = dt_date.today()
        new_status = fields["status"]
        if new_status == "watching":
            if "started_at" not in fields and not existing_dict.get("started_at"):
                fields["started_at"] = today
        elif new_status == "completed":
            if "started_at" not in fields and not existing_dict.get("started_at"):
                fields["started_at"] = today
            if "completed_at" not in fields and not existing_dict.get("completed_at"):
                fields["completed_at"] = today

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
