import requests
import ipaddress
from urllib.parse import urlparse
from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from pydantic import BaseModel
from models import MediaCreate, MediaOut, SearchResult, MediaType, EmissionStatus
from database import get_conn, fetchone, fetchall
from routers.auth_router import get_current_user
from config import TMDB_API_KEY, ANILIST_URL, CACHE_TTL_SEARCH
import cache_service as cache

router = APIRouter(prefix="/media", tags=["media"])

TMDB_BASE = "https://api.themoviedb.org/3"
TMDB_IMG  = "https://image.tmdb.org/t/p/w500"
TMDB_HEADERS = {"Accept": "application/json", "Content-Type": "application/json"}

JIKAN_BASE = "https://api.jikan.moe/v4"
MANGADEX_BASE = "https://api.mangadex.org"
MANGADEX_IMG = "https://uploads.mangadex.org/covers"
MU_BASE = "https://api.mangaupdates.com/v1"
# Países considerados dorama
DORAMA_COUNTRIES = {"KR", "JP", "TH", "CN", "TW", "HK", "SG", "PH", "ID", "VN"}

ANILIST_QUERY = """
query ($search: String, $type: MediaType) {
  Page(page: 1, perPage: 15) {
    media(search: $search, type: $type, sort: [SEARCH_MATCH]) {
      id title { romaji english native }
      format status chapters volumes episodes
      startDate { year }
      description(asHtml: false)
      coverImage { extraLarge large }
      genres averageScore countryOfOrigin
      studios(isMain: true) { nodes { name } }
      staff(perPage: 5, sort: [RELEVANCE]) {
        edges { role node { name { full } } }
      }
      duration
    }
  }
}
"""

_ANILIST_STATUS_MAP = {
    "RELEASING":        EmissionStatus.AIRING,
    "FINISHED":         EmissionStatus.FINISHED,
    "NOT_YET_RELEASED": EmissionStatus.UPCOMING,
    "CANCELLED":        EmissionStatus.CANCELLED,
    "HIATUS":           EmissionStatus.HIATUS,
}


def _tmdb_get(path: str, params: dict = None) -> dict:
    if not TMDB_API_KEY:
        return {}
    p = {"language": "es-ES", **(params or {})}
    try:
        r = requests.get(
            f"{TMDB_BASE}{path}",
            params=p,
            headers={**TMDB_HEADERS, "Authorization": f"Bearer {TMDB_API_KEY}"},
            timeout=10,
        )
        if r.status_code != 200:
            return {}
        return r.json()
    except Exception:
        return {}


def _jikan_get(path: str, params: dict = None) -> dict:
    try:
        r = requests.get(f"{JIKAN_BASE}{path}", params=params or {}, timeout=10)
        if r.status_code != 200:
            return {}
        return r.json()
    except Exception:
        return {}


def _mangadex_get(path: str, params: dict = None) -> dict:
    try:
        r = requests.get(f"{MANGADEX_BASE}{path}", params=params or {}, timeout=10)
        if r.status_code != 200:
            return {}
        return r.json()
    except Exception:
        return {}


_TMDB_GENRES: dict = {}

def _ensure_tmdb_genres() -> dict:
    global _TMDB_GENRES
    if _TMDB_GENRES:
        return _TMDB_GENRES
    result: dict = {}
    for endpoint in ("/genre/tv/list", "/genre/movie/list"):
        for g in _tmdb_get(endpoint).get("genres", []):
            result[g["id"]] = g["name"]
    _TMDB_GENRES = result
    return result


def _strip_html(text: str) -> str:
    if not text:
        return text
    import re
    return re.sub(r"<[^>]+>", "", text).strip()


# ---------------------------------------------------------------------------
# MOVIES  (TMDB)
# ---------------------------------------------------------------------------

