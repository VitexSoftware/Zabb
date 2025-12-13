import 'package:shared_preferences/shared_preferences.dart';
import '../api/zabbix_api.dart';

class ZabbixAlert {
  final String eventId;
  final String name;
  final int severity;
  final DateTime timestamp;
  final String objectId;
  final List<Map<String, dynamic>> acknowledges;
  final List<Map<String, dynamic>> tags;

  ZabbixAlert({
    required this.eventId,
    required this.name,
    required this.severity,
    required this.timestamp,
    required this.objectId,
    required this.acknowledges,
    required this.tags,
  });

  factory ZabbixAlert.fromJson(Map<String, dynamic> json) {
    return ZabbixAlert(
      eventId: json['eventid'] as String,
      name: json['name'] as String,
      severity: int.tryParse(json['severity'].toString()) ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (int.tryParse(json['clock'].toString()) ?? 0) * 1000,
      ),
      objectId: json['objectid'] as String,
      acknowledges: (json['acknowledges'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      tags: (json['tags'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventid': eventId,
      'name': name,
      'severity': severity.toString(),
      'clock': (timestamp.millisecondsSinceEpoch ~/ 1000).toString(),
      'objectid': objectId,
      'acknowledges': acknowledges,
      'tags': tags,
    };
  }

  String get severityText {
    switch (severity) {
      case 0: return 'Not classified';
      case 1: return 'Information';
      case 2: return 'Warning';
      case 3: return 'Average';
      case 4: return 'High';
      case 5: return 'Disaster';
      default: return 'Unknown';
    }
  }

  bool get isAcknowledged => acknowledges.isNotEmpty;
  bool get isCritical => severity >= 4;
}

class ZabbixAlertState {
  final bool hasConnection;
  final List<ZabbixAlert> alerts;
  final String? error;
  final DateTime lastCheck;

  ZabbixAlertState({
    required this.hasConnection,
    required this.alerts,
    this.error,
    required this.lastCheck,
  });

  int get totalAlerts => alerts.length;
  int get criticalAlerts => alerts.where((alert) => alert.isCritical).length;
  int get unacknowledgedAlerts => alerts.where((alert) => !alert.isAcknowledged).length;
  bool get hasActiveAlerts => alerts.isNotEmpty;
  bool get hasCriticalAlerts => criticalAlerts > 0;
}

class ZabbixPollingService {
  static final ZabbixPollingService _instance = ZabbixPollingService._internal();
  static ZabbixPollingService get instance => _instance;
  ZabbixPollingService._internal();

  ZabbixApi? _api;
  ZabbixAlertState? _lastState;
  String? _cachedToken;

  ZabbixAlertState? get lastState => _lastState;

  Future<ZabbixAlertState> pollZabbixAlerts() async {
    try {
      // Initialize API if needed
      await _ensureApiInitialized();
      
      if (_api == null) {
        return ZabbixAlertState(
          hasConnection: false,
          alerts: [],
          error: 'API not configured',
          lastCheck: DateTime.now(),
        );
      }

      // Ensure we're authenticated
      await _ensureAuthenticated();

      // Get recent problems (last 24 hours)
      final problemsData = await _api!.getProblems(recentSeconds: 86400);
      
      final alerts = problemsData.map((problem) => ZabbixAlert.fromJson(problem)).toList();
      
      final state = ZabbixAlertState(
        hasConnection: true,
        alerts: alerts,
        lastCheck: DateTime.now(),
      );

      _lastState = state;
      return state;

    } catch (e) {
      final errorState = ZabbixAlertState(
        hasConnection: false,
        alerts: [],
        error: e.toString(),
        lastCheck: DateTime.now(),
      );
      
      _lastState = errorState;
      return errorState;
    }
  }

  Future<void> _ensureApiInitialized() async {
    if (_api != null) return;

    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('zbx_server');
    
    if (server == null || server.isEmpty) {
      throw Exception('Zabbix server not configured');
    }

    _api = ZabbixApi(server);
  }

  Future<void> _ensureAuthenticated() async {
    if (_api == null) return;

    // If we have a cached token and it's still valid, use it
    if (_cachedToken != null && _api!.authToken == _cachedToken) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('zbx_user');
    final password = prefs.getString('zbx_password');

    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      throw Exception('Zabbix credentials not configured');
    }

    try {
      final token = await _api!.login(username: username, password: password);
      _cachedToken = token;
    } catch (e) {
      _cachedToken = null;
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    try {
      await _ensureApiInitialized();
      await _ensureAuthenticated();
      return true;
    } catch (e) {
      return false;
    }
  }

  void reset() {
    _api = null;
    _cachedToken = null;
    _lastState = null;
  }

  Future<List<ZabbixAlert>> getNewAlerts(List<String> previousEventIds) async {
    final currentState = await pollZabbixAlerts();
    
    if (!currentState.hasConnection || !currentState.hasActiveAlerts) {
      return [];
    }

    // Return alerts that weren't in the previous check
    return currentState.alerts
        .where((alert) => !previousEventIds.contains(alert.eventId))
        .toList();
  }

  Future<void> acknowledgeAlert(String eventId, [String? message]) async {
    if (_api == null) {
      await _ensureApiInitialized();
      await _ensureAuthenticated();
    }

    await _api!.acknowledgeEvent(eventId: eventId, message: message);
  }

  Future<void> closeAlert(String eventId) async {
    if (_api == null) {
      await _ensureApiInitialized();
      await _ensureAuthenticated();
    }

    await _api!.closeEvent(eventId: eventId);
  }

  Future<ZabbixAlert?> getProblemById(String eventId) async {
    await _ensureApiInitialized();
    await _ensureAuthenticated();

    final problemData = await _api!.getProblemById(eventId);
    if (problemData != null) {
      return ZabbixAlert.fromJson(problemData);
    }
    return null;
  }
}