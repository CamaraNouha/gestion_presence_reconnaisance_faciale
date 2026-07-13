import cv2
import numpy as np
import base64
import os
import threading

# ── Chemins vers les fichiers .onnx ──────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
YUNET_PATH = os.path.join(BASE_DIR, "models", "yunet.onnx")
SFACE_PATH = os.path.join(BASE_DIR, "models", "sface.onnx")
# ── Seuil de similarité cosinus ───────────────────────────────
# >= 0.363 → même personne (seuil officiel SFace)
SIMILARITY_THRESHOLD = 0.363

# ── Anti-spoofing (détection de vivacité) ─────────────────────
# Ensemble de 2 modèles (Silent-Face-Anti-Spoofing, Apache-2.0),
# comme le démo officiel : chaque modèle analyse un crop du visage
# à son propre facteur d'agrandissement, et les probabilités sont
# moyennées. Sortie = [fake, real, fake] ; classe 1 = vrai visage.
ANTISPOOF_MODELS = [
    # (fichier ONNX, facteur de crop)
    (os.path.join(BASE_DIR, "models", "anti_spoof_2.7_80x80.onnx"), 2.7),
    (os.path.join(BASE_DIR, "models", "anti_spoof_4.0_80x80.onnx"), 4.0),
]
LIVENESS_THRESHOLD = float(os.getenv("LIVENESS_THRESHOLD", "0.5"))

# ── Détection de clignement (multi-images) ────────────────────
# Sur une rafale d'images, on mesure la variation des zones des
# yeux par rapport à une zone de référence (le nez). Un clignement
# fait varier les yeux beaucoup plus que le nez → ratio élevé.
# Une photo rigide varie uniformément → ratio proche de 1.
BLINK_THRESHOLD = float(os.getenv("BLINK_THRESHOLD", "2.0"))


