from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from limiter import limiter
from routers import auth_router, media_router, entries_router
from routers import rating_config_router
from routers import import_router

app = FastAPI(title="Nexus API", version="1.0.0")

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://nexus.iamlaura.dev",
        "http://localhost:3500",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(media_router.router)
app.include_router(entries_router.router)
app.include_router(rating_config_router.router)
app.include_router(import_router.router)


@app.get("/health")
def health():
    return {"status": "ok"}
