# ============================================================
# TEST DE CHARGE — Simule N étudiants qui pointent en même temps
#
# Usage :
#   python load_test.py --photo chemin/vers/visage.jpg \
#       --admin-apogee admin --admin-password admin123 \
#       --students 100
#
# Phases :
#   0. Prépare la rafale de 5 images (avec clignement synthétisé)
#      et la valide localement (détection, vivacité, clignement)
#   1. Setup idempotent : prof LTPROF + module LOADTEST +
#      N étudiants LT001..LTxxx (avec photo → embedding)
#   2. N logins simultanés (mesure bcrypt + DB sous charge)
#   3. N pointages simultanés (mesure le pipeline CV complet)
#
# NOTE : tous les étudiants de test partagent la même photo.
# La plupart des pointages finissent donc en 401 « le visage ne
# correspond pas à votre compte » — c'est ATTENDU et sans
# importance : le 401 arrive APRÈS tout le travail lourd
# (décodage x5, détection x5, anti-spoof x10, clignement,
# embedding, requête pgvector). La métrique utile est la latence.
#
# Nettoyage : --cleanup supprime les comptes/module de test.
# ============================================================

import argparse
import base64
import os
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# Import du moteur facial local pour la validation des images
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cv2          # noqa: E402
import numpy as np  # noqa: E402
from app.cv.face_engine import face_engine  # noqa: E402

PREFIX = "LT"           # préfixe apogée des comptes de test
PROF_APOGEE = "LTPROF"
MODULE_CODE = "LOADTEST"
PASSWORD = "loadtest123"
TIMEOUT = 300           # secondes par requête


# ------------------------------------------------------------─
# Phase 0 : préparation des images
# ------------------------------------------------------------─

