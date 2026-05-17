from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth_router, media_router, entries_router

app = FastAPI(title="Nexus API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(media_router.router)
app.include_router(entries_router.router)


@app.get("/health")
def health():
    return {"status": "ok"}
