# ============================================================
# TESTS — Hachage de mot de passe et tokens JWT
# ============================================================

from jose import jwt
import pytest

from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token,
    SECRET_KEY, ALGORITHM,
)


def test_hash_et_verify_password():
    h = hash_password("motdepasse123")
    assert h != "motdepasse123"          # jamais en clair
    assert verify_password("motdepasse123", h)
    assert not verify_password("mauvais", h)


def test_hashs_differents_pour_meme_mdp():
    """Le sel bcrypt doit rendre chaque hash unique."""
    assert hash_password("abc") != hash_password("abc")


def test_access_token_contenu():
    token = create_access_token({"sub": "user-123", "role": "etudiant"})
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["role"] == "etudiant"
    assert payload["type"] == "access"
    assert "exp" in payload


def test_refresh_token_contenu():
    token, jti, expire = create_refresh_token("user-456")
    payload = decode_token(token)
    assert payload["sub"] == "user-456"
    assert payload["type"] == "refresh"
    assert payload["jti"] == jti
    assert len(jti) == 36                # UUID


def test_token_signature_invalide_rejete():
    """Un token signé avec une autre clé doit être rejeté."""
    faux = jwt.encode({"sub": "pirate"}, "autre-cle", algorithm=ALGORITHM)
    with pytest.raises(Exception):
        decode_token(faux)


def test_token_falsifie_rejete():
    """Un token modifié après signature doit être rejeté."""
    token = create_access_token({"sub": "user-123"})
    falsifie = token[:-4] + "XXXX"
    with pytest.raises(Exception):
        decode_token(falsifie)