def _search_tmdb_movies(query: str) -> List[SearchResult]:
    ck = cache.cache_key("tmdb:movies", query)
    cached = cache.get(ck)
    if cached is not None:
        return [SearchResult(**r) for r in cached]
    data = _tmdb_get("/search/movie", {"query": query, "include_adult": False})
    gmap = _ensure_tmdb_genres()
    results = []
    for m in data.get("results", [])[:8]:
        genre_names = [gmap[gid] for gid in m.get("genre_ids", []) if gid in gmap]
        results.append(SearchResult(
            source="tmdb",
            external_id=str(m["id"]),
            title=m.get("title", ""),
            title_original=m.get("original_title"),
            year=int(m["release_date"][:4]) if m.get("release_date") else None,
            cover_url=f"{TMDB_IMG}{m['poster_path']}" if m.get("poster_path") else None,
            genres=genre_names or None,
            synopsis=m.get("overview") or None,
            score=round(m["vote_average"], 1) if m.get("vote_average") else None,
            type=MediaType.MOVIE,
            country=m.get("original_language", "").upper() or None,
        ))
    cache.set(ck, [r.model_dump() for r in results], ttl=CACHE_TTL_SEARCH)
    return results


# ---------------------------------------------------------------------------
# SERIES  (TMDB)
# ---------------------------------------------------------------------------

def _build_tmdb_tv_result(m: dict, forced_type: Optional[MediaType] = None) -> SearchResult:
    origin = m.get("origin_country", [])
    if forced_type:
        t = forced_type
    else:
        t = MediaType.DORAMA if any(c in DORAMA_COUNTRIES for c in origin) else MediaType.SERIES

    gmap = _ensure_tmdb_genres()
    genre_names = [gmap[gid] for gid in m.get("genre_ids", []) if gid in gmap]
    return SearchResult(
        source="tmdb",
        external_id=str(m["id"]),
        title=m.get("name", ""),
        title_original=m.get("original_name"),
        year=int(m["first_air_date"][:4]) if m.get("first_air_date") else None,
        cover_url=f"{TMDB_IMG}{m['poster_path']}" if m.get("poster_path") else None,
        genres=genre_names or None,
        synopsis=m.get("overview") or None,
        score=round(m["vote_average"], 1) if m.get("vote_average") else None,
        type=t,
        country=", ".join(origin) if origin else None,
    )


def _search_tmdb_series(query: str) -> List[SearchResult]:
    """Series occidentales: filtra resultados que NO sean de países dorama."""
    ck = cache.cache_key("tmdb:series", query)
    cached = cache.get(ck)
    if cached is not None:
        return [SearchResult(**r) for r in cached]
    data = _tmdb_get("/search/tv", {"query": query, "include_adult": False})
    results = []
    for m in data.get("results", [])[:10]:
        origin = m.get("origin_country", [])
        if not any(c in DORAMA_COUNTRIES for c in origin):
            results.append(_build_tmdb_tv_result(m, forced_type=MediaType.SERIES))
    # Si no hay resultados no-asiáticos, devuelve todo
    if not results:
        for m in data.get("results", [])[:5]:
            results.append(_build_tmdb_tv_result(m, forced_type=MediaType.SERIES))
    cache.set(ck, [r.model_dump() for r in results[:6]], ttl=CACHE_TTL_SEARCH)
    return results[:6]


# ---------------------------------------------------------------------------
# Title language helpers
# ---------------------------------------------------------------------------

def _is_non_latin(text: str) -> bool:
    """Returns True if text contains Thai, CJK, Korean or other non-Latin script."""
    for c in text:
        cp = ord(c)
        if (0x0E00 <= cp <= 0x0E7F    # Thai
                or 0x4E00 <= cp <= 0x9FFF   # CJK Unified Ideographs
                or 0x3040 <= cp <= 0x30FF   # Hiragana + Katakana
                or 0xAC00 <= cp <= 0xD7A3   # Korean syllables
                or 0x1100 <= cp <= 0x11FF): # Korean Jamo
            return True
    return False