class FaceEngine:
    def __init__(self):
        # Les objets OpenCV (FaceDetectorYN, FaceRecognizerSF,
        # dnn.Net) ne sont PAS thread-safe : sous requêtes
        # concurrentes ils se corrompent (détections perdues,
        # scores aléatoires — constaté en test de charge).
        # Ce verrou sérialise l'accès aux modèles dans le process ;
        # le parallélisme vient des workers uvicorn (1 moteur chacun).
        self._lock = threading.Lock()
        # Charge YuNet — détection de visage
        self.detector = cv2.FaceDetectorYN.create(
            model=YUNET_PATH,
            config="",
            input_size=(320, 320),
            score_threshold=0.9,
            nms_threshold=0.3,
            top_k=1
        )
        # Charge SFace — extraction d'embedding
        self.recognizer = cv2.FaceRecognizerSF.create(
            model=SFACE_PATH,
            config=""
        )
        # Charge l'ensemble anti-spoofing (vivacité)
        # Chaque entrée = (réseau, facteur de crop). Les fichiers
        # manquants sont ignorés (fonctionne avec 1 ou 2 modèles).
        self.antispoof_models = []
        for path, scale in ANTISPOOF_MODELS:
            if os.path.exists(path):
                net = cv2.dnn.readNetFromONNX(path)
                self.antispoof_models.append((net, scale))
            else:
                print(f"⚠️  Modele anti-spoof absent : {path}")
        print(
            f"Modeles YuNet, SFace et {len(self.antispoof_models)} "
            f"modele(s) anti-spoofing charges avec succes"
        )

    def decode_base64_image(self, base64_string: str) -> np.ndarray:
        """
        Convertit une image base64 (envoyée par Flutter)
        en image OpenCV (tableau NumPy BGR).
        """
        try:
            # Supprime le préfixe data:image/jpeg;base64,
            if "," in base64_string:
                base64_string = base64_string.split(",")[1]

            # Décode base64 → bytes → tableau NumPy → image OpenCV
            img_bytes = base64.b64decode(base64_string)
            img_array = np.frombuffer(img_bytes, dtype=np.uint8)
            image = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
            return image
        except Exception as e:
            print(f"Erreur décodage image: {e}")
            return None

    def detect_face(self, image: np.ndarray):
        """
        Détecte le visage principal avec YuNet.
        Retourne la ligne de détection (bbox + landmarks) ou None.
        """
        with self._lock:
            h, w = image.shape[:2]
            self.detector.setInputSize((w, h))
            _, faces = self.detector.detect(image)

        if faces is None or len(faces) == 0:
            return None
        return faces[0]

    def get_embedding_for_face(
        self,
        image: np.ndarray,
        face: np.ndarray
    ) -> np.ndarray:
        """
        Extrait l'embedding d'un visage déjà détecté (évite une
        seconde détection quand la bbox est déjà connue).
        """
        with self._lock:
            # Aligne et recadre le visage détecté
            aligned_face = self.recognizer.alignCrop(image, face)

            # Extrait l'embedding avec SFace (vecteur 128D)
            embedding = self.recognizer.feature(aligned_face)

        return embedding.flatten()

    def get_embedding(self, image: np.ndarray) -> np.ndarray:
        """
        Extrait l'embedding facial d'une image OpenCV.
        Retourne un vecteur de 128 nombres ou None si échec.
        """
        face = self.detect_face(image)
        if face is None:
            return None
        return self.get_embedding_for_face(image, face)

    def _crop_scaled(
        self,
        image: np.ndarray,
        face: np.ndarray,
        crop_scale: float
    ) -> np.ndarray:
        """
        Recadre le visage avec un facteur d'agrandissement donné
        autour de la bbox (protocole officiel Silent-Face) puis
        redimensionne à 80x80 pour le modèle anti-spoofing.
        """
        src_h, src_w = image.shape[:2]
        x, y, box_w, box_h = face[0], face[1], face[2], face[3]

        # Le facteur est réduit si la bbox élargie dépasse l'image
        scale = min(
            (src_h - 1) / box_h,
            min((src_w - 1) / box_w, crop_scale)
        )
        new_w = box_w * scale
        new_h = box_h * scale
        center_x = x + box_w / 2
        center_y = y + box_h / 2

        left = center_x - new_w / 2
        top = center_y - new_h / 2
        right = center_x + new_w / 2
        bottom = center_y + new_h / 2

        # Décale le cadre s'il sort de l'image
        if left < 0:
            right -= left
            left = 0
        if top < 0:
            bottom -= top
            top = 0
        if right > src_w - 1:
            left -= right - (src_w - 1)
            right = src_w - 1
        if bottom > src_h - 1:
            top -= bottom - (src_h - 1)
            bottom = src_h - 1

        crop = image[int(top):int(bottom) + 1, int(left):int(right) + 1]
        return cv2.resize(crop, (80, 80))

    def check_liveness(
        self,
        image: np.ndarray,
        face: np.ndarray
    ) -> tuple:
        """
        Vérifie que le visage est vivant (pas une photo/écran).
        Chaque modèle de l'ensemble vote avec son propre crop,
        les probabilités sont moyennées (protocole officiel).
        Retourne (is_real: bool, score_real: float).
        """
        if not self.antispoof_models:
            # Aucun modèle disponible → on laisse passer (dégradé)
            return True, 1.0

        total_probs = np.zeros(3, dtype=np.float64)
        for net, crop_scale in self.antispoof_models:
            crop = self._crop_scaled(image, face, crop_scale)

            # Le modèle attend des pixels bruts 0-255, BGR, en 80x80
            blob = cv2.dnn.blobFromImage(
                crop,
                scalefactor=1.0,
                size=(80, 80),
                mean=(0, 0, 0),
                swapRB=False,
            )
            with self._lock:
                net.setInput(blob)
                total_probs += net.forward().flatten()

        probs = total_probs / len(self.antispoof_models)

        # probs = [fake, real, fake] → classe 1 = vrai visage
        score_real = float(probs[1])
        return score_real >= LIVENESS_THRESHOLD, score_real

    # ──────────────────────────────────────────────────────────
    # Détection de clignement sur une rafale d'images
    # ──────────────────────────────────────────────────────────

    def _extract_patch(
        self,
        image: np.ndarray,
        cx: float,
        cy: float,
        half_w: float,
        half_h: float
    ) -> np.ndarray:
        """
        Extrait un patch normalisé (32x24, niveaux de gris,
        moyenne 0 / écart-type 1) centré sur un landmark.
        La normalisation annule les variations d'exposition.
        """
        h, w = image.shape[:2]
        x1 = max(0, int(cx - half_w))
        y1 = max(0, int(cy - half_h))
        x2 = min(w, int(cx + half_w))
        y2 = min(h, int(cy + half_h))
        if x2 - x1 < 4 or y2 - y1 < 4:
            return None
        patch = cv2.cvtColor(image[y1:y2, x1:x2], cv2.COLOR_BGR2GRAY)
        patch = cv2.resize(patch, (32, 24)).astype(np.float32)
        std = patch.std()
        if std < 1e-6:
            return None
        return (patch - patch.mean()) / std

    def check_blink(self, frames_faces: list) -> tuple:
        """
        Détecte un clignement d'yeux sur une rafale.

        frames_faces : liste de (image, face) où face est la ligne
        YuNet (bbox + landmarks : yeux, nez, bouche).

        Principe : pour chaque image, on extrait les patchs des
        2 yeux et du nez, alignés sur les landmarks (ce qui annule
        le mouvement global de la main). On compare chaque patch à
        sa médiane temporelle. Un clignement = les yeux s'écartent
        fortement de leur médiane pendant que le nez reste stable.

        Retourne (blinked: bool, blink_score: float).
        """
        eyes_l, eyes_r, noses = [], [], []

        for image, face in frames_faces:
            box_w = face[2]
            # Landmarks YuNet : [4,5]=œil droit, [6,7]=œil gauche,
            # [8,9]=nez
            half_w = box_w * 0.12
            half_h = box_w * 0.08
            p_re = self._extract_patch(image, face[4], face[5], half_w, half_h)
            p_le = self._extract_patch(image, face[6], face[7], half_w, half_h)
            p_no = self._extract_patch(image, face[8], face[9], half_w, half_h)
            if p_re is None or p_le is None or p_no is None:
                continue
            eyes_r.append(p_re)
            eyes_l.append(p_le)
            noses.append(p_no)

        if len(noses) < 3:
            # Pas assez d'images exploitables pour juger
            return False, 0.0

        # Référence temporelle : médiane pixel à pixel
        ref_r = np.median(np.stack(eyes_r), axis=0)
        ref_l = np.median(np.stack(eyes_l), axis=0)
        ref_n = np.median(np.stack(noses), axis=0)

        best_ratio = 0.0
        nose_diffs = [
            float(np.abs(n - ref_n).mean()) for n in noses
        ]
        # Plancher de bruit : évite la division par ~0 quand le
        # téléphone est parfaitement stable
        floor = max(0.05, 0.5 * float(np.median(nose_diffs)))

        for i in range(len(noses)):
            eye_diff = (
                float(np.abs(eyes_r[i] - ref_r).mean()) +
                float(np.abs(eyes_l[i] - ref_l).mean())
            ) / 2.0
            ratio = eye_diff / (nose_diffs[i] + floor)
            best_ratio = max(best_ratio, ratio)

        return best_ratio >= BLINK_THRESHOLD, best_ratio

    def get_embedding_from_base64(self, base64_string: str) -> np.ndarray:
        """
        Méthode principale appelée depuis l'API.
        Reçoit une image base64 et retourne l'embedding.
        """
        # Convertit base64 → image OpenCV
        image = self.decode_base64_image(base64_string)
        if image is None:
            return None

        # Extrait et retourne l'embedding
        return self.get_embedding(image)

    def compare_embeddings(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray
    ) -> float:
        """
        Compare 2 embeddings avec la similarité cosinus.
        Retourne un score entre 0.0 et 1.0.
        Score >= 0.363 → même personne.
        """

        #Aplatit les vecteurs en 1D
        e1 = embedding1.flatten()
        e2 = embedding2.flatten()

        #Calcule les normes (||A|| et ||B||)
        dot_product = np.dot(e1, e2)
        norm1 = np.linalg.norm(e1)
        norm2 = np.linalg.norm(e2)
        if norm1 == 0 or norm2 == 0:
            return 0.0
        #Calcule la similarité cosinus
        score = dot_product / (norm1 * norm2)
        return float(score)

    def is_same_person(
        self,
        embedding1: np.ndarray,
        embedding2: np.ndarray
    ) -> tuple:
        """
        Retourne (True/False, score).
        True = même personne, False = personnes différentes.
        """
        score = self.compare_embeddings(embedding1, embedding2)
        return score >= SIMILARITY_THRESHOLD, score


# ── Instance globale ──────────────────────────────────────────
# Créée une seule fois au démarrage pour ne pas
# recharger les modèles à chaque requête
face_engine = FaceEngine()