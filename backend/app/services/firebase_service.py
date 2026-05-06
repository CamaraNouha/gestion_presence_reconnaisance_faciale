# ============================================================
# FIREBASE SERVICE — Envoi de notifications push
#
# Système de TOPICS FCM :
#  - module_<UUID>     → tous les étudiants inscrits au module
#  - prof_<UUID>       → notifications personnelles du prof
# ============================================================

import firebase_admin
from firebase_admin import credentials, messaging
import os

# Chemin vers le fichier de credentials Firebase
CREDENTIALS_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    '..', 'firebase_credentials.json'
)


def init_firebase():
    """
    Initialise l'application Firebase Admin.
    Appelé une seule fois au démarrage du serveur.
    """
    try:
        firebase_admin.get_app()
        print("✅ Firebase déjà initialisé")
    except ValueError:
        if os.path.exists(CREDENTIALS_PATH):
            cred = credentials.Certificate(CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase initialisé avec succès")
        else:
            print(f"⚠️  Warning: {CREDENTIALS_PATH} introuvable")
            print("⚠️  Les notifications push seront désactivées")


# ─────────────────────────────────────────────────────────────
# ÉTUDIANTS — Session ouverte par le prof
# ─────────────────────────────────────────────────────────────

async def send_session_notification(
    module_id: str,
    module_nom: str,
    prof_nom: str,
    session_id: str,
    delai_minutes: int
):
    """
    Notifie tous les étudiants inscrits qu'une session est ouverte.
    Envoie au topic du module : module_<UUID>
    """
    try:
        topic = f"module_{module_id.replace('-', '_')}"

        message = messaging.Message(
            notification=messaging.Notification(
                title=f"📢 Session ouverte — {module_nom}",
                body=f"{prof_nom} a ouvert une session. "
                     f"Vous avez {delai_minutes} minutes pour pointer."
            ),
            data={
                "type": "session_ouverte",
                "session_id": session_id,
                "module_id": module_id,
                "module_nom": module_nom,
                "delai_minutes": str(delai_minutes),
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    color="#C26B4F",  # Couleur ENIAD
                    channel_id="eniad_sessions",
                )
            ),
            topic=topic,
        )

        response = messaging.send(message)
        print(f"✅ Notification session ouverte → topic {topic}: {response}")
        return True

    except Exception as e:
        print(f"❌ Erreur notification session ouverte: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# ÉTUDIANTS — Session fermée par le prof
# ─────────────────────────────────────────────────────────────

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
                title=f"🔒 Session fermée — {module_nom}",
                body="La session de présence est maintenant fermée."
            ),
            data={
                "type": "session_fermee",
                "module_id": module_id,
            },
            android=messaging.AndroidConfig(
                priority="normal",
                notification=messaging.AndroidNotification(
                    sound="default",
                    color="#888888",
                    channel_id="eniad_sessions",
                )
            ),
            topic=topic,
        )

        response = messaging.send(message)
        print(f"✅ Notification session fermée → topic {topic}: {response}")
        return True

    except Exception as e:
        print(f"❌ Erreur notification fermeture: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# PROF — Statistiques après fermeture de session
# ─────────────────────────────────────────────────────────────

async def send_prof_stats_notification(
    prof_id: str,
    module_nom: str,
    total_etudiants: int,
    total_present: int,
    total_absent: int,
):
    """
    Notifie le prof avec les statistiques de présence
    après fermeture de la session.
    
    Calcule le taux de présence et envoie au topic personnel du prof.
    """
    try:
        topic = f"prof_{prof_id.replace('-', '_')}"

        # Calcule le pourcentage
        if total_etudiants > 0:
            pourcentage = round((total_present / total_etudiants) * 100)
        else:
            pourcentage = 0

        # Emoji selon le pourcentage
        if pourcentage >= 80:
            emoji = "🎉"
            evaluation = "Excellent taux"
        elif pourcentage >= 60:
            emoji = "👍"
            evaluation = "Bon taux"
        elif pourcentage >= 40:
            emoji = "⚠️"
            evaluation = "Taux moyen"
        else:
            emoji = "📉"
            evaluation = "Taux faible"

        message = messaging.Message(
            notification=messaging.Notification(
                title=f"{emoji} Bilan — {module_nom}",
                body=f"{evaluation} de présence : {pourcentage}% "
                     f"({total_present}/{total_etudiants} présents, "
                     f"{total_absent} absents)"
            ),
            data={
                "type": "stats_session",
                "module_nom": module_nom,
                "total_etudiants": str(total_etudiants),
                "total_present": str(total_present),
                "total_absent": str(total_absent),
                "pourcentage": str(pourcentage),
            },
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    color="#185FA5",  # Couleur prof
                    channel_id="eniad_stats",
                )
            ),
            topic=topic,
        )

        response = messaging.send(message)
        print(f"✅ Stats prof → topic {topic}: {pourcentage}% — {response}")
        return True

    except Exception as e:
        print(f"❌ Erreur stats prof: {e}")
        return False