def _apply_latin_title(results: List[SearchResult], query: str) -> List[SearchResult]:
    """
    For any result whose title is in non-Latin script (Thai, CJK, Korean), resolve
    an English title via three escalating strategies:
    1. Re-search TMDB with the original query and language=en-US (fast, covers most cases).
    2. Fetch /tv/{id} with language=en-US directly (covers discovery-fallback results
       whose name doesn't match the query).
    3. Check /tv/{id}/alternative_titles for any Latin-script title (covers shows with
       no official en-US translation but known by an English alias).
    If none of the three yield a Latin title the original is kept but moved to
    title_original so the user can at least see it.
    """
    non_latin = [r for r in results if _is_non_latin(r.title)]
    if not non_latin:
        return results

    en_map: dict = {}

    # Strategy 1: re-search by query
    en_data = _tmdb_get("/search/tv", {"query": query, "include_adult": False, "language": "en-US"})
    for m in en_data.get("results", []):
        name = m.get("name", "")
        if name and not _is_non_latin(name):
            en_map[str(m["id"])] = name

    # Strategies 2 & 3: per-show lookup for still-unresolved results
    for r in non_latin:
        if r.external_id in en_map:
            continue
        # Strategy 2: detail endpoint
        detail = _tmdb_get(f"/tv/{r.external_id}", {"language": "en-US"})
        name = detail.get("name", "")
        if name and not _is_non_latin(name):
            en_map[r.external_id] = name
            continue
        # Strategy 3: alternative titles
        alts = _tmdb_get(f"/tv/{r.external_id}/alternative_titles")
        best: str = ""
        for alt in alts.get("results", []):
            alt_title = alt.get("title", "")
            if not alt_title or _is_non_latin(alt_title):
                continue
            iso = alt.get("iso_3166_1", "")
            if iso in ("US", "GB", "AU", "XW"):  # English-speaking or global
                en_map[r.external_id] = alt_title
                best = ""
                break
            if not best:
                best = alt_title  # first Latin alt as fallback
        if r.external_id not in en_map and best:
            en_map[r.external_id] = best

    out = []
    for r in results:
        if not _is_non_latin(r.title):
            out.append(r)
        elif r.external_id in en_map:
            # Preserve original-script title in title_original if not already set
            orig = r.title_original if r.title_original else r.title
            out.append(r.model_copy(update={"title": en_map[r.external_id], "title_original": orig}))
        else:
            # No Latin title found anywhere — keep as-is; at least title_original is populated
            orig = r.title_original if r.title_original else r.title
            out.append(r.model_copy(update={"title_original": orig}))
    return out


def _search_tmdb_dorama(query: str) -> List[SearchResult]:
    """
    Doramas asiáticos. Todas las llamadas usan language=en-US para obtener el título
    oficial en inglés directamente, sin depender de traducciones al español que a menudo
    no existen y provocan que TMDB devuelva el título en el idioma original (tailandés,
    chino, japonés…). _apply_latin_title queda como red de seguridad para obras que
    TMDB no tiene traducidas al inglés.
    """
    seen_ids: set = set()
    results: List[SearchResult] = []

    def _add_from_data(data: dict, max_items: int = 10):
        for m in data.get("results", [])[:max_items]:
            if str(m["id"]) in seen_ids:
                continue
            origin = m.get("origin_country", [])
            if any(c in DORAMA_COUNTRIES for c in origin):
                seen_ids.add(str(m["id"]))
                results.append(_build_tmdb_tv_result(m, forced_type=MediaType.DORAMA))

    # Búsqueda principal en inglés — TMDB busca en todos los idiomas pero devuelve
    # el título en-US, que tiene cobertura mucho mayor que es-ES para contenido asiático
    _add_from_data(_tmdb_get("/search/tv", {
        "query": query, "include_adult": False, "language": "en-US",
    }))

    # Fallback: discover por idioma original + match manual de palabras del query
    if len(results) < 3:
        for lang in ["ko", "ja", "zh", "th", "vi", "id"]:
            disc = _tmdb_get("/discover/tv", {
                "with_original_language": lang,
                "sort_by": "vote_count.desc",
                "include_adult": False,
                "vote_count.gte": 20,
                "language": "en-US",
            })
            for m in disc.get("results", [])[:20]:
                name_en = m.get("name", "")
                orig    = m.get("original_name", "")
                # Match contra título inglés y también contra título original romanizado
                haystack = (name_en + " " + orig).lower()
                if any(w.lower() in haystack for w in query.split() if len(w) > 2):
                    if str(m["id"]) not in seen_ids:
                        seen_ids.add(str(m["id"]))
                        results.append(_build_tmdb_tv_result(m, forced_type=MediaType.DORAMA))

    # Sin resultados asiáticos: devuelve cualquier resultado en inglés
    if not results:
        data = _tmdb_get("/search/tv", {
            "query": query, "include_adult": False, "language": "en-US",
        })
        for m in data.get("results", [])[:5]:
            if str(m["id"]) not in seen_ids:
                results.append(_build_tmdb_tv_result(m, forced_type=MediaType.DORAMA))

    # Red de seguridad: sustituye cualquier título no-latino residual por su versión inglesa
    results = _apply_latin_title(results, query)

    return results[:8]


