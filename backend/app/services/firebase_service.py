# ============================================================
# FIREBASE SERVICE — Envoi de notifications push
#
# Firebase Cloud Messaging (FCM) permet d'envoyer des
# notifications push aux appareils Android et iOS.
#
# On utilise le système de TOPICS :
# Chaque module a un topic = "module_UUID"
# Tous les étudiants inscrits s'abonnent à ce topic
# Quand le prof ouvre une session → on envoie au topic
# ============================================================

import firebase_admin
from firebase_admin import credentials, messaging
import os

# Chemin vers le fichier de credentials Firebase
CREDENTIALS_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    '..', 'firebase_credentials.json'
)

# Initialise Firebase une seule fois au démarrage
def init_firebase():
    """
    Initialise l'application Firebase Admin.
    Appelé une seule fois au démarrage du serveur.
    """
    try:
        # Vérifie si déjà initialisé
        firebase_admin.get_app()
        print("Firebase déjà initialisé")
    except ValueError:
        # Initialise avec les credentials
        if os.path.exists(CREDENTIALS_PATH):
            cred = credentials.Certificate(CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            print("Firebase initialisé avec succès")
        else:
            print("Warning: firebase_credentials.json introuvable")
            print("Les notifications push seront désactivées")


async def send_session_notification(
    module_id: str,
    module_nom: str,
    prof_nom: str,
    session_id: str,
    delai_minutes: int
):
    """
    Envoie une notification push à tous les étudiants
    inscrits à un module quand le prof ouvre une session.

    Utilise les Topics FCM :
    - Topic = "module_" + module_id
    - Tous les étudiants du module sont abonnés à ce topic
    - Un seul appel envoie la notification à tous

    Args:
        module_id      : UUID du module
        module_nom     : Nom du module (ex: Algorithmique)
        prof_nom       : Nom du professeur
        session_id     : UUID de la session ouverte
        delai_minutes  : Délai de pointage en minutes
    """

    try:
        # Nom du topic = module_UUID
        # Les espaces et caractères spéciaux ne sont pas autorisés
        topic = f"module_{module_id.replace('-', '_')}"

        # Crée le message FCM
        message = messaging.Message(
            # ── Notification visible ──────────────────────
            notification=messaging.Notification(
                title=f"Session ouverte — {module_nom}",
                body=f"{prof_nom} a ouvert une session. "
                     f"Vous avez {delai_minutes} minutes pour pointer."
            ),

            # ── Données supplémentaires (invisibles) ──────
            # Flutter les reçoit même si l'app est fermée
            data={
                "type": "session_ouverte",
                "session_id": session_id,
                "module_id": module_id,
                "module_nom": module_nom,
                "delai_minutes": str(delai_minutes),
            },

            # ── Configuration Android ──────────────────────
            android=messaging.AndroidConfig(
                priority="high",  # Notification prioritaire
                notification=messaging.AndroidNotification(
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    color="#185FA5",  # Couleur bleue ENIADE
                )
            ),

            # ── Envoi au topic du module ───────────────────
            topic=topic,
        )

        # Envoie la notification
        response = messaging.send(message)
        print(f"Notification envoyée au topic {topic}: {response}")
        return True

    except Exception as e:
        print(f"Erreur envoi notification FCM: {e}")
        return False


async def send_session_closed_notification(
    module_id: str,
    module_nom: str
):
    """
    Notifie les étudiants que la session est fermée.
    """
    try:
        topic = f"module_{module_id.replace('-', '_')}"

        message = messaging.Message(
            notification=messaging.Notification(
                title=f"Session fermée — {module_nom}",
                body="La session de présence est maintenant fermée."
            ),
            data={
                "type": "session_fermee",
                "module_id": module_id,
            },
            topic=topic,
        )

        response = messaging.send(message)
        print(f"Notification fermeture envoyée: {response}")
        return True

    except Exception as e:
        print(f"Erreur notification fermeture: {e}")
        return False