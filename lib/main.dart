import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/screens/problems_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/configure_server_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const ZabbixApp());
}

class ZabbixApp extends StatelessWidget {
  const ZabbixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zabb',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/configure': (context) => const ConfigureServerScreen(),
        '/login': (context) => const LoginScreen(),
        '/problems': (context) => const ProblemsScreen(),
      },
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter({super.key});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  Future<bool> _isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('zbx_configured') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isConfigured(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final configured = snapshot.data!;
        if (!configured) {
          return const WelcomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _autoTried = false;

  @override
  void initState() {
    super.initState();
    // Attempt autologin if credentials are present
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    if (_autoTried) return;
    _autoTried = true;
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('zbx_server') ?? '';
    final user = prefs.getString('zbx_user') ?? '';
    final pass = prefs.getString('zbx_password') ?? '';
    final configured = prefs.getBool('zbx_configured') ?? false;
    if (configured && server.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
      try {
        final token = await AuthService.instance.login();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authenticated. Token: ${token.substring(0, 8)}...')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProblemsScreen()),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Autologin failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset('assets/zabb.svg', height: 24, width: 24),
            const SizedBox(width: 8),
            const Text('Login'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Server settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/configure');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'reset') {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('zbx_configured', false);
                await prefs.remove('zbx_server');
                await prefs.remove('zbx_user');
                await prefs.remove('zbx_password');
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/welcome');
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'reset',
                child: Text('Reset configuration'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _LoginButton(),
          ),
          // Bottom left corner image
          Positioned(
            bottom: 16,
            left: 16,
            child: Image.asset(
              'assets/nymfette3-smile.png',
              width: 64,
              height: 64,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatefulWidget {
  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _loading = false;
  String? _token;

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthService.instance.login();
      setState(() => _token = token);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Authenticated. Token: ${token.substring(0, 8)}...')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProblemsScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
            Text('Logged in'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await AuthService.instance.logout();
                      setState(() => _token = null);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Logged out')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Logout failed: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: _loading ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Logout'),
          ),
        ],
      );
    }
    return ElevatedButton(
      onPressed: _loading ? null : _doLogin,
      child: _loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Login to Zabbix'),
    );
  }
}