# ---------------------------------------------------------------------------
# ANIME  (AniList primario + Jikan/MAL secundario)
# ---------------------------------------------------------------------------

def _search_anilist(query: str, media_type: str) -> List[SearchResult]:
    ck = cache.cache_key("anilist", media_type, query)
    cached = cache.get(ck)
    if cached is not None:
        return [SearchResult(**r) for r in cached]
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
    for m in data.get("data", {}).get("Page", {}).get("media", [])[:8]:
        fmt = m.get("format", "") or ""
        country = m.get("countryOfOrigin", "") or ""

        if media_type == "ANIME":
            t = MediaType.ANIME
        elif fmt in ("MANHWA",) or country == "KR":
            t = MediaType.MANHWA
        elif fmt in ("MANHUA",) or country in ("CN", "TW"):
            t = MediaType.MANHUA
        elif fmt in ("WEBTOON",):
            t = MediaType.WEBTOON
        else:
            t = MediaType.MANGA

        titles = m.get("title", {})
        cover = (m.get("coverImage") or {})
        synopsis = _strip_html(m.get("description"))

        # Studio / cadena
        studios = (m.get("studios") or {}).get("nodes", [])
        network = studios[0]["name"] if studios else None

        # Staff: director + guionistas
        cast_parts = []
        for edge in (m.get("staff") or {}).get("edges", []):
            role = edge.get("role", "")
            name = (edge.get("node") or {}).get("name", {}).get("full", "")
            if name and ("Director" in role or "Story" in role or "Script" in role):
                cast_parts.append(f"{name} ({role})")
        cast_text = ", ".join(cast_parts) if cast_parts else None

        duration_min = m.get("duration")
        duration = f"{duration_min} min" if duration_min else None

        emission_status = _ANILIST_STATUS_MAP.get(m.get("status", ""))

        ep_count = m.get("episodes") if media_type == "ANIME" else m.get("chapters")

        results.append(SearchResult(
            source="anilist",
            external_id=str(m["id"]),
            title=titles.get("romaji") or titles.get("english") or "",
            title_original=titles.get("native"),
            year=(m.get("startDate") or {}).get("year"),
            cover_url=cover.get("extraLarge") or cover.get("large"),
            genres=m.get("genres") or None,
            synopsis=synopsis or None,
            score=round(m["averageScore"] / 10, 1) if m.get("averageScore") else None,
            type=t,
            duration=duration,
            country=country or None,
            emission_status=emission_status,
            network=network,
            cast_text=cast_text,
            episodes=ep_count,
        ))
    cache.set(ck, [r.model_dump() for r in results], ttl=CACHE_TTL_SEARCH)
    return results


def _search_jikan_anime(query: str) -> List[SearchResult]:
    """MyAnimeList via Jikan v4 — fuente secundaria de anime."""
    ck = cache.cache_key("jikan:anime", query)
    cached = cache.get(ck)
    if cached is not None:
        return [SearchResult(**r) for r in cached]
    data = _jikan_get("/anime", {"q": query, "limit": 8, "sfw": True})
    seen_mal_ids: set = set()
    results = []
    for m in data.get("data", []):
        mal_id = str(m.get("mal_id", ""))
        if mal_id in seen_mal_ids:
            continue
        seen_mal_ids.add(mal_id)

        images = (m.get("images") or {}).get("jpg", {})
        cover = images.get("large_image_url") or images.get("image_url")

        genres = [g["name"] for g in (m.get("genres") or []) + (m.get("themes") or [])]

        aired = (m.get("aired") or {}).get("from")
        year = None
        if aired:
            try:
                year = int(aired[:4])
            except Exception:
                pass

        duration_raw = m.get("duration", "") or ""
        duration = duration_raw.replace(" per ep", "").strip() or None

        results.append(SearchResult(
            source="jikan",
            external_id=f"mal_{mal_id}",
            title=m.get("title_english") or m.get("title") or "",
            title_original=m.get("title_japanese"),
            year=year,
            cover_url=cover,
            genres=genres or None,
            synopsis=m.get("synopsis") or None,
            score=round(float(m["score"]), 1) if m.get("score") else None,
            type=MediaType.ANIME,
            duration=duration,
            country="JP",
        ))
    cache.set(ck, [r.model_dump() for r in results], ttl=CACHE_TTL_SEARCH)
    return results


