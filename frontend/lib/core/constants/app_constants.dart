// ============================================================
// CONSTANTES DE L'APPLICATION
// ============================================================

class AppConstants {
  AppConstants._();

  // ── Informations école ────────────────────────────────────
  static const String appName = 'ENIAD';
  static const String appFullName =
      'École Nationale d\'Intelligence Artificielle et du Digital';
  static const String appCity = 'Berkane';
  static const String appSlogan = 'Système de gestion de présence';

  // ── API Backend ───────────────────────────────────────────
  // ⚠️ Change cette IP par celle de ta machine locale
  static const String apiBaseUrl = 'http://192.168.1.197:8000';

  // ── Timeouts ──────────────────────────────────────────────
  static const int connectionTimeout = 15; // secondes
  static const int receiveTimeout = 30;    // secondes

  // ── Reconnaissance faciale ────────────────────────────────
  static const double faceMatchThreshold = 0.363;
  static const int maxPhotoSize = 800; // pixels

  // ── Géolocalisation ───────────────────────────────────────
  static const double maxDistanceMeters = 200.0;

  // ── Pointage ──────────────────────────────────────────────
  static const int defaultSessionDelay = 15; // minutes
  static const int sessionRefreshInterval = 5; // secondes
}