def build_frames(photo_path: str):
    """
    Construit la rafale de 5 images : 4 normales + 1 « clignement »
    (yeux recouverts de couleur peau) pour passer check_blink.
    Retourne (frames_base64, photo_jpeg_bytes).
    """
    img = cv2.imread(photo_path)
    if img is None:
        sys.exit(f"ERREUR : impossible de lire {photo_path}")

    # Redimensionne (max 720 px de large) pour des payloads sains
    h, w = img.shape[:2]
    if w > 720:
        scale = 720 / w
        img = cv2.resize(img, (720, int(h * scale)))

    face = face_engine.detect_face(img)
    if face is None:
        sys.exit("ERREUR : aucun visage détecté dans la photo fournie")

    # Image « clignement » : recouvre les 2 yeux avec la couleur
    # de peau échantillonnée sous les yeux. Le flou de fusion est
    # appliqué UNIQUEMENT autour des yeux, pour que la zone du nez
    # (référence anti-mouvement de check_blink) reste identique.
    blink_img = img.copy()
    box_w = face[2]
    half_w, half_h = int(box_w * 0.16), int(box_w * 0.10)
    for ex, ey in [(face[4], face[5]), (face[6], face[7])]:
        ex, ey = int(ex), int(ey)
        # Échantillon de peau juste sous l'œil
        sy = min(img.shape[0] - 2, ey + int(half_h * 2.2))
        skin = np.median(
            img[sy:sy + 6, max(0, ex - 8):ex + 8].reshape(-1, 3), axis=0
        )
        cv2.ellipse(
            blink_img, (ex, ey), (half_w, half_h), 0, 0, 360,
            tuple(int(c) for c in skin), -1
        )
        # Trait sombre horizontal = pli de la paupière fermée
        cv2.line(
            blink_img, (ex - half_w // 2, ey), (ex + half_w // 2, ey),
            tuple(int(c * 0.55) for c in skin), 2
        )
        # Flou local pour fondre les bords de l'ellipse
        y1 = max(0, ey - half_h * 2)
        y2 = min(blink_img.shape[0], ey + half_h * 2)
        x1 = max(0, ex - half_w * 2)
        x2 = min(blink_img.shape[1], ex + half_w * 2)
        blink_img[y1:y2, x1:x2] = cv2.GaussianBlur(
            blink_img[y1:y2, x1:x2], (7, 7), 0
        )

    def to_b64(image):
        ok, buf = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 85])
        return base64.b64encode(buf).decode()

    frames = [to_b64(img), to_b64(img), to_b64(blink_img),
              to_b64(img), to_b64(img)]

    # ── Validation locale (mêmes algos que le serveur) --------
    frames_faces = []
    for fb in frames:
        im = face_engine.decode_base64_image(fb)
        f = face_engine.detect_face(im)
        if f is not None:
            frames_faces.append((im, f))
    if len(frames_faces) < 3:
        sys.exit("ERREUR : visage perdu dans la rafale générée")

    scores = sorted(face_engine.check_liveness(im, f)[1]
                    for im, f in frames_faces)
    live = scores[len(scores) // 2]
    blinked, blink = face_engine.check_blink(frames_faces)
    print(f"[VALIDATION LOCALE] vivacite(mediane)={live:.3f} "
          f"blink={blink:.2f} ({'OK' if blinked else 'ECHEC'})")
    if live < 0.5 or not blinked:
        sys.exit("ERREUR : la rafale ne passerait pas les contrôles. "
                 "Utilisez une photo de meilleure qualité (vrai selfie).")

    ok, photo_buf = cv2.imencode(".jpg", img,
                                 [cv2.IMWRITE_JPEG_QUALITY, 90])
    return frames, photo_buf.tobytes()


# ------------------------------------------------------------─
# Helpers API
# ------------------------------------------------------------─

def login(api, apogee, password):
    r = requests.post(f"{api}/auth/login", json={
        "apogee": apogee, "mot_de_passe": password,
    }, timeout=TIMEOUT)
    r.raise_for_status()
    return r.json()["access_token"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------─
# Phase 1 : setup des données de test (idempotent)
# ------------------------------------------------------------─

def setup(api, admin_token, n_students, photo_bytes):
    h = auth(admin_token)

    users = requests.get(f"{api}/admin/users", headers=h,
                         timeout=TIMEOUT).json()
    by_apogee = {u["apogee"]: u for u in users}

    # ── Professeur de test ------------------------------------
    if PROF_APOGEE in by_apogee:
        prof_id = by_apogee[PROF_APOGEE]["id"]
    else:
        r = requests.post(f"{api}/admin/users", headers=h, data={
            "nom": "LoadTest", "prenom": "Prof",
            "email": "ltprof@loadtest.local",
            "apogee": PROF_APOGEE, "mot_de_passe": PASSWORD,
            "role": "professeur",
        }, timeout=TIMEOUT)
        r.raise_for_status()
        prof_id = r.json()["id"]
    print(f"Prof de test : {PROF_APOGEE}")

    # ── Module de test ----------------------------------------
    modules = requests.get(f"{api}/admin/modules", headers=h,
                           timeout=TIMEOUT).json()
    module = next((m for m in modules if m["code"] == MODULE_CODE), None)
    if module is None:
        r = requests.post(f"{api}/admin/modules", headers=h, json={
            "nom": "Module Test de Charge", "code": MODULE_CODE,
            "semestre": "S1", "filiere": "TEST",
            "professeur_id": prof_id,
        }, timeout=TIMEOUT)
        r.raise_for_status()
        module = r.json()
    module_id = module["id"]
    print(f"Module de test : {MODULE_CODE}")

    # ── Étudiants inscrits au module (pour éviter les doublons) ──
    enrolled = requests.get(
        f"{api}/admin/modules/{module_id}/students",
        headers=h, timeout=TIMEOUT,
    ).json()
    enrolled_ids = {s["id"] for s in enrolled}

    apogees = [f"{PREFIX}{i:03d}" for i in range(1, n_students + 1)]

    def ensure_student(apogee):
        if apogee in by_apogee:
            sid = by_apogee[apogee]["id"]
        else:
            r = requests.post(f"{api}/admin/users", headers=h, data={
                "nom": "LoadTest", "prenom": apogee,
                "email": f"{apogee.lower()}@loadtest.local",
                "apogee": apogee, "mot_de_passe": PASSWORD,
                "role": "etudiant",
            }, files={
                "photo": ("face.jpg", photo_bytes, "image/jpeg"),
            }, timeout=TIMEOUT)
            r.raise_for_status()
            sid = r.json()["id"]
        if sid not in enrolled_ids:
            requests.post(
                f"{api}/admin/modules/{module_id}/students/{sid}",
                headers=h, timeout=TIMEOUT,
            )
        return apogee

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=8) as ex:
        done = 0
        for _ in as_completed([ex.submit(ensure_student, a)
                               for a in apogees]):
            done += 1
            if done % 20 == 0:
                print(f"  ... {done}/{n_students} étudiants prêts")
    print(f"Setup étudiants : {time.time() - t0:.1f}s")
    return module_id


# ------------------------------------------------------------─
# Statistiques
# ------------------------------------------------------------─

def report(name, results):
    """results = liste de (status_code|None, latence_s, detail)"""
    lat = sorted(r[1] for r in results)
    codes = {}
    for status, _, _ in results:
        codes[status] = codes.get(status, 0) + 1

    def pct(p):
        return lat[min(len(lat) - 1, int(len(lat) * p))]

    print(f"\n---- {name} ----")
    print(f"  Requêtes : {len(results)}   Codes HTTP : {codes}")
    print(f"  Latence  : min={lat[0]:.2f}s  p50={pct(0.50):.2f}s  "
          f"p90={pct(0.90):.2f}s  p95={pct(0.95):.2f}s  "
          f"max={lat[-1]:.2f}s")
    print(f"  Moyenne  : {statistics.mean(lat):.2f}s")
    errors = [r for r in results if r[0] is None]
    if errors:
        print(f"  !! ERREURS RESEAU/TIMEOUT : {len(errors)} "
              f"(ex: {errors[0][2][:120]})")


# ------------------------------------------------------------─
# Main
# ------------------------------------------------------------─

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--api", default="http://localhost:8000")
    ap.add_argument("--photo", required=True,
                    help="Photo d'un visage (selfie) pour le test")
    ap.add_argument("--admin-apogee", required=True)
    ap.add_argument("--admin-password", required=True)
    ap.add_argument("--students", type=int, default=100)
    ap.add_argument("--cleanup", action="store_true",
                    help="Supprime les données de test puis quitte")
    args = ap.parse_args()

    admin_token = login(args.api, args.admin_apogee, args.admin_password)

    # ── Nettoyage --------------------------------------------─
    if args.cleanup:
        h = auth(admin_token)
        users = requests.get(f"{args.api}/admin/users", headers=h,
                             timeout=TIMEOUT).json()
        victims = [u for u in users
                   if u["apogee"].startswith(PREFIX)]
        for u in victims:
            requests.delete(f"{args.api}/admin/users/{u['id']}",
                            headers=h, timeout=TIMEOUT)
        modules = requests.get(f"{args.api}/admin/modules", headers=h,
                               timeout=TIMEOUT).json()
        for m in modules:
            if m["code"] == MODULE_CODE:
                requests.delete(f"{args.api}/admin/modules/{m['id']}",
                                headers=h, timeout=TIMEOUT)
        print(f"Nettoyage : {len(victims)} comptes + module supprimés")
        return

    # ── Phase 0 : images ------------------------------------──
    frames, photo_bytes = build_frames(args.photo)
    payload_mb = sum(len(f) for f in frames) / 1e6
    print(f"Rafale prête : 5 images, {payload_mb:.1f} Mo par pointage")

    # ── Phase 1 : setup ------------------------------------───
    module_id = setup(args.api, admin_token, args.students, photo_bytes)

    # ── Phase 2 : logins simultanés ------------------------───
    apogees = [f"{PREFIX}{i:03d}" for i in range(1, args.students + 1)]
    tokens = {}

    def do_login(apogee):
        t0 = time.time()
        try:
            r = requests.post(f"{args.api}/auth/login", json={
                "apogee": apogee, "mot_de_passe": PASSWORD,
            }, timeout=TIMEOUT)
            if r.status_code == 200:
                tokens[apogee] = r.json()["access_token"]
            return (r.status_code, time.time() - t0, r.text[:120])
        except Exception as e:
            return (None, time.time() - t0, str(e))

    print(f"\n>>> {args.students} LOGINS SIMULTANÉS...")
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=args.students) as ex:
        results = [f.result() for f in
                   [ex.submit(do_login, a) for a in apogees]]
    wall_login = time.time() - t0
    report(f"LOGINS ({wall_login:.1f}s au total, "
           f"{len(results)/wall_login:.1f} req/s)", results)

    if len(tokens) < args.students:
        print(f"!! Seulement {len(tokens)} logins réussis")

    # ── Ouvre la session (prof) ----------------------------───
    prof_token = login(args.api, PROF_APOGEE, PASSWORD)
    r = requests.post(f"{args.api}/sessions/open", headers=auth(prof_token),
                      json={"module_id": module_id, "delai_minutes": 15},
                      timeout=TIMEOUT)
    if r.status_code == 400 and "déjà ouverte" in r.text:
        active = requests.get(f"{args.api}/sessions/active",
                              headers=auth(prof_token),
                              timeout=TIMEOUT).json()
        session_id = next(s["id"] for s in active
                          if s["module_id"] == module_id)
    else:
        r.raise_for_status()
        session_id = r.json()["id"]
    print(f"\nSession ouverte : {session_id}")

    # ── Warmup (1 pointage hors mesure) --------------------───
    def do_checkin(apogee):
        t0 = time.time()
        try:
            r = requests.post(f"{args.api}/checkin/",
                              headers=auth(tokens[apogee]),
                              json={"session_id": session_id,
                                    "frames_base64": frames},
                              timeout=TIMEOUT)
            return (r.status_code, time.time() - t0, r.text[:120])
        except Exception as e:
            return (None, time.time() - t0, str(e))

    first = next(iter(tokens))
    warm = do_checkin(first)
    print(f"Warmup : HTTP {warm[0]} en {warm[1]:.2f}s — {warm[2][:80]}")

    # ── Phase 3 : pointages simultanés ------------------------
    print(f"\n>>> {len(tokens)} POINTAGES SIMULTANÉS "
          f"(pipeline CV complet)...")
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=len(tokens)) as ex:
        results = [f.result() for f in
                   [ex.submit(do_checkin, a) for a in tokens]]
    wall = time.time() - t0
    report(f"POINTAGES ({wall:.1f}s au total, "
           f"{len(results)/wall:.2f} req/s)", results)

    print("\nRappel : les 401 « ne correspond pas à votre compte » sont "
          "ATTENDUS (photo partagée) — le pipeline complet a bien "
          "tourné. Les métriques importantes : latences et absence "
          "d'erreurs réseau/timeout/500.")
    print("Nettoyage des données de test : python load_test.py "
          "--cleanup --admin-apogee ... --admin-password ... "
          "--photo x.jpg")

    # Ferme la session pour laisser l'environnement propre
    requests.post(f"{args.api}/sessions/{session_id}/close",
                  headers=auth(prof_token), timeout=TIMEOUT)
    print("Session fermée.")


if __name__ == "__main__":
    main()