# ---------------------------------------------------------------------------
# MANGA / MANHWA / MANHUA / WEBTOON  (AniList + MangaDex)
# ---------------------------------------------------------------------------

_MANGADEX_STATUS_MAP = {
    "ongoing":   EmissionStatus.AIRING,
    "completed": EmissionStatus.FINISHED,
    "hiatus":    EmissionStatus.HIATUS,
    "cancelled": EmissionStatus.CANCELLED,
}

_MU_TYPE_MAP = {
    "Manga":            MediaType.MANGA,
    "Manhwa":           MediaType.MANHWA,
    "Manhua":           MediaType.MANHUA,
    "Webtoon":          MediaType.WEBTOON,
    "Webtoon (Manhwa)": MediaType.MANHWA,
    "Webtoon (Manhua)": MediaType.MANHUA,
}


def _search_mangadex(query: str, requested_type: MediaType) -> List[SearchResult]:
    """MangaDex — soporta búsqueda por títulos traducidos (español y otros idiomas)."""
    data = _mangadex_get("/manga", {
        "title": query,
        "limit": 15,
        "includes[]": ["cover_art"],
        "order[relevance]": "desc",
        "contentRating[]": ["safe", "suggestive", "erotica"],
    })

    results = []
    for m in data.get("data", []):
        attrs = m.get("attributes", {})
        manga_id = m.get("id", "")

        # Título: preferir español, luego inglés, luego romaji, luego cualquiera
        titles = attrs.get("title", {})
        alt_titles_list = attrs.get("altTitles", [])
        all_titles: dict = {**titles}
        for alt in alt_titles_list:
            all_titles.update(alt)

        title = (
            all_titles.get("es")
            or all_titles.get("es-la")
            or all_titles.get("en")
            or all_titles.get("ja-ro")
            or next(iter(all_titles.values()), "")
        )
        if not title:
            continue

        title_original = (
            all_titles.get("ja")
            or all_titles.get("ko")
            or all_titles.get("zh")
            or all_titles.get("zh-hk")
        )

        # Portada desde las relaciones
        cover_url = None
        for rel in m.get("relationships", []):
            if rel.get("type") == "cover_art":
                fn = (rel.get("attributes") or {}).get("fileName")
                if fn:
                    cover_url = f"{MANGADEX_IMG}/{manga_id}/{fn}"
                break

        # Tipo según idioma original
        orig_lang = attrs.get("originalLanguage", "")
        if orig_lang == "ko":
            t = MediaType.MANHWA
        elif orig_lang in ("zh", "zh-hk"):
            t = MediaType.MANHUA
        else:
            t = requested_type

        genres = [
            tag["attributes"]["name"].get("en", "")
            for tag in attrs.get("tags", [])
            if (tag.get("attributes") or {}).get("group") == "genre"
        ]

        desc_dict = attrs.get("description", {})
        synopsis = (
            desc_dict.get("es")
            or desc_dict.get("es-la")
            or desc_dict.get("en")
            or next(iter(desc_dict.values()), None)
        )

        results.append(SearchResult(
            source="mangadex",
            external_id=f"mdx_{manga_id}",
            title=title,
            title_original=title_original,
            year=attrs.get("year"),
            cover_url=cover_url,
            genres=genres or None,
            synopsis=_strip_html(synopsis) or None,
            score=None,
            type=t,
            emission_status=_MANGADEX_STATUS_MAP.get(attrs.get("status", "")),
            country=orig_lang.upper() if orig_lang else None,
        ))
    return results


