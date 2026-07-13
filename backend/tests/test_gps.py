# ============================================================
# TESTS — Calcul de distance GPS (formule de Haversine)
# ============================================================

from app.routers.checkin import calculer_distance_metres, RAYON_MAX_METRES


def test_distance_nulle_meme_point():
    """Deux points identiques → distance 0."""
    d = calculer_distance_metres(34.9218, -2.3186, 34.9218, -2.3186)
    assert d == 0.0


def test_distance_connue_berkane_oujda():
    """Berkane → Oujda : ~50 km à vol d'oiseau (tolérance 5 km)."""
    d = calculer_distance_metres(34.9218, -2.3186, 34.6814, -1.9086)
    assert 45_000 < d < 55_000


def test_distance_courte_meme_salle():
    """~30 m de décalage : doit rester dans le rayon autorisé."""
    # 0.00027° de latitude ≈ 30 m
    d = calculer_distance_metres(34.9218, -2.3186, 34.92207, -2.3186)
    assert d < RAYON_MAX_METRES


def test_distance_hors_rayon():
    """~500 m de décalage : doit dépasser le rayon autorisé."""
    # 0.0045° de latitude ≈ 500 m
    d = calculer_distance_metres(34.9218, -2.3186, 34.9263, -2.3186)
    assert d > RAYON_MAX_METRES


def test_distance_symetrique():
    """d(A,B) == d(B,A)."""
    d1 = calculer_distance_metres(34.92, -2.31, 34.93, -2.32)
    d2 = calculer_distance_metres(34.93, -2.32, 34.92, -2.31)
    assert abs(d1 - d2) < 1e-6
