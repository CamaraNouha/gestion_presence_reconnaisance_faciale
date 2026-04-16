import cv2
import numpy as np
import base64
import os

# ── Chemins vers les fichiers .onnx ──────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
YUNET_PATH = os.path.join(BASE_DIR, "models", "yunet.onnx")
SFACE_PATH = os.path.join(BASE_DIR, "models", "sface.onnx")

# ── Seuil de similarité cosinus ───────────────────────────────
# >= 0.363 → même personne (seuil officiel SFace)
SIMILARITY_THRESHOLD = 0.363


class FaceEngine:
    def __init__(self):
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
        print("Modeles YuNet et SFace charges avec succes")

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

    def get_embedding(self, image: np.ndarray) -> np.ndarray:
        """
        Extrait l'embedding facial d'une image OpenCV.
        Retourne un vecteur de 128 nombres ou None si échec.
        """
        # Étape 1 : Détecte le visage avec YuNet
        h, w = image.shape[:2]
        self.detector.setInputSize((w, h))
        _, faces = self.detector.detect(image)

        if faces is None or len(faces) == 0:
            return None

        # Étape 2 : Aligne et recadre le visage détecté
        aligned_face = self.recognizer.alignCrop(image, faces[0])

        # Étape 3 : Extrait l'embedding avec SFace (vecteur 128D)
        embedding = self.recognizer.feature(aligned_face)

        return embedding.flatten()

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