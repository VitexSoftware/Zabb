import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _createNotificationChannels();
    _initialized = true;
  }

  Future<void> _createNotificationChannels() async {
    // High priority channel for critical alerts
    const criticalChannel = AndroidNotificationChannel(
      'zabbix_critical_alerts',
      'Zabbix Critical Alerts',
      description: 'Critical Zabbix monitoring alerts',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    // Regular alerts channel
    const regularChannel = AndroidNotificationChannel(
      'zabbix_regular_alerts',
      'Zabbix Alerts',
      description: 'Zabbix monitoring alerts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Background service channel
    const backgroundChannel = AndroidNotificationChannel(
      'zabbix_background_service',
      'Zabbix Monitoring Service',
      description: 'Background monitoring service for Zabbix alerts',
      importance: Importance.low,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(criticalChannel);
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(regularChannel);
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(backgroundChannel);
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap - could navigate to specific problem screen
    debugPrint('Notification tapped: ${response.id}, payload: ${response.payload}');
  }

  Future<void> showZabbixAlertNotification({
    required String title,
    required String message,
    required int severity,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    final bool isCritical = severity >= 4; // High and disaster severity
    
    final androidDetails = AndroidNotificationDetails(
      isCritical ? 'zabbix_critical_alerts' : 'zabbix_regular_alerts',
      isCritical ? 'Zabbix Critical Alerts' : 'Zabbix Alerts',
      channelDescription: 'Zabbix monitoring alerts',
      importance: isCritical ? Importance.max : Importance.high,
      priority: isCritical ? Priority.max : Priority.high,
      fullScreenIntent: isCritical,
      autoCancel: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        message,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: 'Zabbix Alert',
        htmlFormatSummaryText: false,
      ),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      color: _getSeverityColor(severity),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647, // Unique ID
      title,
      message,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> showBackgroundServiceNotification({
    required String status,
    int? problemCount,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'zabbix_background_service',
      'Zabbix Monitoring Service',
      channelDescription: 'Background monitoring service for Zabbix alerts',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        problemCount != null && problemCount > 0 
          ? '$status\n$problemCount active problems detected'
          : status,
        htmlFormatBigText: false,
        contentTitle: 'Zabbix Monitor Active',
        htmlFormatContentTitle: false,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999, // Fixed ID for service notification
      'Zabbix Monitor Active',
      status,
      notificationDetails,
    );
  }

  Future<void> cancelServiceNotification() async {
    await _notifications.cancel(999999);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 0: // Not classified
        return Colors.grey;
      case 1: // Information
        return Colors.blue;
      case 2: // Warning
        return Colors.orange;
      case 3: // Average
        return Colors.amber;
      case 4: // High
        return Colors.red;
      case 5: // Disaster
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      return await androidImpl.areNotificationsEnabled() ?? false;
    }
    
    return true; // Assume enabled on other platforms
  }

  Future<void> requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
    }
  }
}