def _search_mangaupdates(query: str, requested_type: MediaType) -> List[SearchResult]:
    """MangaUpdates — catálogo extenso con títulos alternativos en múltiples idiomas."""
    try:
        r = requests.post(
            f"{MU_BASE}/series/search",
            json={"search": query, "perpage": 10},
            timeout=10,
        )
        if r.status_code != 200:
            return []
        data = r.json()
    except Exception:
        return []

    results = []
    for res in data.get("results", []):
        rec = res.get("record", {})
        series_id = str(rec.get("series_id", ""))
        title = rec.get("title", "")
        if not series_id or not title:
            continue

        t = _MU_TYPE_MAP.get(rec.get("type", ""), requested_type)
        cover_url = ((rec.get("image") or {}).get("url") or {}).get("original")

        genres = [g["genre"] for g in (rec.get("genres") or []) if g.get("genre")]

        year = None
        try:
            year = int(str(rec.get("year", ""))[:4])
        except (ValueError, TypeError):
            pass

        synopsis = _strip_html(rec.get("description") or "") or None

        results.append(SearchResult(
            source="mangaupdates",
            external_id=f"mu_{series_id}",
            title=title,
            title_original=None,
            year=year,
            cover_url=cover_url,
            genres=genres or None,
            synopsis=synopsis,
            score=None,
            type=t,
        ))
    return results


def _title_key(title: str) -> str:
    """Normaliza un título para deduplicación (solo alfanumérico ASCII en minúsculas)."""
    import re
    return re.sub(r"[^a-z0-9]", "", title.lower())


def _search_manga(query: str, requested_type: MediaType) -> List[SearchResult]:
    anilist = _search_anilist(query, "MANGA")
    mangaupdates = _search_mangaupdates(query, requested_type)
    mangadex = _search_mangadex(query, requested_type)

    # AniList primero, filtrado por tipo si hay resultados del tipo pedido
    anilist_typed = [r for r in anilist if r.type == requested_type]
    anilist_final = anilist_typed if anilist_typed else anilist

    # Merge MangaUpdates + MangaDex sin duplicar (por título normalizado o external_id)
    seen_keys = {_title_key(r.title) for r in anilist_final if _title_key(r.title)}
    seen_ids: set = set()
    extras = []
    for r in mangaupdates + mangadex:
        key = _title_key(r.title)
        if (key and key in seen_keys) or r.external_id in seen_ids:
            continue
        extras.append(r)
        seen_ids.add(r.external_id)
        if key:
            seen_keys.add(key)

    return (anilist_final + extras)[:12]


# ---------------------------------------------------------------------------
# Library membership check — annotates SearchResults with entry_id/status/rating
# Called after external-API results are obtained so the cache never stores user data.
# ---------------------------------------------------------------------------

def _augment_with_library(results: List[SearchResult], user_id: int) -> List[SearchResult]:
    if not results:
        return results

    tmdb_ids    = [int(r.external_id) for r in results
                   if r.source == "tmdb" and r.external_id.isdigit()]
    anilist_ids = [int(r.external_id) for r in results
                   if r.source == "anilist" and r.external_id.isdigit()]
    all_titles  = [r.title.lower() for r in results]

    conditions: List[str] = []
    params: list = [user_id]

    if tmdb_ids:
        conditions.append("m.tmdb_id = ANY(%s)")
        params.append(tmdb_ids)
    if anilist_ids:
        conditions.append("m.anilist_id = ANY(%s)")
        params.append(anilist_ids)
    if all_titles:
        conditions.append("LOWER(m.title) = ANY(%s)")
        params.append(all_titles)

    if not conditions:
        return results

    try:
        rows = fetchall(
            f"""
            SELECT ue.id, ue.status, ue.rating_label,
                   m.tmdb_id, m.anilist_id, LOWER(m.title) AS title_lower
            FROM user_entries ue
            JOIN media m ON m.id = ue.media_id
            WHERE ue.user_id = %s AND ({' OR '.join(conditions)})
            """,
            params,
        )
    except Exception:
        return results

    tmdb_map:   dict = {}
    anilist_map: dict = {}
    title_map:  dict = {}

    for row in rows:
        info = {
            "entry_id":     row["id"],
            "entry_status": row["status"],
            "entry_rating": row["rating_label"],
        }
        if row["tmdb_id"]:
            tmdb_map[row["tmdb_id"]] = info
        if row["anilist_id"]:
            anilist_map[row["anilist_id"]] = info
        tl = row["title_lower"]
        if tl:
            title_map[tl] = info

    augmented = []
    for r in results:
        match = None
        if r.source == "tmdb" and r.external_id.isdigit():
            match = tmdb_map.get(int(r.external_id))
        elif r.source == "anilist" and r.external_id.isdigit():
            match = anilist_map.get(int(r.external_id))
        else:
            # Only fall back to title matching for sources without a canonical numeric ID
            # (jikan, mangadex, mangaupdates). Never use title alone for tmdb/anilist
            # because the same title can belong to multiple distinct works (different years).
            match = title_map.get(r.title.lower())
        augmented.append(r.model_copy(update=match) if match else r)

    return augmented


