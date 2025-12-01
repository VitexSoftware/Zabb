import 'dart:convert';
import 'package:http/http.dart' as http;

class ZabbixApi {
  ZabbixApi(this.serverUrl, {http.Client? client}) : _client = client ?? http.Client();

  final String serverUrl; // e.g. https://your-zabbix.example.com
  final http.Client _client;
  String? _authToken;
  int _requestId = 1;

  bool get isAuthenticated => _authToken != null;
  String? get authToken => _authToken;
  Uri get _endpoint {
    var base = serverUrl.trim();
    base = base.replaceAll(RegExp(r"/+$"), "");
    if (base.endsWith('/api_jsonrpc.php')) {
      return Uri.parse(base);
    }
    return Uri.parse('$base/api_jsonrpc.php');
  }

  Future<String> login({required String username, required String password}) async {
    // Some Zabbix versions expect 'username' instead of 'user'
    final response = await _post('user.login', {
      'username': username,
      'password': password,
    });
    if (response['result'] is String) {
      _authToken = response['result'] as String;
      return _authToken!;
    }
    throw ZabbixApiException('Unexpected login response', response);
  }

  Future<void> logout() async {
    if (_authToken == null) return;
    try {
      await _post('user.logout', {}, auth: _authToken);
    } finally {
      _authToken = null;
    }
  }

  Future<Map<String, dynamic>> _post(String method, Map<String, dynamic> params, {String? auth}) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': _requestId++,
    });
    final resp = await _client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (auth != null && auth.isNotEmpty) 'Authorization': 'Bearer $auth',
      },
      body: body,
    );
    if (resp.statusCode != 200) {
      // Print to stdout for easier debugging on Linux
      // ignore: avoid_print
      print('HTTP error ${resp.statusCode}: ${resp.body}');
      throw ZabbixApiException('HTTP ${resp.statusCode}', {'body': resp.body});
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      // Print to stdout for easier debugging on Linux
      // ignore: avoid_print
      print('Zabbix API error: ${jsonEncode(decoded['error'])}');
      throw ZabbixApiException('API error', decoded['error'] as Map<String, dynamic>);
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> getHosts({List<String>? hostIds}) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'output': ['hostid', 'host', 'name', 'status'],
      if (hostIds != null) 'hostids': hostIds,
    };
    final response = await _post('host.get', params, auth: _authToken);
    final result = response['result'];
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    throw ZabbixApiException('Unexpected host.get result', response);
  }

  Future<List<Map<String, dynamic>>> getHostsWithInterfaces() async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'output': ['hostid', 'host', 'name'],
      'selectInterfaces': ['interfaceid', 'ip'],
    };
    final response = await _post('host.get', params, auth: _authToken);
    final result = response['result'];
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    throw ZabbixApiException('Unexpected host.get result', response);
  }

  Future<List<Map<String, dynamic>>> getTriggers({List<String>? triggerIds}) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'output': ['triggerid', 'description'],
      'selectHosts': ['hostid', 'host', 'name'],
      if (triggerIds != null) 'triggerids': triggerIds,
    };
    final response = await _post('trigger.get', params, auth: _authToken);
    final result = response['result'];
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    throw ZabbixApiException('Unexpected trigger.get result', response);
  }

  Future<List<Map<String, dynamic>>> getProblems({int? recentSeconds}) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'output': ['eventid', 'name', 'severity', 'clock', 'objectid'],
      'selectAcknowledges': 'extend',
      'selectTags': 'extend',
      'severities': [0, 1, 2, 3, 4, 5],
      'sortfield': 'eventid',
      'sortorder': 'DESC',
      'recent': true,
      if (recentSeconds != null) 'time_from': DateTime.now().millisecondsSinceEpoch ~/ 1000 - recentSeconds,
    };
    final response = await _post('problem.get', params, auth: _authToken);
    final result = response['result'];
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    throw ZabbixApiException('Unexpected problem.get result', response);
  }

  Future<void> acknowledgeEvent({required String eventId, String? message}) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'eventids': [eventId],
      if (message != null && message.isNotEmpty) 'message': message,
      'action': 2, // acknowledge
    };
    await _post('event.acknowledge', params, auth: _authToken);
  }

  Future<void> closeEvent({required String eventId}) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'eventids': [eventId],
      'action': 1, // close problem
    };
    await _post('event.acknowledge', params, auth: _authToken);
  }
}

class ZabbixApiException implements Exception {
  ZabbixApiException(this.message, this.details);
  final String message;
  final Map<String, dynamic> details;
  @override
  String toString() => 'ZabbixApiException: $message ${jsonEncode(details)}';
}
