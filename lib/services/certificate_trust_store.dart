import 'package:shared_preferences/shared_preferences.dart';
import '../api/zabbix_api.dart';

/// Persists per-server certificate trust decisions the user has explicitly
/// made (e.g. "yes, trust this self-signed certificate"), keyed by hostname.
/// One fingerprint per host is kept — trusting a new certificate for a host
/// replaces any previous one.
class CertificateTrustStore {
  static String _keyFor(String host) => 'trusted_cert_sha256_$host';

  static Future<Set<String>> loadTrustedFingerprints(String serverUrl) async {
    final host = ZabbixApi.hostFromUrl(serverUrl);
    if (host == null) return const <String>{};
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = prefs.getString(_keyFor(host));
    return fingerprint == null ? const <String>{} : {fingerprint};
  }

  static Future<void> trust(String serverUrl, String fingerprint) async {
    final host = ZabbixApi.hostFromUrl(serverUrl);
    if (host == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(host), fingerprint);
  }

  static Future<void> forget(String serverUrl) async {
    final host = ZabbixApi.hostFromUrl(serverUrl);
    if (host == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(host));
  }
}
