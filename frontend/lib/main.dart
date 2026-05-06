// ============================================================
// MAIN — ENIAD Application
// ============================================================

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/services/fcm_service.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/splash_screen.dart';

void main() async {
  // Initialisation Flutter (obligatoire avant tout async)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise les services
  ApiService.init();
  await FCMService.init();

  runApp(const ENIADApp());
}

class ENIADApp extends StatelessWidget {
  const ENIADApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}