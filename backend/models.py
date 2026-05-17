from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum
from datetime import date, datetime


class MediaType(str, Enum):
    MANGA   = "MANGA"
    MANHWA  = "MANHWA"
    MANHUA  = "MANHUA"
    WEBTOON = "WEBTOON"
    ANIME   = "ANIME"
    MOVIE   = "MOVIE"
    SERIES  = "SERIES"
    DORAMA  = "DORAMA"


class TrackingStatus(str, Enum):
    PLAN     = "plan_to_watch"
    WATCHING = "watching"
    COMPLETE = "completed"
    ON_HOLD  = "on_hold"
    DROPPED  = "dropped"


class RatingLabel(str, Enum):
    MUST        = "must"
    ME_ENCANTA  = "me_encanta"
    MUY_BONITA  = "muy_bonita"
    BONITA      = "bonita"
    PASABLE     = "pasable"
    NO_ME_GUSTO = "no_me_gusto"
    ABANDONADO  = "abandonado"
    SIN_VALORAR = "sin_valorar"


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    display_name: Optional[str] = None
    password: str = Field(min_length=6)


class UserLogin(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    id: int
    username: str
    display_name: Optional[str]
    avatar_url: Optional[str]
    is_admin: bool
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class MediaCreate(BaseModel):
    type: MediaType
    title: str
    title_original: Optional[str] = None
    year: Optional[int] = None
    genres: Optional[List[str]] = None
    synopsis: Optional[str] = None
    cover_url: Optional[str] = None
    duration: Optional[str] = None
    country: Optional[str] = None
    network: Optional[str] = None
    cast_text: Optional[str] = None
    external_score: Optional[float] = None
    tmdb_id: Optional[int] = None
    anilist_id: Optional[int] = None
    platform: Optional[str] = None


class MediaOut(MediaCreate):
    id: int
    created_at: datetime
    updated_at: datetime


class EntryCreate(BaseModel):
    media_id: int
    status: TrackingStatus = TrackingStatus.PLAN
    progress: Optional[str] = None
    score: Optional[float] = None
    rating_label: Optional[RatingLabel] = RatingLabel.SIN_VALORAR
    notes: Optional[str] = None
    platform: Optional[str] = None
    started_at: Optional[date] = None
    completed_at: Optional[date] = None


class EntryUpdate(BaseModel):
    status: Optional[TrackingStatus] = None
    progress: Optional[str] = None
    score: Optional[float] = None
    rating_label: Optional[RatingLabel] = None
    notes: Optional[str] = None
    platform: Optional[str] = None
    started_at: Optional[date] = None
    completed_at: Optional[date] = None


class EntryOut(BaseModel):
    id: int
    user_id: int
    media_id: int
    status: TrackingStatus
    progress: Optional[str]
    score: Optional[float]
    rating_label: Optional[RatingLabel]
    notes: Optional[str]
    platform: Optional[str]
    started_at: Optional[date]
    completed_at: Optional[date]
    created_at: datetime
    updated_at: datetime
    media: Optional[MediaOut] = None


class SearchResult(BaseModel):
    source: str
    external_id: str
    title: str
    title_original: Optional[str]
    year: Optional[int]
    cover_url: Optional[str]
    genres: Optional[List[str]]
    synopsis: Optional[str]
    score: Optional[float]
    type: MediaType
    duration: Optional[str] = None
    country: Optional[str] = None


class StatsOut(BaseModel):
    total: int
    by_type: dict
    by_status: dict
    by_rating: dict
    completed: int
    watching: int
    plan: int
