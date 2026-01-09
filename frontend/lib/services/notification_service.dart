import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification click if needed
        },
      );
      print('✅ Notification Plugin Initialized');

      // Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'equipment_alerts',
        'Poultry Smart System',
        description: 'Real-time monitoring and equipment state changes',
        importance: Importance.max,
        enableLights: true,
        ledColor: Color(0xFF4AB08B),
        playSound: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      print('✅ Notification Channel Created');
    } catch (e) {
      print('❌ Error in NotificationService init: $e');
      rethrow; // Rethrow so main knows it failed
    }
  }

  Future<void> requestPermissions() async {
    print('🔑 Requesting Notification Permissions...');
    try {
      final bool? granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      print('📊 Notification Permission Status: $granted');
    } catch (e) {
      print('❌ Error requesting permissions: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'equipment_alerts',
        'Poultry Smart System',
        channelDescription: 'Real-time monitoring and equipment state changes',
        importance: Importance.max,
        priority: Priority.max,
        ticker: 'ticker',
        showWhen: false,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.show(id, title, body, platformDetails);
    } catch (e) {
      print('❌ Notification error: $e');
    }
  }
}