# ---------------------------------------------------------------------------
# Endpoint principal
# ---------------------------------------------------------------------------

@router.get("/search", response_model=List[SearchResult])
def search_metadata(
    q: str = Query(min_length=2),
    type: MediaType = Query(MediaType.DORAMA),
    user = Depends(get_current_user),
):
    if type == MediaType.MOVIE:
        results = _search_tmdb_movies(q)

    elif type == MediaType.SERIES:
        results = _search_tmdb_series(q)

    elif type == MediaType.DORAMA:
        results = _search_tmdb_dorama(q)

    elif type == MediaType.ANIME:
        anilist = _search_anilist(q, "ANIME")
        jikan = _search_jikan_anime(q)
        seen_titles = {r.title.lower() for r in anilist}
        extras = [r for r in jikan if r.title.lower() not in seen_titles]
        results = (anilist + extras)[:10]

    elif type in (MediaType.MANGA, MediaType.MANHWA, MediaType.MANHUA, MediaType.WEBTOON):
        results = _search_manga(q, type)

    else:
        results = []

    return _augment_with_library(results, user["id"])


# ---------------------------------------------------------------------------
# CRUD de media
# ---------------------------------------------------------------------------

@router.post("/", response_model=MediaOut)
def create_media(data: MediaCreate, _user = Depends(get_current_user)):
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO media (type, title, title_original, year, genres, synopsis,
                cover_url, duration, country, network, cast_text, external_score,
                emission_status, tmdb_id, anilist_id, platform)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT DO NOTHING
            RETURNING *
        """, (
            data.type, data.title, data.title_original, data.year,
            data.genres, data.synopsis, data.cover_url, data.duration,
            data.country, data.network, data.cast_text, data.external_score,
            data.emission_status, data.tmdb_id, data.anilist_id, data.platform,
        ))
        row = cur.fetchone()
        if not row:
            cur.execute("SELECT * FROM media WHERE title=%s AND type=%s", (data.title, data.type))
            row = cur.fetchone()
            # Update genres if the existing record had none
            if row and not row["genres"] and data.genres:
                cur.execute(
                    "UPDATE media SET genres=%s, updated_at=NOW() WHERE id=%s RETURNING *",
                    (data.genres, row["id"])
                )
                updated = cur.fetchone()
                if updated:
                    row = updated
    if row is None:
        raise HTTPException(500, "No se pudo crear el media")
    return MediaOut(**dict(row))


@router.post("/admin/repair-titles")
def repair_non_latin_titles(_user = Depends(get_current_user)):
    """Find all media records with non-Latin titles and resolve them via TMDB."""
    if not _user.get("is_admin"):
        raise HTTPException(403, "Solo administradores")

    rows = fetchall("""
        SELECT id, type, title, title_original, tmdb_id
        FROM media
        WHERE title ~ '[^\\x00-\\x7F]'
        ORDER BY id
    """)

    updated = 0
    skipped = 0
    results = []

    for row in rows:
        media_id = row["id"]
        tmdb_id = row["tmdb_id"]
        current_title = row["title"]
        current_orig = row["title_original"]

        new_title = None

        if tmdb_id:
            # Strategy 1: detail endpoint
            mtype = row["type"]
            endpoint = f"/movie/{tmdb_id}" if mtype == "MOVIE" else f"/tv/{tmdb_id}"
            detail = _tmdb_get(endpoint, {"language": "en-US"})
            name = detail.get("name") or detail.get("title", "")
            if name and not _is_non_latin(name):
                new_title = name
            else:
                # Strategy 2: alternative titles
                alts_ep = f"/movie/{tmdb_id}/alternative_titles" if mtype == "MOVIE" else f"/tv/{tmdb_id}/alternative_titles"
                alts = _tmdb_get(alts_ep)
                best = ""
                for alt in alts.get("results", []) + alts.get("titles", []):
                    alt_title = alt.get("title", "")
                    if not alt_title or _is_non_latin(alt_title):
                        continue
                    if alt.get("iso_3166_1") in ("US", "GB", "AU", "XW"):
                        new_title = alt_title
                        best = ""
                        break
                    if not best:
                        best = alt_title
                if not new_title and best:
                    new_title = best

        if new_title:
            orig = current_orig if current_orig else current_title
            with get_conn() as conn:
                cur = conn.cursor()
                cur.execute(
                    "UPDATE media SET title=%s, title_original=%s, updated_at=NOW() WHERE id=%s",
                    (new_title, orig, media_id)
                )
            results.append({"id": media_id, "old": current_title, "new": new_title})
            updated += 1
        else:
            skipped += 1

    return {"updated": updated, "skipped": skipped, "details": results}


@router.post("/admin/backfill-genres")
def backfill_genres(_user = Depends(get_current_user)):
    if not _user.get("is_admin"):
        raise HTTPException(403, "Solo administradores")
    gmap = _ensure_tmdb_genres()
    if not gmap:
        return {"updated": 0, "error": "TMDB unavailable"}

    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, tmdb_id, type FROM media
            WHERE tmdb_id IS NOT NULL AND (genres IS NULL OR genres = '{}')
        """)
        rows = cur.fetchall()

    updated = 0
    for row in rows:
        tmdb_id = row["tmdb_id"]
        mtype = row["type"]
        endpoint = f"/movie/{tmdb_id}" if mtype == "MOVIE" else f"/tv/{tmdb_id}"
        detail = _tmdb_get(endpoint)
        raw_genres = detail.get("genres", [])
        if not raw_genres:
            continue
        genre_names = [g["name"] for g in raw_genres if g.get("name")]
        if not genre_names:
            continue
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute(
                "UPDATE media SET genres=%s, updated_at=NOW() WHERE id=%s",
                (genre_names, row["id"])
            )
        updated += 1

    return {"updated": updated, "total_checked": len(rows)}


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


