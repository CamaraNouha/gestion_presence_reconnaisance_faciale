from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import auth,admin,sessions,users,checkin,export

app=FastAPI(
    title="ENIAD Présence API",
    description="Systeme de gestion de présence par Reconnaissance Faciale pour l'ENIAD",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
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