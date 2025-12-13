import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ZabbixApi {
  ZabbixApi(this.serverUrl, {http.Client? client}) : _client = client ?? _createClient();

  final String serverUrl; // e.g. https://your-zabbix.example.com
  final http.Client _client;
  String? _authToken;
  int _requestId = 1;

  static http.Client _createClient() {
    final client = HttpClient();
    // Allow bad certificates for testing - in production, you should use proper certificates
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    // Set a reasonable timeout
    client.connectionTimeout = const Duration(seconds: 30);
    // Add more debugging
    client.findProxy = (uri) {
      print('Looking up proxy for: $uri');
      return 'DIRECT';
    };
    return IOClient(client);
  }

  bool get isAuthenticated => _authToken != null;
  String? get authToken => _authToken;
  Uri get _endpoint {
    var base = serverUrl.trim();
    base = base.replaceAll(RegExp(r"/+$"), "");
    
    // Add IP fallback for zabbix.spojenet.cz to bypass DNS issues
    if (base.contains('zabbix.spojenet.cz')) {
      base = base.replaceAll('zabbix.spojenet.cz', '77.87.240.70');
      print('Using IP fallback: $base');
    }
    
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
    
    print('Making request to: $_endpoint');
    print('Method: $method');
    
    try {
      final resp = await _client.post(
        _endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (auth != null && auth.isNotEmpty) 'Authorization': 'Bearer $auth',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));
      
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
    } catch (e) {
      if (e is ZabbixApiException) rethrow;
      
      // Handle common network errors with user-friendly messages
      String userMessage = 'Network error: ${e.toString()}';
      if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        userMessage = 'Cannot reach server. Please check:\n• Internet connection\n• Server URL is correct\n• Server is accessible from your network';
      } else if (e.toString().contains('TimeoutException')) {
        userMessage = 'Connection timeout. Server may be slow or unreachable.';
      } else if (e.toString().contains('HandshakeException') || e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        userMessage = 'SSL certificate error. Server certificate may be invalid or self-signed.';
      }
      
      throw ZabbixApiException(userMessage, {'original_error': e.toString(), 'endpoint': _endpoint.toString()});
    }
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

  Future<Map<String, dynamic>?> getProblemById(String eventId) async {
    if (_authToken == null) {
      throw ZabbixApiException('Not authenticated', {});
    }
    final params = {
      'output': ['eventid', 'name', 'severity', 'clock', 'objectid'],
      'selectAcknowledges': 'extend',
      'selectTags': 'extend',
      'eventids': [eventId],
    };
    final response = await _post('problem.get', params, auth: _authToken);
    final result = response['result'];
    if (result is List && result.isNotEmpty) {
      return result.first as Map<String, dynamic>;
    }
    return null;
  }
}

class ZabbixApiException implements Exception {
  ZabbixApiException(this.message, this.details);
  final String message;
  final Map<String, dynamic> details;
  @override
  String toString() => 'ZabbixApiException: $message ${jsonEncode(details)}';
}