class CoverUpdate(BaseModel):
    cover_url: str


def _validate_cover_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
        if parsed.scheme not in ('http', 'https'):
            return False
        host = parsed.hostname
        if not host:
            return False
        # Block private/local IPs
        try:
            addr = ipaddress.ip_address(host)
            if addr.is_private or addr.is_loopback or addr.is_link_local:
                return False
        except ValueError:
            # It's a hostname, check it's not localhost
            if host.lower() in ('localhost', '0.0.0.0'):
                return False
        return True
    except Exception:
        return False


class EmissionStatusUpdate(BaseModel):
    emission_status: str


@router.patch("/{media_id}/emission-status", response_model=MediaOut)
def update_emission_status(media_id: int, data: EmissionStatusUpdate, _user = Depends(get_current_user)):
    valid = {"AIRING", "FINISHED", "UPCOMING", "CANCELLED", "HIATUS", "UNKNOWN", ""}
    if data.emission_status not in valid:
        raise HTTPException(400, f"Estado de emisión no válido: {data.emission_status!r}")
    val = data.emission_status if data.emission_status else None
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "UPDATE media SET emission_status = %s, updated_at = NOW() WHERE id = %s RETURNING *",
            (val, media_id),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, "Media no encontrada")
    return MediaOut(**dict(row))


@router.patch("/{media_id}/cover", response_model=MediaOut)
def update_cover(media_id: int, data: CoverUpdate, _user = Depends(get_current_user)):
    if not _validate_cover_url(data.cover_url):
        raise HTTPException(400, "URL de portada no válida")
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(
            "UPDATE media SET cover_url = %s, updated_at = NOW() WHERE id = %s RETURNING *",
            (data.cover_url, media_id),
        )
        row = cur.fetchone()
    if not row:
        raise HTTPException(404, "Media no encontrada")
    return MediaOut(**dict(row))
