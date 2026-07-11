// ============================================================
// MAIN — ENIAD Application
// ============================================================

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/navigation_service.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Notification BACKGROUND/TERMINATED');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');
}

void main() async {
  // Initialisation Flutter (obligatoire avant tout async)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase
  await Firebase.initializeApp();
  // Enregistre le handler pour les notifications en background / terminated
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Initialise les services
  ApiService.init();
  await FCMService.init();

  // Récupère le message qui a ouvert l'app (si TERMINATED)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null){
    print('🔔 Notification TERMINATED');
    print('   Data: ${initialMessage.data}');
  }

  runApp(const ENIADApp());
}

// ============================================================
// HANDLER GLOBAL POUR LES NOTIFICATIONS EN BACKGROUND / TERMINATED
// ============================================================
// Cette fonction est appelée par Android quand une notification
// arrive alors que l'app est complètement fermée (terminated)
// ============================================================



class ENIADApp extends StatelessWidget {
  const ENIADApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}