import requests
from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from models import MediaCreate, MediaOut, SearchResult, MediaType
from database import get_conn, fetchone, fetchall
from routers.auth_router import get_current_user
from config import TMDB_API_KEY, ANILIST_URL

router = APIRouter(prefix="/media", tags=["media"])

TMDB_BASE = "https://api.themoviedb.org/3"
TMDB_IMG  = "https://image.tmdb.org/t/p/w500"
TMDB_HEADERS = {"Accept": "application/json", "Content-Type": "application/json"}

ANILIST_QUERY = """
query ($search: String, $type: MediaType) {
  Page(page: 1, perPage: 10) {
    media(search: $search, type: $type, sort: [SEARCH_MATCH]) {
      id title { romaji english native }
      format status chapters volumes
      startDate { year }
      description(asHtml: false)
      coverImage { large }
      genres averageScore countryOfOrigin
    }
  }
}
"""


def _tmdb_get(path: str, params: dict = None) -> dict:
    if not TMDB_API_KEY:
        return {}
    p = {"language": "es-ES", **(params or {})}
    r = requests.get(f"{TMDB_BASE}{path}", params=p,
                     headers={**TMDB_HEADERS, "Authorization": f"Bearer {TMDB_API_KEY}"},
                     timeout=10)
    if r.status_code != 200:
        return {}
    return r.json()


def _search_tmdb_movies(query: str) -> List[SearchResult]:
    data = _tmdb_get("/search/movie", {"query": query})
    results = []
    for m in data.get("results", [])[:5]:
        results.append(SearchResult(
            source="tmdb",
            external_id=str(m["id"]),
            title=m.get("title", ""),
            title_original=m.get("original_title"),
            year=int(m["release_date"][:4]) if m.get("release_date") else None,
            cover_url=f"{TMDB_IMG}{m['poster_path']}" if m.get("poster_path") else None,
            genres=None,
            synopsis=m.get("overview"),
            score=m.get("vote_average"),
            type=MediaType.MOVIE,
        ))
    return results


def _search_tmdb_tv(query: str, media_type: MediaType) -> List[SearchResult]:
    data = _tmdb_get("/search/tv", {"query": query})
    results = []
    for m in data.get("results", [])[:5]:
        origin = m.get("origin_country", [])
        # Guess type from origin country
        t = media_type
        if t == MediaType.SERIES and origin and any(c in ["KR", "JP", "TH", "CN"] for c in origin):
            t = MediaType.DORAMA
        results.append(SearchResult(
            source="tmdb",
            external_id=str(m["id"]),
            title=m.get("name", ""),
            title_original=m.get("original_name"),
            year=int(m["first_air_date"][:4]) if m.get("first_air_date") else None,
            cover_url=f"{TMDB_IMG}{m['poster_path']}" if m.get("poster_path") else None,
            genres=None,
            synopsis=m.get("overview"),
            score=m.get("vote_average"),
            type=t,
            country=", ".join(origin) if origin else None,
        ))
    return results


def _search_anilist(query: str, media_type: str) -> List[SearchResult]:
    try:
        r = requests.post(
            ANILIST_URL,
            json={"query": ANILIST_QUERY, "variables": {"search": query, "type": media_type}},
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        data = r.json()
    except Exception:
        return []
    results = []
    for m in data.get("data", {}).get("Page", {}).get("media", [])[:5]:
        fmt = m.get("format", "")
        country = m.get("countryOfOrigin", "")
        t = MediaType.MANGA
        if fmt == "MANHWA" or country == "KR":
            t = MediaType.MANHWA
        elif fmt == "MANHUA" or country in ("CN", "TW"):
            t = MediaType.MANHUA
        elif media_type == "ANIME":
            t = MediaType.ANIME
        titles = m.get("title", {})
        results.append(SearchResult(
            source="anilist",
            external_id=str(m["id"]),
            title=titles.get("romaji") or titles.get("english") or "",
            title_original=titles.get("native"),
            year=(m.get("startDate") or {}).get("year"),
            cover_url=(m.get("coverImage") or {}).get("large"),
            genres=m.get("genres"),
            synopsis=m.get("description"),
            score=m.get("averageScore", 0) / 10 if m.get("averageScore") else None,
            type=t,
        ))
    return results


@router.get("/search", response_model=List[SearchResult])
def search_metadata(
    q: str = Query(min_length=2),
    type: MediaType = Query(MediaType.DORAMA),
    _user = Depends(get_current_user),
):
    results = []
    if type in (MediaType.MOVIE,):
        results += _search_tmdb_movies(q)
    elif type in (MediaType.SERIES, MediaType.DORAMA):
        results += _search_tmdb_tv(q, type)
    elif type in (MediaType.MANGA, MediaType.MANHWA, MediaType.MANHUA, MediaType.WEBTOON):
        results += _search_anilist(q, "MANGA")
    elif type == MediaType.ANIME:
        results += _search_anilist(q, "ANIME")
    # Always add TMDB cross-reference for doramas/series
    if type == MediaType.DORAMA and not results:
        results += _search_tmdb_tv(q, type)
    return results


@router.post("/", response_model=MediaOut)
def create_media(data: MediaCreate, _user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO media (type, title, title_original, year, genres, synopsis,
                cover_url, duration, country, network, cast_text, external_score,
                tmdb_id, anilist_id, platform)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT DO NOTHING
            RETURNING *
        """, (
            data.type, data.title, data.title_original, data.year,
            data.genres, data.synopsis, data.cover_url, data.duration,
            data.country, data.network, data.cast_text, data.external_score,
            data.tmdb_id, data.anilist_id, data.platform,
        ))
        row = cur.fetchone()
        if not row:
            # Already exists - find by title+type
            cur.execute("SELECT * FROM media WHERE title=%s AND type=%s", (data.title, data.type))
            row = cur.fetchone()
    return MediaOut(**dict(row))


@router.get("/", response_model=List[MediaOut])
def list_media(
    type: Optional[MediaType] = None,
    q: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    _user = Depends(get_current_user),
):
    conditions = []
    params = []
    if type:
        conditions.append("type = %s")
        params.append(type)
    if q:
        conditions.append("title ILIKE %s")
        params.append(f"%{q}%")
    where = "WHERE " + " AND ".join(conditions) if conditions else ""
    rows = fetchall(f"SELECT * FROM media {where} ORDER BY title LIMIT %s OFFSET %s",
                    params + [limit, offset])
    return [MediaOut(**dict(r)) for r in rows]


@router.get("/{media_id}", response_model=MediaOut)
def get_media(media_id: int, _user = Depends(get_current_user)):
    row = fetchone("SELECT * FROM media WHERE id = %s", (media_id,))
    if not row:
        raise HTTPException(404, "Media no encontrada")
    return MediaOut(**dict(row))
