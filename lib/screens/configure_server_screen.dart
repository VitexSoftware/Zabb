import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/services/auth_service.dart';

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
    await prefs.setString('zbx_server', _serverController.text.trim());
    await prefs.setString('zbx_user', _userController.text.trim());
    await prefs.setString('zbx_password', _passwordController.text);
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
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $error')),
      );
    } else {
      Navigator.pop(context, true);
    }
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
