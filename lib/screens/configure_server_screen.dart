import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/api/zabbix_api.dart';
import 'package:zabb/services/auth_service.dart';
import 'package:zabb/services/certificate_trust_store.dart';

class ConfigureServerScreen extends StatefulWidget {
  const ConfigureServerScreen({super.key});

  @override
  State<ConfigureServerScreen> createState() => _ConfigureServerScreenState();
}

class _ConfigureServerScreenState extends State<ConfigureServerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    _serverController.text = prefs.getString('zbx_server') ?? '';
    _userController.text = prefs.getString('zbx_user') ?? '';
    _passwordController.text = prefs.getString('zbx_password') ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _serverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    final server = _serverController.text.trim();
    await prefs.setString('zbx_server', server);
    await prefs.setString('zbx_user', _userController.text.trim());
    await prefs.setString('zbx_password', _passwordController.text);
    AuthService.instance.resetApi();
    // Attempt login to validate credentials before marking configured
    String? error;
    try {
      await AuthService.instance.login();
      await prefs.setBool('zbx_configured', true);
    } catch (e) {
      error = e.toString();
      await prefs.setBool('zbx_configured', false);
    }
    setState(() => _saving = false);
    if (!mounted) return;

    if (error != null && _looksLikeCertificateError(error)) {
      final trusted = await _offerToTrustCertificate(server);
      if (trusted) {
        // Certificate now trusted — retry with the same credentials.
        return _save();
      }
    }

    if (error != null) {
      // Show a more detailed error dialog instead of just a snackbar
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Failed'),
          content: SingleChildScrollView(
            child: Text(
              error!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      // Configuration successful - navigate directly to problems screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/problems',
        (route) => false,
      );
    }
  }

  bool _looksLikeCertificateError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('certificate') ||
        lower.contains('handshakeexception') ||
        lower.contains('certificate_verify_failed');
  }

  /// Probes the server's presented certificate and, if the user confirms
  /// its fingerprint, stores it as trusted for this host. Returns true if
  /// the user chose to trust it.
  Future<bool> _offerToTrustCertificate(String server) async {
    final cert = await ZabbixApi.probeUntrustedCertificate(server);
    if (cert == null || !mounted) return false;

    final fingerprint = ZabbixApi.fingerprintOf(cert);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Untrusted Certificate'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This server presented a certificate that isn\'t signed by a '
                'recognized authority (e.g. a self-signed certificate). Only '
                'trust it if you recognize this fingerprint, ideally verified '
                'out-of-band with your Zabbix administrator.',
              ),
              const SizedBox(height: 12),
              Text('Subject: ${cert.subject}', style: const TextStyle(fontSize: 12)),
              Text('Issuer: ${cert.issuer}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              SelectableText(
                'SHA-256: $fingerprint',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trust This Certificate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    await CertificateTrustStore.trust(server, fingerprint);
    AuthService.instance.resetApi();
    return true;
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Zabbix Server')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://your-zabbix.example.com',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Server URL is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Password is required'
                      : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save and Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
