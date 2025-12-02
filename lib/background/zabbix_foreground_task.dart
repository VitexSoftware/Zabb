import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/zabbix_polling_service.dart';
import '../services/notification_service.dart';

class ZabbixTaskHandler extends TaskHandler {
  static const String _statusKey = 'status';
  static const String _alertsKey = 'alerts';
  static const String _errorKey = 'error';
  static const String _lastCheckKey = 'lastCheck';

  SendPort? _sendPort;
  List<String> _lastAlertEventIds = [];
  Timer? _pollTimer;
  bool _isPolling = false;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    
    // Initialize services
    try {
      await NotificationService.instance.initialize();
      await NotificationService.instance.showBackgroundServiceNotification(
        status: 'Initializing Zabbix monitoring...',
      );
    } catch (e) {
      // Continue even if notifications fail
      print('Failed to initialize notifications: $e');
    }

    // Send initial status
    _sendToMainIsolate({
      _statusKey: 'started',
      _lastCheckKey: timestamp.toIso8601String(),
    });

    print('ZabbixTaskHandler started at $timestamp');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    if (_isPolling) return; // Prevent overlapping polls
    
    _isPolling = true;
    try {
      final alertState = await ZabbixPollingService.instance.pollZabbixAlerts();
      
      // Update service notification
      await _updateServiceNotification(alertState);
      
      // Check for new alerts
      await _checkForNewAlerts(alertState);
      
      // Update last known event IDs
      _lastAlertEventIds = alertState.alerts.map((alert) => alert.eventId).toList();
      
      // Send status to main isolate
      _sendToMainIsolate({
        _statusKey: alertState.hasConnection ? 'connected' : 'disconnected',
        _alertsKey: alertState.totalAlerts,
        _errorKey: alertState.error,
        _lastCheckKey: timestamp.toIso8601String(),
      });
      
      print('Zabbix poll completed: ${alertState.totalAlerts} alerts, connection: ${alertState.hasConnection}');
      
    } catch (e) {
      print('Error during Zabbix polling: $e');
      
      // Send error status
      _sendToMainIsolate({
        _statusKey: 'error',
        _errorKey: e.toString(),
        _lastCheckKey: timestamp.toIso8601String(),
      });
      
      try {
        await NotificationService.instance.showBackgroundServiceNotification(
          status: 'Monitoring error: ${e.toString()}',
        );
      } catch (notifError) {
        print('Failed to show error notification: $notifError');
      }
    } finally {
      _isPolling = false;
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print('ZabbixTaskHandler destroyed at $timestamp');
    
    _pollTimer?.cancel();
    
    try {
      await NotificationService.instance.cancelServiceNotification();
    } catch (e) {
      print('Failed to cancel service notification: $e');
    }
    
    _sendToMainIsolate({
      _statusKey: 'stopped',
      _lastCheckKey: timestamp.toIso8601String(),
    });
  }

  Future<void> _updateServiceNotification(ZabbixAlertState alertState) async {
    try {
      String status;
      if (!alertState.hasConnection) {
        status = alertState.error != null 
          ? 'Connection error: ${alertState.error}'
          : 'Disconnected from Zabbix';
      } else if (alertState.hasActiveAlerts) {
        status = 'Monitoring active';
      } else {
        status = 'No active problems';
      }

      await NotificationService.instance.showBackgroundServiceNotification(
        status: status,
        problemCount: alertState.totalAlerts,
      );
    } catch (e) {
      print('Failed to update service notification: $e');
    }
  }

  Future<void> _checkForNewAlerts(ZabbixAlertState alertState) async {
    if (!alertState.hasConnection || !alertState.hasActiveAlerts) {
      return;
    }

    try {
      // Find new alerts that weren't in the last check
      final newAlerts = alertState.alerts
          .where((alert) => !_lastAlertEventIds.contains(alert.eventId))
          .toList();

      for (final alert in newAlerts) {
        // Only notify for unacknowledged alerts
        if (!alert.isAcknowledged) {
          await NotificationService.instance.showZabbixAlertNotification(
            title: 'Zabbix Alert - ${alert.severityText}',
            message: alert.name,
            severity: alert.severity,
            payload: alert.eventId,
          );
          
          print('Sent notification for new alert: ${alert.name} (severity: ${alert.severity})');
        }
      }
    } catch (e) {
      print('Failed to send alert notifications: $e');
    }
  }

  void _sendToMainIsolate(Map<String, dynamic> data) {
    try {
      _sendPort?.send(data);
    } catch (e) {
      print('Failed to send data to main isolate: $e');
    }
  }
}

// Top-level function for the background task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(ZabbixTaskHandler());
}

class ZabbixBackgroundTaskManager {
  static StreamSubscription<Map<String, dynamic>>? _dataSubscription;
  static Stream<Map<String, dynamic>>? _dataStream;

  static Future<bool> initialize() async {
    try {
      // Request notification permissions first
      await NotificationService.instance.initialize();
      await NotificationService.instance.requestPermissions();

      // Initialize the foreground task service
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'zabbix_background_service',
          channelName: 'Zabbix Monitoring Service',
          channelDescription: 'Background monitoring service for Zabbix alerts',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          iconData: const NotificationIconData(
            resType: ResourceType.mipmap,
            resPrefix: ResourcePrefix.ic,
            name: 'launcher',
          ),
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 15000, // 15 seconds
          isOnceEvent: false,
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );

      return true;
    } catch (e) {
      print('Failed to initialize background task manager: $e');
      return false;
    }
  }

  static Future<bool> startMonitoring() async {
    try {
      // Check if task is already running
      if (await FlutterForegroundTask.isRunningService) {
        print('Background task is already running');
        return true;
      }

      // Start the foreground service
      final serviceRequestResult = await FlutterForegroundTask.startService(
        notificationTitle: 'Zabbix Monitor Active',
        notificationText: 'Monitoring Zabbix for alerts...',
        callback: startCallback,
      );

      if (serviceRequestResult) {
        print('Background monitoring started successfully');
        
        // Set up data stream to receive updates from background task
        final receivePort = FlutterForegroundTask.receivePort;
        if (receivePort != null) {
          _dataStream = receivePort.asBroadcastStream().cast<Map<String, dynamic>>();
          _dataSubscription = _dataStream!.listen(
            (data) {
              print('Received from background task: $data');
              // Handle background task updates here if needed
            },
            onError: (error) {
              print('Error receiving background task data: $error');
            },
          );
        }
        
        return true;
      } else {
        print('Failed to start background service');
        return false;
      }
    } catch (e) {
      print('Error starting background monitoring: $e');
      return false;
    }
  }

  static Future<bool> stopMonitoring() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;
      _dataStream = null;

      final result = await FlutterForegroundTask.stopService();
      print('Background monitoring stopped: $result');
      return result;
    } catch (e) {
      print('Error stopping background monitoring: $e');
      return false;
    }
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }

  static Future<void> requestIgnoreBatteryOptimization() async {
    try {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      print('Failed to request battery optimization exemption: $e');
    }
  }

  static Stream<Map<String, dynamic>>? get dataStream => _dataStream;
}