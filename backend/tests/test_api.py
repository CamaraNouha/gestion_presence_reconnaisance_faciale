# ============================================================
# TESTS — Endpoints de base de l'API (sans base de données)
# ============================================================

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root():
    r = client.get("/")
    assert r.status_code == 200
    assert "ENIAD" in r.json()["message"]


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_endpoint_protege_sans_token():
    """Sans token JWT → 403 (HTTPBearer refuse l'accès)."""
    r = client.get("/users/me")
    assert r.status_code in (401, 403)


def test_endpoint_protege_token_invalide():
    r = client.get("/users/me", headers={
        "Authorization": "Bearer token-bidon"
    })
    assert r.status_code == 401
