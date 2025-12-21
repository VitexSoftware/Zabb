import 'package:shared_preferences/shared_preferences.dart';
import '../api/zabbix_api.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  ZabbixApi? _api;
  List<Map<String, dynamic>>? _hostsCache;
  Map<String, String>? _triggerToHostCache; // Maps trigger ID to host name

  Future<ZabbixApi> _ensureApi() async {
    if (_api != null) return _api!;
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('zbx_server');
    if (server == null || server.isEmpty) {
      throw StateError('Server not configured');
    }
    _api = ZabbixApi(server);
    return _api!;
  }

  Future<String> login() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('zbx_user');
    final password = prefs.getString('zbx_password');
    if (user == null || password == null) {
      throw StateError('Credentials not configured');
    }
    final api = await _ensureApi();
    // Map stored 'user' to API 'username'
    return api.login(username: user, password: password);
  }

  Future<void> logout() async {
    final api = await _ensureApi();
    await api.logout();
  }

  Future<List<Map<String, dynamic>>> fetchHosts() async {
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    return api.getHosts();
  }

  Future<void> loadHosts() async {
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    try {
      _hostsCache = await api.getHostsWithInterfaces();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('not authorized') || msg.contains('unauthorized')) {
        await login();
        _hostsCache = await api.getHostsWithInterfaces();
      } else {
        rethrow;
      }
    }
  }

  Future<void> loadTriggersToHostMapping(List<String> triggerIds) async {
    if (triggerIds.isEmpty) return;
    
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    
    _triggerToHostCache ??= <String, String>{};
    
    // Only get triggers we don't already have cached
    final uncachedTriggerIds = triggerIds.where((id) => !_triggerToHostCache!.containsKey(id)).toList();
    if (uncachedTriggerIds.isEmpty) return;
    
    try {
      final triggers = await api.getTriggers(triggerIds: uncachedTriggerIds);
      for (final trigger in triggers) {
        final triggerId = trigger['triggerid']?.toString();
        if (triggerId != null) {
          String hostName = 'Unknown';
          if (trigger['hosts'] is List && (trigger['hosts'] as List).isNotEmpty) {
            final host = (trigger['hosts'] as List).first;
            hostName = host['name']?.toString() ?? host['host']?.toString() ?? 'Unknown';
          }
          _triggerToHostCache![triggerId] = hostName;
        }
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('not authorized') || msg.contains('unauthorized')) {
        await login();
        final triggers = await api.getTriggers(triggerIds: uncachedTriggerIds);
        for (final trigger in triggers) {
          final triggerId = trigger['triggerid']?.toString();
          if (triggerId != null) {
            String hostName = 'Unknown';
            if (trigger['hosts'] is List && (trigger['hosts'] as List).isNotEmpty) {
              final host = (trigger['hosts'] as List).first;
              hostName = host['name']?.toString() ?? host['host']?.toString() ?? 'Unknown';
            }
            _triggerToHostCache![triggerId] = hostName;
          }
        }
      } else {
        rethrow;
      }
    }
  }

  String getHostName(String hostId) {
    if (_hostsCache == null) {
      return 'Loading...';
    }
    // Try to find host by hostid (string or int)
    for (final host in _hostsCache!) {
      final hostIdStr = host['hostid']?.toString();
      if (hostIdStr == hostId) {
        final name = host['name']?.toString();
        final hostName = host['host']?.toString();
        return name?.isNotEmpty == true ? name! : (hostName ?? 'Host $hostId');
      }
    }
    // If not found, return a descriptive fallback
    return _hostsCache!.isEmpty ? 'No hosts' : 'Unknown ($hostId)';
  }

  String getHostNameByTriggerId(String triggerId) {
    if (_triggerToHostCache == null) {
      return 'Loading...';
    }
    return _triggerToHostCache![triggerId] ?? 'Unknown trigger';
  }

  // Debug method to see what hosts we have cached
  List<Map<String, dynamic>>? get cachedHosts => _hostsCache;
  
  Future<List<Map<String, dynamic>>> fetchProblems({int? recentSeconds}) async {
    final api = await _ensureApi();
    // Ensure we are authenticated; login if needed
    if (!api.isAuthenticated) {
      await login();
    }
    // Load hosts if not already cached
    if (_hostsCache == null) {
      await loadHosts();
    }
    try {
      final problems = await api.getProblems(recentSeconds: recentSeconds);
      
      // Extract trigger IDs from problems (objectid refers to trigger ID)
      final triggerIds = problems
          .map((p) => p['objectid']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();
      
      // Load trigger-to-host mappings
      if (triggerIds.isNotEmpty) {
        await loadTriggersToHostMapping(triggerIds);
      }
      
      return problems;
    } catch (e) {
      // If authorization failed, try a single re-login and retry once
      final msg = e.toString().toLowerCase();
      if (msg.contains('not authorized') || msg.contains('unauthorized')) {
        await login();
        return await api.getProblems(recentSeconds: recentSeconds);
      }
      rethrow;
    }
  }

  Future<void> acknowledgeEvent({required String eventId, String? message}) async {
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    await api.acknowledgeEvent(eventId: eventId, message: message);
  }

  Future<void> closeEvent({required String eventId}) async {
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    await api.closeEvent(eventId: eventId);
  }

  Future<String> disableTrigger({required String triggerId}) async {
    final api = await _ensureApi();
    if (!api.isAuthenticated) {
      await login();
    }
    try {
      return await api.disableTrigger(triggerId: triggerId);
    } catch (e) {
      // If authorization failed, try a single re-login and retry once
      final msg = e.toString().toLowerCase();
      if (msg.contains('not authorized') || msg.contains('unauthorized')) {
        await login();
        return await api.disableTrigger(triggerId: triggerId);
      }
      rethrow;
    }
  }

  Future<String?> getTriggerConfigUrl(String triggerId) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('zbx_server');
    
    if (serverUrl == null || serverUrl.isEmpty) {
      return null;
    }
    
    return '$serverUrl/zabbix.php?action=trigger.edit&triggerid=$triggerId';
  }
}
