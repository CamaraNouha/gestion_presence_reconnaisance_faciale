// ============================================================
// OUVRIR UNE SESSION — Vue Professeur
// ============================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/message_box.dart';
import 'active_session_screen.dart';

class OpenSessionScreen extends StatefulWidget {
  final List<dynamic> modules;

  const OpenSessionScreen({super.key, required this.modules});

  @override
  State<OpenSessionScreen> createState() => _OpenSessionScreenState();
}

class _OpenSessionScreenState extends State<OpenSessionScreen> {
  String? _selectedModuleId;
  int _delaiMinutes = 15;
  bool _loading = false;
  bool _gettingLocation = false;
  double? _latitude;
  double? _longitude;

  // Délais possibles
  final List<int> _delais = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  // ── Récupère la position ──────────────────────────────────
  Future<void> _getLocation() async {
    setState(() => _gettingLocation = true);

    try {
      // Permission
      final status = await Permission.location.request();
      if (!status.isGranted) {
        if (mounted) {
          MessageBox.show(
            context,
            message: 'Permission de localisation refusée',
            type: MessageType.error,
          );
        }
        return;
      }

      // Service activé ?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          MessageBox.show(
            context,
            message: 'Activez la localisation sur votre téléphone',
            type: MessageType.error,
          );
        }
        return;
      }

      // Position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        MessageBox.show(
          context,
          message: 'Impossible d\'obtenir la position',
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ── Ouvrir la session ─────────────────────────────────────
  Future<void> _openSession() async {
    if (_selectedModuleId == null) {
      MessageBox.show(
        context,
        message: 'Veuillez sélectionner un module',
        type: MessageType.warning,
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

    setState(() => _loading = true);

    try {
      final response = await ApiService.openSession(
        moduleId: _selectedModuleId!,
        delaiMinutes: _delaiMinutes,
        latitude: _latitude!,
        longitude: _longitude!,
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Session ouverte avec succès',
        type: MessageType.success,
      );

      // Trouve le nom du module
      final module = widget.modules.firstWhere(
        (m) => m['id'] == _selectedModuleId,
        orElse: () => null,
      );

      // Va directement à l'écran de session active
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(
            sessionId: response['id'],
            moduleName: module?['nom'] ?? 'Module',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.professeur,
        title: const Text('Nouvelle session'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.professeurLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.professeur,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Une notification sera envoyée aux étudiants inscrits dès l\'ouverture',
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: AppColors.professeur,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Sélection module ────────────────────────────
            const Text(
              'Module',
              style: TextStyle(
                fontSize: AppTheme.textSmall,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.modules.map((m) => _buildModuleCard(m)),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Délai ───────────────────────────────────────
            const Text(
              'Délai du pointage',
              style: TextStyle(
                fontSize: AppTheme.textSmall,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Les étudiants ont ce temps pour pointer avant d\'être marqués absents',
              style: TextStyle(
                fontSize: AppTheme.textXSmall,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _delais.map((d) {
                  final selected = _delaiMinutes == d;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _delaiMinutes = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.professeur
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.professeur
                                : AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textGrey,
                              size: 18,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$d min',
                              style: TextStyle(
                                fontSize: AppTheme.textSmall,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Position GPS ────────────────────────────────
            const Text(
              'Localisation',
              style: TextStyle(
                fontSize: AppTheme.textSmall,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              decoration: BoxDecoration(
                color: _latitude != null
                    ? AppColors.successLight
                    : AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _latitude != null
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _latitude != null
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    color: _latitude != null
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gettingLocation
                              ? 'Récupération en cours...'
                              : (_latitude != null
                                  ? 'Position GPS récupérée'
                                  : 'Position non disponible'),
                          style: TextStyle(
                            fontSize: AppTheme.textSmall,
                            fontWeight: FontWeight.w600,
                            color: _latitude != null
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        if (_latitude != null)
                          Text(
                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              color: AppColors.textGrey,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_gettingLocation && _latitude == null)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _getLocation,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Bouton ouvrir ───────────────────────────────
            AppButton(
              text: 'Ouvrir la session',
              icon: Icons.play_arrow,
              loading: _loading,
              onPressed:
                  (_selectedModuleId != null && _latitude != null)
                      ? _openSession
                      : null,
              customColor: AppColors.success,
            ),

            const SizedBox(height: AppTheme.spaceXLarge),
          ],
        ),
      ),
    );
  }

  // ── Card de module ────────────────────────────────────────
  Widget _buildModuleCard(Map<String, dynamic> module) {
    final selected = _selectedModuleId == module['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedModuleId = module['id']),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: selected ? AppColors.professeurLight : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: selected ? AppColors.professeur : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.professeur
                      : AppColors.professeurLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.book_outlined,
                  color:
                      selected ? Colors.white : AppColors.professeur,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module['nom'] ?? '',
                      style: const TextStyle(
                        fontSize: AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.professeurLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            module['code'] ?? '',
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.w600,
                              color: AppColors.professeur,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (module['semestre'] != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            module['semestre'],
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.professeur,
                ),
            ],
          ),
        ),
      ),
    );
  }
}