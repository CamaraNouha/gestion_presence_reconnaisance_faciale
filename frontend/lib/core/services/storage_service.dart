// ============================================================
// STORAGE SERVICE — Stockage sécurisé local
// ============================================================
// Utilisé pour :
// - Sauvegarder le token JWT après login
// - Sauvegarder les infos utilisateur (id, nom, role, etc.)
// - Vérifier si l'utilisateur est connecté
// - Effacer les données au logout
// ============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'fcm_service.dart';
import 'api_service.dart';

class StorageService {
  StorageService._();

  // Instance unique du stockage sécurisé
  static const _storage = FlutterSecureStorage();

  // ── Clés de stockage ──────────────────────────────────────
  static const _keyToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyRole = 'user_role';
  static const _keyNom = 'user_nom';
  static const _keyPrenom = 'user_prenom';
  static const _keyEmail = 'user_email';
  static const _keyApogee = 'user_apogee';

  // ============================================================
  // SAUVEGARDE après login
  // ============================================================

  static Future<void> saveAuthData({
    required String token,
    required String refreshToken,
    required String userId,
    required String role,
    required String nom,
    required String prenom,
    required String email,
    String? apogee,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyRole, value: role);
    await _storage.write(key: _keyNom, value: nom);
    await _storage.write(key: _keyPrenom, value: prenom);
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyApogee, value: apogee ?? '');
  }

  // ============================================================
  // LECTURE des données
  // ============================================================

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // Met à jour uniquement les tokens (après un /auth/refresh)
  static Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  static Future<String?> getRole() async {
    return await _storage.read(key: _keyRole);
  }

  static Future<String?> getNom() async {
    return await _storage.read(key: _keyNom);
  }

  static Future<String?> getPrenom() async {
    return await _storage.read(key: _keyPrenom);
  }

  static Future<String?> getEmail() async {
    return await _storage.read(key: _keyEmail);
  }

  static Future<String?> getApogee() async {
    return await _storage.read(key: _keyApogee);
  }

  // ── Nom complet (Prénom + Nom) ────────────────────────────
  static Future<String> getFullName() async {
    final prenom = await getPrenom() ?? '';
    final nom = await getNom() ?? '';
    return '$prenom $nom'.trim();
  }

  // ── Initiales (pour avatar) ───────────────────────────────
  static Future<String> getInitials() async {
    final prenom = await getPrenom() ?? '';
    final nom = await getNom() ?? '';
    final i1 = prenom.isNotEmpty ? prenom[0] : '';
    final i2 = nom.isNotEmpty ? nom[0] : '';
    return '$i1$i2'.toUpperCase();
  }

  // ============================================================
  // VÉRIFICATIONS
  // ============================================================

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == 'admin';
  }

  static Future<bool> isProf() async {
    final role = await getRole();
    return role == 'professeur';
  }

  static Future<bool> isEtudiant() async {
    final role = await getRole();
    return role == 'etudiant';
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> clearAll() async {
    // Révoque le refresh token côté serveur (best-effort)
    // AVANT d'effacer le stockage local.
    try {
      await ApiService.logout();
    } catch (e) {
      print('Erreur logout serveur: $e');
    }

    await _storage.deleteAll();

    // Désabonne de tous les topics FCM
    try {
      await FCMService.unsubscribeAll();
    } catch (e) {
      print('Erreur cleanup FCM: $e');
    }
  }
}