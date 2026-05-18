// ============================================================
// FCM SERVICE — Firebase Cloud Messaging
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class FCMService {
  FCMService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  // ============================================================
  // INITIALISATION
  // ============================================================

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      print('Firebase Core initialisé');

      await _requestPermissions();
      await _setupLocalNotifications();
      _setupListeners();

      final token = await _fcm.getToken();
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print(' FCM Token: $token');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      print('Erreur init FCM: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    await Permission.notification.request();

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print(' Permission notifications accordée');
    } else {
      print(' Permission notifications refusée');
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        print('🔔 Notification cliquée: ${response.payload}');
      },
    );

    // ── Crée les channels Android via une approche différente ──
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifs.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'eniad_sessions',
          'Sessions ENIAD',
          description: 'Notifications de sessions de cours',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'eniad_stats',
          'Statistiques ENIAD',
          description: 'Statistiques des sessions',
          importance: Importance.high,
        ),
      );
    }
  }

  static void _setupListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔔 Notification FOREGROUND');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
      print('   Data: ${message.data}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Notification cliquée: ${message.data}');
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    final type = message.data['type'] ?? '';
    final channelId =
        type == 'stats_session' ? 'eniad_stats' : 'eniad_sessions';
    final channelName =
        type == 'stats_session' ? 'Statistiques ENIAD' : 'Sessions ENIAD';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFC26B4F),
    );

    final notifDetails = NotificationDetails(android: androidDetails);

    await _localNotifs.show(
      notif.hashCode,
      notif.title,
      notif.body,
      notifDetails,
      payload: message.data.toString(),
    );
  }

  // ============================================================
  // ABONNEMENTS AUX TOPICS
  // ============================================================

  static Future<void> subscribeToModules(List<String> moduleIds) async {
    for (final moduleId in moduleIds) {
      final topic = 'module_${moduleId.replaceAll('-', '_')}';
      try {
        await _fcm.subscribeToTopic(topic);
        print(' Abonné au topic: $topic');
      } catch (e) {
        print(' Erreur abonnement $topic: $e');
      }
    }
  }

  static Future<void> unsubscribeFromModule(String moduleId) async {
    final topic = 'module_${moduleId.replaceAll('-', '_')}';
    try {
      await _fcm.unsubscribeFromTopic(topic);
      print(' Désabonné du topic: $topic');
    } catch (e) {
      print(' Erreur désabonnement $topic: $e');
    }
  }

  static Future<void> subscribeToProfTopic(String profId) async {
    final topic = 'prof_${profId.replaceAll('-', '_')}';
    try {
      await _fcm.subscribeToTopic(topic);
      print(' Abonné au topic prof: $topic');
    } catch (e) {
      print(' Erreur abonnement prof: $e');
    }
  }

  static Future<void> unsubscribeAll() async {
    try {
      await _fcm.deleteToken();
      print(' Tous les topics nettoyés');
    } catch (e) {
      print(' Erreur cleanup: $e');
    }
  }
}