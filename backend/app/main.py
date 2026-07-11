import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth,admin,sessions,users,checkin,export
from app.services.firebase_service import init_firebase


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialise Firebase au démarrage
    init_firebase()
    yield


app=FastAPI(
    title="ENIAD Présence API",
    description="Systeme de gestion de présence par Reconnaissance Faciale pour l'ENIAD",
    version="1.0.0",
    lifespan=lifespan,
)

# Origines autorisées (CORS). Le client est une app mobile qui
# s'authentifie par Bearer token (pas de cookies) → allow_credentials
# reste à False, ce qui rend l'usage de "*" valide et sûr.
# Restreindre via la variable d'env CORS_ORIGINS (séparée par des
# virgules) si un client web est ajouté plus tard.
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(sessions.router)
app.include_router(users.router)
app.include_router(checkin.router)
app.include_router(export.router)
@app.get("/")
def root():
    return {"message":"ENIAD API is running"}
@app.get("/health")
def health():
    return {"status": "ok"}