import csv
import io
import json
import xml.etree.ElementTree as ET
from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from database import fetchone, get_conn
from routers.auth_router import get_current_user

router = APIRouter(prefix="/import", tags=["import"])

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_MAL_STATUS_MAP = {
    "Completed":      "completed",
    "Read":           "completed",
    "Watching":       "watching",
    "Reading":        "watching",
    "Plan to Watch":  "plan_to_watch",
    "Plan to Read":   "plan_to_watch",
    "On-Hold":        "on_hold",
    "Dropped":        "dropped",
}

_LETTERBOXD_RATING_MAP = [
    (5.0,  "must"),
    (4.5,  "me_encanta"),
    (4.0,  "muy_bonita"),
    (3.5,  "bonita"),
    (3.0,  "pasable"),
]


def _parse_date(s: Optional[str]) -> Optional[date]:
    """Parse YYYY-MM-DD, ignore '0000-00-00' and empty/None."""
    if not s or s.startswith("0000"):
        return None
    try:
        return date.fromisoformat(s)
    except Exception:
        return None


def _letterboxd_rating_label(score: Optional[float]) -> str:
    if score is None:
        return "sin_valorar"
    for threshold, label in _LETTERBOXD_RATING_MAP:
        if score >= threshold:
            return label
    return "no_me_gusto"


def _upsert_media(cur, *, type: str, title: str, year: Optional[int] = None,
                  cover_url: Optional[str] = None, genres=None) -> int:
    """Insert media with ON CONFLICT DO NOTHING, then fetch the id."""
    cur.execute("""
        INSERT INTO media (type, title, year, cover_url, genres)
        VALUES (%s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
        RETURNING id
    """, (type, title, year, cover_url, genres))
    row = cur.fetchone()
    if row:
        return row["id"]
    # Already exists — fetch by title+type
    cur.execute("SELECT id FROM media WHERE title = %s AND type = %s", (title, type))
    existing = cur.fetchone()
    if existing:
        return existing["id"]
    raise RuntimeError(f"Could not find or create media: {title!r}")


def _insert_entry(cur, *, user_id: int, media_id: int, status: str,
                  score: Optional[float], rating_label: str,
                  started_at: Optional[date], completed_at: Optional[date],
                  progress: Optional[str] = None,
                  ep_current: Optional[int] = None,
                  ep_total: Optional[int] = None,
                  notes: Optional[str] = None) -> bool:
    """Insert entry with ON CONFLICT DO NOTHING. Returns True if inserted."""
    cur.execute("""
        INSERT INTO user_entries
            (user_id, media_id, status, score, rating_label,
             started_at, completed_at, progress, ep_current, ep_total, notes)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (user_id, media_id) DO NOTHING
        RETURNING id
    """, (user_id, media_id, status, score, rating_label,
          started_at, completed_at, progress, ep_current, ep_total, notes))
    return cur.fetchone() is not None


# ---------------------------------------------------------------------------
# Format parsers
# ---------------------------------------------------------------------------

def _import_own_json(content: str, user_id: int) -> dict:
    imported = 0
    skipped = 0
    errors = []

    try:
        data = json.loads(content)
    except Exception as e:
        raise HTTPException(400, f"JSON inválido: {e}")

    entries = data.get("entries", [])
    if not isinstance(entries, list):
        raise HTTPException(400, "El campo 'entries' debe ser una lista")

    with get_conn() as conn:
        cur = conn.cursor()
        for i, item in enumerate(entries):
            try:
                media_data = item.get("media") or {}
                entry_data = item.get("entry") or {}

                if not media_data or not entry_data:
                    skipped += 1
                    errors.append(f"Item {i}: faltan campos 'media' o 'entry'")
                    continue

                media_id = _upsert_media(
                    cur,
                    type=media_data["type"],
                    title=media_data["title"],
                    year=media_data.get("year"),
                    cover_url=media_data.get("cover_url"),
                    genres=media_data.get("genres"),
                )

                inserted = _insert_entry(
                    cur,
                    user_id=user_id,
                    media_id=media_id,
                    status=entry_data.get("status", "plan_to_watch"),
                    score=entry_data.get("score"),
                    rating_label=entry_data.get("rating_label") or "sin_valorar",
                    started_at=_parse_date(entry_data.get("started_at")),
                    completed_at=_parse_date(entry_data.get("completed_at")),
                    progress=entry_data.get("progress"),
                    ep_current=entry_data.get("ep_current"),
                    ep_total=entry_data.get("ep_total"),
                    notes=entry_data.get("notes"),
                )
                if inserted:
                    imported += 1
                else:
                    skipped += 1
            except Exception as e:
                skipped += 1
                errors.append(f"Item {i}: {e}")

    return {"imported": imported, "skipped": skipped, "errors": errors}


