# ============================================================
# TESTS — Moteur facial : détection, vivacité, clignement
# Utilise les vrais modèles ONNX (présents dans le repo).
# ============================================================

import numpy as np
import pytest

from app.cv.face_engine import face_engine, LIVENESS_THRESHOLD, BLINK_THRESHOLD


def _fausse_bbox():
    """Bbox + landmarks factices au format YuNet (15 valeurs)."""
    face = np.zeros(15)
    face[:4] = [200, 150, 180, 220]              # x, y, w, h
    face[4:10] = [260, 220, 340, 220, 300, 270]  # yeux + nez
    return face


def test_deux_modeles_antispoof_charges():
    """L'ensemble anti-spoofing doit contenir les 2 modèles."""
    assert len(face_engine.antispoof_models) == 2


def test_pas_de_visage_dans_du_bruit():
    img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    assert face_engine.detect_face(img) is None


def test_image_invalide_retourne_none():
    assert face_engine.decode_base64_image("pas-du-base64!!!") is None


def test_liveness_retourne_score_valide():
    img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    is_real, score = face_engine.check_liveness(img, _fausse_bbox())
    assert isinstance(is_real, bool) or is_real in (True, False)
    assert 0.0 <= score <= 1.0


def test_blink_rejette_rafale_statique():
    """5 images identiques (= photo rigide) → pas de clignement."""
    img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    frames = [(img, _fausse_bbox())] * 5
    blinked, score = face_engine.check_blink(frames)
    assert not blinked
    assert score < BLINK_THRESHOLD


def test_blink_detecte_changement_yeux():
    """Yeux modifiés sur 1 image, nez stable → clignement détecté."""
    img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    face = _fausse_bbox()
    img_blink = img.copy()
    # Altère uniquement la zone des yeux (y≈220, x≈260 et 340)
    img_blink[204:236, 228:372] = np.random.randint(
        0, 255, (32, 144, 3), dtype=np.uint8
    )
    frames = [(img, face)] * 2 + [(img_blink, face)] + [(img, face)] * 2
    blinked, score = face_engine.check_blink(frames)
    assert blinked
    assert score >= BLINK_THRESHOLD


def test_blink_refuse_moins_de_3_images():
    img = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    blinked, score = face_engine.check_blink([(img, _fausse_bbox())] * 2)
    assert not blinked
