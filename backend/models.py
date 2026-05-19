from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from enum import Enum
from datetime import date, datetime
import re


class MediaType(str, Enum):
    MANGA    = "MANGA"
    MANHWA   = "MANHWA"
    MANHUA   = "MANHUA"
    WEBTOON  = "WEBTOON"
    ANIME    = "ANIME"
    MOVIE    = "MOVIE"
    SERIES   = "SERIES"
    DORAMA   = "DORAMA"
    NOVEL    = "NOVEL"


class EmissionStatus(str, Enum):
    AIRING    = "AIRING"
    FINISHED  = "FINISHED"
    UPCOMING  = "UPCOMING"
    CANCELLED = "CANCELLED"
    HIATUS    = "HIATUS"
    UNKNOWN   = "UNKNOWN"


class TrackingStatus(str, Enum):
    PLAN     = "plan_to_watch"
    WATCHING = "watching"
    COMPLETE = "completed"
    ON_HOLD  = "on_hold"
    DROPPED  = "dropped"


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    display_name: Optional[str] = None
    password: str = Field(min_length=8)

    @field_validator('password')
    @classmethod
    def password_complexity(cls, v):
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('La contraseña debe contener al menos una letra')
        if not re.search(r'[0-9]', v):
            raise ValueError('La contraseña debe contener al menos un número')
        return v


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


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
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
    emission_status: Optional[EmissionStatus] = None
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
    rating_label: Optional[str] = "sin_valorar"
    notes: Optional[str] = None
    platform: Optional[str] = None
    started_at: Optional[date] = None
    completed_at: Optional[date] = None
    ep_current: Optional[int] = None
    ep_total: Optional[int] = None


class EntryUpdate(BaseModel):
    status: Optional[TrackingStatus] = None
    progress: Optional[str] = None
    score: Optional[float] = None
    rating_label: Optional[str] = None
    notes: Optional[str] = None
    platform: Optional[str] = None
    started_at: Optional[date] = None
    completed_at: Optional[date] = None
    ep_current: Optional[int] = None
    ep_total: Optional[int] = None


class EntryOut(BaseModel):
    id: int
    user_id: int
    media_id: int
    status: TrackingStatus
    progress: Optional[str]
    score: Optional[float]
    rating_label: Optional[str]
    notes: Optional[str]
    platform: Optional[str]
    started_at: Optional[date]
    completed_at: Optional[date]
    ep_current: Optional[int]
    ep_total: Optional[int]
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
    emission_status: Optional[EmissionStatus] = None
    network: Optional[str] = None
    cast_text: Optional[str] = None


class RatingConfigCreate(BaseModel):
    key: str = Field(min_length=1, max_length=50)
    label: str = Field(min_length=1, max_length=100)
    color: str = Field(default="#888888", pattern=r"^#[0-9A-Fa-f]{6}$")
    sort_order: int = 0


class RatingConfigOut(RatingConfigCreate):
    id: int
    user_id: int


class StatsOut(BaseModel):
    total: int
    by_type: dict
    by_status: dict
    by_rating: dict
    completed: int
    watching: int
    plan: int
    top_genres: list
    monthly_added: list
    score_distribution: list
    time_spent_hours: float


class ProfileUpdate(BaseModel):
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8)

    @field_validator('new_password')
    @classmethod
    def password_complexity(cls, v):
        import re
        if not re.search(r'[A-Za-z]', v):
            raise ValueError('La contraseña debe contener al menos una letra')
        if not re.search(r'[0-9]', v):
            raise ValueError('La contraseña debe contener al menos un número')
        return v
