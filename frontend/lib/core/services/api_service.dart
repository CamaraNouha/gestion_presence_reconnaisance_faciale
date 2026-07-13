// ============================================================
// API SERVICE — Communication avec le backend FastAPI
// ============================================================
// Toutes les requêtes HTTP au backend passent par ce service.
// Il ajoute automatiquement le token JWT dans les headers.
// ============================================================


import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../constants/app_constants.dart';
import 'storage_service.dart';
import 'navigation_service.dart';

class ApiService {
  ApiService._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(
      seconds: AppConstants.connectionTimeout,
    ),
    receiveTimeout: const Duration(
      seconds: AppConstants.receiveTimeout,
    ),
    headers: {'Content-Type': 'application/json'},
  ));

  // ============================================================
  // INITIALISATION
  // ============================================================

  // Empêche plusieurs rafraîchissements simultanés (un seul à la fois)
  static Future<bool>? _refreshFuture;

  static void init() {
    _dio.interceptors.clear();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isAuthCall =
            path.contains('/auth/login') || path.contains('/auth/refresh');
        final alreadyRetried =
            error.requestOptions.extra['retried'] == true;

        // ── Access token expiré → tente un refresh puis rejoue ──
        if (status == 401 && !isAuthCall && !alreadyRetried) {
          // Un seul refresh à la fois : les requêtes concurrentes
          // attendent le même résultat.
          _refreshFuture ??= _refreshTokens();
          final refreshed = await _refreshFuture!;
          _refreshFuture = null;

          if (refreshed) {
            try {
              final newToken = await StorageService.getToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              opts.extra['retried'] = true;
              final retryResponse = await _dio.fetch(opts);
              return handler.resolve(retryResponse);
            } catch (_) {
              // Le rejeu a échoué → on laisse l'erreur suivre son cours
            }
          }
        }

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('   API Error');
        print('   Path: ${error.requestOptions.path}');
        print('   Status: ${error.response?.statusCode}');
        print('   Message: ${error.response?.data}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return handler.next(error);
      },
    ));
  }

  // ============================================================
  // REFRESH TOKEN
  // ============================================================

  /// Échange le refresh token stocké contre un nouveau couple de
  /// tokens. Utilise un Dio « nu » (sans intercepteur) pour éviter
  /// toute récursion. Retourne true si le rafraîchissement a réussi.
  static Future<bool> _refreshTokens() async {
    final refresh = await StorageService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      // Aucun refresh token → session terminée
      await _handleSessionExpired();
      return false;
    }

    try {
      final bareDio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      final response = await bareDio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final newAccess = response.data['access_token'] as String;
      final newRefresh = response.data['refresh_token'] as String;
      await StorageService.updateTokens(
        token: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } on DioException catch (e) {
      // 401 → refresh réellement invalide/expiré/révoqué → déconnexion
      if (e.response?.statusCode == 401) {
        await _handleSessionExpired();
      } else {
        // Erreur réseau transitoire → on NE déconnecte PAS
        print('Refresh réseau échoué: ${e.message}');
      }
      return false;
    }
  }

  // Évite de traiter l'expiration plusieurs fois en parallèle
  static bool _sessionExpiredHandling = false;

  /// Session définitivement expirée : on nettoie et on renvoie
  /// l'utilisateur vers l'écran de login (redirection live).
  static Future<void> _handleSessionExpired() async {
    if (_sessionExpiredHandling) return;
    _sessionExpiredHandling = true;
    try {
      await StorageService.clearAll();
    } catch (_) {
      // ignore
    }
    NavigationService.goToLogin();
    _sessionExpiredHandling = false;
  }

  // ============================================================
  // LOGOUT — révoque le refresh token côté serveur
  // ============================================================

  static Future<void> logout() async {
    try {
      final refresh = await StorageService.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh});
      }
    } catch (e) {
      print('logout error: $e');
    }
  }

  static String _errorMessage(DioException e) {
    if (e.response?.data is Map) {
      return e.response?.data['detail']?.toString() ?? 'Erreur inconnue';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Impossible de contacter le serveur';
    }
    if (e.type == DioExceptionType.receiveTimeout) {
      return 'Le serveur met trop de temps à répondre';
    }
    return 'Erreur réseau';
  }

  // ============================================================
  // TEST DE CONNEXION
  // ============================================================

  static Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (e) {
      print('Test connexion échoué: $e');
      return false;
    }
  }

  // ============================================================
  // AUTH — Login par apogée + mot de passe
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String apogee,
    required String motDePasse,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'apogee': apogee,
        'mot_de_passe': motDePasse,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // PROFIL UTILISATEUR
  // ============================================================

  static Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _dio.get('/users/me');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> updateMyProfile({
    String? nom,
    String? prenom,
    String? email,
  }) async {
    try {
      await _dio.put('/users/me', data: {
        if (nom != null) 'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (email != null) 'email': email,
      });
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> changePassword({
    required String ancien,
    required String nouveau,
  }) async {
    try {
      await _dio.put(
        '/users/me/password',
        data: FormData.fromMap({
          'ancien_mot_de_passe': ancien,
          'nouveau_mot_de_passe': nouveau,
        }),
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // ADMIN — UTILISATEURS
  // ============================================================

  static Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getAllUsers error: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<List<dynamic>> getStudents() async {
    final all = await getAllUsers();
    return all.where((u) => u['role'] == 'etudiant').toList();
  }

  static Future<List<dynamic>> getProfessors() async {
    final all = await getAllUsers();
    return all.where((u) => u['role'] == 'professeur').toList();
  }

  static Future<Map<String, dynamic>> createUser({
    required String nom,
    required String prenom,
    required String email,
    required String apogee,
    required String role,
    required String motDePasse,
    String? photoPath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'apogee': apogee,
        'mot_de_passe': motDePasse,
        'role': role,
        if (photoPath != null)
          'photo': await MultipartFile.fromFile(photoPath),
      });
      final response = await _dio.post('/admin/users', data: formData);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // IMPORT EN BLOC (Admin)
  // ============================================================

  static Future<Map<String, dynamic>> bulkImportStudents(
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/admin/users/bulk-import',
        data: formData,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // VÉRIFIE SI L'UTILISATEUR A UNE PHOTO
  // ============================================================

  static Future<bool> hasPhoto() async {
    try {
      final response = await _dio.get('/users/me/has-photo');
      return response.data['has_photo'] == true;
    } on DioException catch (e) {
      print('hasPhoto error: ${_errorMessage(e)}');
      return true; // En cas d'erreur, on suppose qu'il a (pour ne pas bloquer)
    }
  }

  // ============================================================
  // L'UTILISATEUR UPLOAD SA PROPRE PHOTO
  // ============================================================

  static Future<Map<String, dynamic>> uploadMyPhoto(
    String filePath,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        '/users/me/upload-photo',
        data: formData,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await _dio.delete('/admin/users/$userId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // ADMIN — MODULES
  // ============================================================

  static Future<List<dynamic>> getAllModules() async {
    try {
      final response = await _dio.get('/admin/modules');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getAllModules error: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createModule({
    required String nom,
    required String code,
    required String semestre,
    required String filiere,
    required String professeurId,
  }) async {
    try {
      final response = await _dio.post('/admin/modules', data: {
        'nom': nom,
        'code': code,
        'semestre': semestre,
        'filiere': filiere,
        'professeur_id': professeurId,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> deleteModule(String moduleId) async {
    try {
      await _dio.delete('/admin/modules/$moduleId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<List<dynamic>> getModuleStudents(String moduleId) async {
    try {
      final response = await _dio.get(
        '/admin/modules/$moduleId/students',
      );
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getModuleStudents: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<void> assignStudentToModule({
    required String moduleId,
    required String studentId,
  }) async {
    try {
      await _dio.post(
        '/admin/modules/$moduleId/students/$studentId',
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> removeStudentFromModule({
    required String moduleId,
    required String studentId,
  }) async {
    try {
      await _dio.delete(
        '/admin/modules/$moduleId/students/$studentId',
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // ÉTUDIANT
  // ============================================================

  static Future<List<dynamic>> getMyModules() async {
    try {
      final response = await _dio.get('/users/me/my-modules');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getMyModules: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<List<dynamic>> getMyAttendances() async {
    try {
      final response = await _dio.get('/users/me/attendances');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getMyAttendances: ${_errorMessage(e)}');
      return [];
    }
  }

  // ============================================================
  // PROFESSEUR
  // ============================================================

  static Future<List<dynamic>> getProfModules() async {
    try {
      final response = await _dio.get('/sessions/prof-modules');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getProfModules: ${_errorMessage(e)}');
      return [];
    }
  }

  // ============================================================
  // SESSIONS
  // ============================================================

  static Future<Map<String, dynamic>> openSession({
    required String moduleId,
    required int delaiMinutes,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.post('/sessions/open', data: {
        'module_id': moduleId,
        'delai_minutes': delaiMinutes,
        'latitude': latitude,
        'longitude': longitude,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<void> closeSession(String sessionId) async {
    try {
      await _dio.post('/sessions/$sessionId/close');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  static Future<List<dynamic>> getActiveSessions() async {
    try {
      final response = await _dio.get('/sessions/active');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getActiveSessions: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<List<dynamic>> getMySessions() async {
    try {
      final response = await _dio.get('/sessions/my-sessions');
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getMySessions: ${_errorMessage(e)}');
      return [];
    }
  }

  static Future<List<dynamic>> getSessionAttendances(
    String sessionId,
  ) async {
    try {
      final response = await _dio.get(
        '/sessions/$sessionId/attendances',
      );
      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      print('getSessionAttendances: ${_errorMessage(e)}');
      return [];
    }
  }

  // ── Récupère les infos d'une session ──────────────────────
  static Future<Map<String, dynamic>?> getSessionInfo(
    String sessionId,
  ) async {
    try {
      // On utilise la liste de mes sessions et on filtre
      final mySessions = await getMySessions();
      final session = mySessions.firstWhere(
        (s) => s['id'] == sessionId,
        orElse: () => null,
      );
      if (session == null) return null;
      return Map<String, dynamic>.from(session);
    } catch (e) {
      print('getSessionInfo: $e');
      return null;
    }
  }

  static Future<void> updateAttendanceStatus({
    required String sessionId,
    required String studentId,
    required String statut,
  }) async {
    try {
      await _dio.patch(
        '/sessions/$sessionId/attendances/$studentId',
        data: {'statut': statut},
      );
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // POINTAGE
  // ============================================================

  static Future<Map<String, dynamic>> checkin({
    required String sessionId,
    required List<String> framesBase64,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.post('/checkin/', data: {
        'session_id': sessionId,
        'frames_base64': framesBase64,
        'latitude': latitude,
        'longitude': longitude,
      });
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }

  // ============================================================
  // EXPORT
  // ============================================================

  static Future<void> downloadExport({
    required String sessionId,
    required String format,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = format == 'excel' ? 'xlsx' : 'csv';
      final filePath = '${dir.path}/presence_$sessionId.$ext';

      await _dio.download(
        '/export/$format/$sessionId',
        filePath,
      );

      await OpenFilex.open(filePath);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e));
    }
  }
}