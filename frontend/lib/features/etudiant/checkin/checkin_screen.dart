// ============================================================
// POINTAGE — Reconnaissance faciale + GPS
// ============================================================
// L'étudiant prend un selfie qui est envoyé au backend.
// Le backend compare avec son embedding facial enregistré.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/message_box.dart';

class CheckinScreen extends StatefulWidget {
  final String sessionId;
  final String moduleName;

  const CheckinScreen({
    super.key,
    required this.sessionId,
    required this.moduleName,
  });

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  CameraController? _camera;
  bool _initializing = true;
  bool _processing = false;
  String _statusMessage = 'Initialisation...';
  bool _hasError = false;

  // Position GPS
  double? _latitude;
  double? _longitude;

  // Résultat du pointage
  bool _checkinDone = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  // ── Initialisation complète ───────────────────────────────
  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _statusMessage = 'Vérification des permissions...';
    });

    // 1. Permissions caméra
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      _showError('Permission caméra refusée');
      return;
    }

    // 2. Permissions GPS
    setState(() => _statusMessage = 'Demande de localisation...');
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      _showError('Permission de localisation refusée');
      return;
    }

    // 3. Vérifier que le service GPS est activé
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Activez la localisation sur votre téléphone');
      return;
    }

    // 4. Récupérer la position
    setState(() => _statusMessage = 'Récupération de la position...');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      _latitude = position.latitude;
      _longitude = position.longitude;
    } catch (e) {
      _showError('Impossible d\'obtenir votre position : $e');
      return;
    }

    // 5. Initialiser la caméra
    setState(() => _statusMessage = 'Initialisation de la caméra...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('Aucune caméra disponible');
        return;
      }

      // Cherche la caméra frontale
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _camera!.initialize();
    } catch (e) {
      _showError('Erreur caméra : $e');
      return;
    }

    if (!mounted) return;

    setState(() {
      _initializing = false;
      _statusMessage = 'Prêt à pointer';
    });
  }

  // ── Affiche une erreur ────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
      _initializing = false;
      _statusMessage = msg;
    });
  }

  // ── Capture et envoi du pointage ──────────────────────────
  Future<void> _doCheckin() async {
    if (_camera == null || !_camera!.value.isInitialized) {
      MessageBox.show(
        context,
        message: 'Caméra non prête',
        type: MessageType.error,
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      MessageBox.show(
        context,
        message: 'Position GPS non disponible',
        type: MessageType.error,
      );
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = 'Vérification en cours...\nClignez des yeux';
    });

    try {
      // 1. Capture d'une rafale de 5 photos (~2,5 s) pour la
      //    détection de clignement côté backend
      final frames = <String>[];
      for (var i = 0; i < 5; i++) {
        final image = await _camera!.takePicture();
        final bytes = await File(image.path).readAsBytes();
        frames.add(base64Encode(bytes));
        if (i < 4) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
      }

      setState(() => _statusMessage = 'Vérification du visage...');

      // 2. Envoi au backend
      final result = await ApiService.checkin(
        sessionId: widget.sessionId,
        framesBase64: frames,
        latitude: _latitude!,
        longitude: _longitude!,
      );

      // 4. Affichage du résultat
      if (!mounted) return;

      setState(() {
        _checkinDone = true;
        _resultSuccess = true;
        _resultMessage = result['message'] ?? 'Pointage enregistré';
        _processing = false;
      });

      // Auto retour après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checkinDone = true;
        _resultSuccess = false;
        _resultMessage =
            e.toString().replaceAll('Exception: ', '');
        _processing = false;
      });
    }
  }

  // ── Réessayer après échec ─────────────────────────────────
  void _retry() {
    setState(() {
      _checkinDone = false;
      _resultMessage = null;
      _resultSuccess = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pointage',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTheme.textLarge,
                          ),
                        ),
                        Text(
                          widget.moduleName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: AppTheme.textSmall,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_latitude != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'GPS OK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Zone caméra ──────────────────────────────────
            Expanded(child: _buildCameraView()),

            // ── Footer avec bouton ───────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Vue caméra ────────────────────────────────────────────
  Widget _buildCameraView() {
    // Affichage du résultat
    if (_checkinDone) {
      return _buildResultView();
    }

    // Erreur d'initialisation
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.textLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Réessayer',
                icon: Icons.refresh,
                fullWidth: false,
                onPressed: () {
                  setState(() => _hasError = false);
                  _initialize();
                },
              ),
            ],
          ),
        ),
      );
    }

    // Initialisation
    if (_initializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      );
    }

    // Caméra prête
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview caméra
        ClipRect(
          child: Transform.scale(
            scale: 1.0,
            child: Center(
              child: CameraPreview(_camera!),
            ),
          ),
        ),

        // ── Overlay avec cadre visage ──────────────────────
        Positioned.fill(
          child: CustomPaint(
            painter: _FaceFramePainter(),
          ),
        ),

        // ── Indicateur en cours ────────────────────────────
        if (_processing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.success,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Vue résultat ──────────────────────────────────────────
  Widget _buildResultView() {
    final color = _resultSuccess ? AppColors.success : AppColors.error;
    final icon =
        _resultSuccess ? Icons.check_circle : Icons.error_outline;
    final title = _resultSuccess ? 'Pointage validé !' : 'Échec du pointage';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _resultMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTheme.textMedium,
              ),
            ),
            const SizedBox(height: 48),
            if (_resultSuccess)
              const Text(
                'Retour automatique...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: AppTheme.textSmall,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppButton(
                    text: 'Réessayer',
                    icon: Icons.refresh,
                    fullWidth: false,
                    customColor: AppColors.success,
                    onPressed: _retry,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    text: 'Fermer',
                    icon: Icons.close,
                    fullWidth: false,
                    style: AppButtonStyle.outline,
                    customColor: Colors.white,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Footer avec bouton ────────────────────────────────────
  Widget _buildFooter() {
    if (_checkinDone || _hasError || _initializing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.black,
      child: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Centrez votre visage dans le cadre puis appuyez sur le bouton',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: AppTheme.textSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Bouton de capture
          GestureDetector(
            onTap: _processing ? null : _doCheckin,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _processing
                    ? AppColors.textGrey
                    : AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fingerprint,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Pointer ma présence',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PAINTER — Cadre pour aligner le visage
// ============================================================

class _FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Cadre ovale au centre
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final ovalWidth = size.width * 0.7;
    final ovalHeight = size.height * 0.5;

    final ovalRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Fond noir transparent (sauf l'ovale)
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);

    final cutoutPath = Path.combine(
      PathOperation.difference,
      fullPath,
      ovalPath,
    );

    canvas.drawPath(cutoutPath, backgroundPaint);

    // Bordure de l'ovale
    final borderPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawOval(ovalRect, borderPaint);

    // Coins décoratifs (4 coins)
    final cornerPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerSize = 30.0;

    // Top left
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top + cornerSize),
      Offset(ovalRect.left, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.top),
      Offset(ovalRect.left + cornerSize, ovalRect.top),
      cornerPaint,
    );

    // Top right
    canvas.drawLine(
      Offset(ovalRect.right - cornerSize, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.top),
      Offset(ovalRect.right, ovalRect.top + cornerSize),
      cornerPaint,
    );

    // Bottom left
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom - cornerSize),
      Offset(ovalRect.left, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.left, ovalRect.bottom),
      Offset(ovalRect.left + cornerSize, ovalRect.bottom),
      cornerPaint,
    );

    // Bottom right
    canvas.drawLine(
      Offset(ovalRect.right - cornerSize, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(ovalRect.right, ovalRect.bottom),
      Offset(ovalRect.right, ovalRect.bottom - cornerSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}