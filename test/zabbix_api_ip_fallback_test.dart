import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zabb/api/zabbix_api.dart';

http.Response _jsonRpcOk(dynamic result) => http.Response(
      jsonEncode({'jsonrpc': '2.0', 'result': result, 'id': 1}),
      200,
    );

void main() {
  test('falls back to the cached IP and original Host header when DNS fails', () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      if (calls.length == 1) {
        // Hostname attempt: simulate the lookup failing (e.g. Android
        // deprioritizing DNS for a backgrounded foreground service).
        expect(request.url.host, 'my.zabbix.example');
        throw const SocketException("Failed host lookup: 'my.zabbix.example'");
      }
      // Retry attempt: must go out to the cached IP with the original
      // hostname preserved via the Host header, so vhost routing still works.
      expect(request.url.host, '203.0.113.5');
      expect(request.headers['Host'], 'my.zabbix.example');
      return _jsonRpcOk([]);
    });

    final api = ZabbixApi('https://my.zabbix.example', client: client);
    api.useApiToken('test-token');
    api.seedCachedIpForTest('203.0.113.5');

    final result = await api.getHosts();

    expect(result, isEmpty);
    expect(calls.length, 2);
  });

  test('rethrows the friendly network error when there is no cached IP to fall back to', () async {
    final client = MockClient((request) async {
      throw const SocketException("Failed host lookup: 'my.zabbix.example'");
    });

    final api = ZabbixApi('https://my.zabbix.example', client: client);
    api.useApiToken('test-token');

    await expectLater(
      () => api.getHosts(),
      throwsA(isA<ZabbixApiException>().having(
        (e) => e.friendlyMessage,
        'friendlyMessage',
        contains('Cannot reach server'),
      )),
    );
  });
}