def _import_mal_xml(content: str, user_id: int) -> dict:
    imported = 0
    skipped = 0
    errors = []

    try:
        root = ET.fromstring(content)
    except Exception as e:
        raise HTTPException(400, f"XML inválido: {e}")

    items = []
    for anime_el in root.findall("anime"):
        items.append(("anime", anime_el))
    for manga_el in root.findall("manga"):
        items.append(("manga", manga_el))

    def _text(el, tag) -> Optional[str]:
        node = el.find(tag)
        return node.text.strip() if node is not None and node.text else None

    with get_conn() as conn:
        cur = conn.cursor()
        for kind, el in items:
            try:
                if kind == "anime":
                    title = _text(el, "series_title") or ""
                    media_type = "ANIME"
                    watched_ep = _text(el, "my_watched_episodes") or "0"
                    total_ep = _text(el, "series_episodes") or "0"
                    ep_current = int(watched_ep) if watched_ep.isdigit() else None
                    ep_total = int(total_ep) if total_ep.isdigit() and int(total_ep) > 0 else None
                    progress = f"{watched_ep}/{total_ep} ep" if total_ep and total_ep != "0" else f"{watched_ep} ep"
                    mal_status = _text(el, "my_status") or ""
                else:
                    title = _text(el, "series_title") or ""
                    media_type = "MANGA"
                    read_chaps = _text(el, "my_read_chapters") or "0"
                    ep_current = int(read_chaps) if read_chaps.isdigit() else None
                    ep_total = None
                    progress = f"{read_chaps} caps"
                    mal_status = _text(el, "my_status") or ""

                if not title:
                    skipped += 1
                    errors.append(f"Item sin título ({kind}), omitido")
                    continue

                status = _MAL_STATUS_MAP.get(mal_status, "plan_to_watch")

                score_raw = _text(el, "my_score") or "0"
                try:
                    score_val = float(score_raw)
                    score = score_val if score_val >= 1 else None
                except Exception:
                    score = None

                started_at = _parse_date(_text(el, "my_start_date"))
                completed_at = _parse_date(_text(el, "my_finish_date"))
                notes = _text(el, "my_comments") or None

                media_id = _upsert_media(cur, type=media_type, title=title)

                inserted = _insert_entry(
                    cur,
                    user_id=user_id,
                    media_id=media_id,
                    status=status,
                    score=score,
                    rating_label="sin_valorar",
                    started_at=started_at,
                    completed_at=completed_at,
                    progress=progress,
                    ep_current=ep_current,
                    ep_total=ep_total,
                    notes=notes,
                )
                if inserted:
                    imported += 1
                else:
                    skipped += 1
            except Exception as e:
                skipped += 1
                errors.append(f"Error en {kind} '{_text(el, 'series_title') or '?'}': {e}")

    return {"imported": imported, "skipped": skipped, "errors": errors}


def _import_letterboxd_csv(content: str, user_id: int) -> dict:
    imported = 0
    skipped = 0
    errors = []

    try:
        reader = csv.DictReader(io.StringIO(content))
        rows = list(reader)
    except Exception as e:
        raise HTTPException(400, f"CSV inválido: {e}")

    with get_conn() as conn:
        cur = conn.cursor()
        for i, row in enumerate(rows):
            try:
                name = (row.get("Name") or "").strip()
                if not name:
                    skipped += 1
                    errors.append(f"Fila {i + 2}: sin nombre, omitida")
                    continue

                year_raw = (row.get("Year") or "").strip()
                try:
                    year = int(year_raw) if year_raw else None
                except Exception:
                    year = None

                rating_raw = (row.get("Rating") or "").strip()
                try:
                    lb_score = float(rating_raw) if rating_raw else None
                except Exception:
                    lb_score = None

                score = round(lb_score * 2, 1) if lb_score is not None else None
                rating_label = _letterboxd_rating_label(lb_score)

                date_raw = (row.get("Date") or "").strip()
                completed_at = _parse_date(date_raw) if date_raw else None
                status = "completed" if completed_at else "plan_to_watch"

                media_id = _upsert_media(cur, type="MOVIE", title=name, year=year)

                inserted = _insert_entry(
                    cur,
                    user_id=user_id,
                    media_id=media_id,
                    status=status,
                    score=score,
                    rating_label=rating_label,
                    started_at=None,
                    completed_at=completed_at,
                )
                if inserted:
                    imported += 1
                else:
                    skipped += 1
            except Exception as e:
                skipped += 1
                errors.append(f"Fila {i + 2}: {e}")

    return {"imported": imported, "skipped": skipped, "errors": errors}


# ---------------------------------------------------------------------------
# Endpoint
# ---------------------------------------------------------------------------

class ImportRequest(BaseModel):
    format: str  # "own_json" | "mal_xml" | "letterboxd_csv"
    content: str


@router.post("/")
def import_entries(data: ImportRequest, current_user = Depends(get_current_user)):
    uid = current_user["id"]
    fmt = data.format

    if fmt == "own_json":
        return _import_own_json(data.content, uid)
    elif fmt == "mal_xml":
        return _import_mal_xml(data.content, uid)
    elif fmt == "letterboxd_csv":
        return _import_letterboxd_csv(data.content, uid)
    else:
        raise HTTPException(400, f"Formato no soportado: {fmt!r}. Use 'own_json', 'mal_xml' o 'letterboxd_csv'")
