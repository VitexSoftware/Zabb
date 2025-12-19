import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/screens/problems_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/welcome_screen.dart';
import 'screens/configure_server_screen.dart';
import 'services/auth_service.dart';
import 'background/zabbix_foreground_task.dart';
import 'services/notification_service.dart';
import 'services/notification_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background monitoring services
  await ZabbixBackgroundTaskManager.initialize();
  await NotificationService.instance.initialize();

  // Check if the app was launched from a notification
  final launchPayload = await NotificationService.instance.getLaunchNotification();
  if (launchPayload != null) {
    NotificationHandlerService.instance.handleNotification(launchPayload);
  }
  
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
  const _RootRouter();

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
  bool _backgroundMonitoringStarted = false;

  Future<void> _launchGitHubUrl(BuildContext context) async {
    final url = Uri.parse('https://github.com/VitexSoftware/Zabb');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open GitHub: $e')),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Zabb'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zabb', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
              const SizedBox(height: 8),
              Text('Version 0.5.1', style: TextStyle(color: colorScheme.secondary)),
              const SizedBox(height: 8),
              const Text('Flutter-based mobile client for Zabbix monitoring'),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('GitHub Repository'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
                onPressed: () => _launchGitHubUrl(context),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Attempt autologin if credentials are present
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    if (_autoTried) return;
    _autoTried = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('zbx_server') ?? '';
      final user = prefs.getString('zbx_user') ?? '';
      final pass = prefs.getString('zbx_password') ?? '';
      final configured = prefs.getBool('zbx_configured') ?? false;
      
      print('AutoLogin - Configured: $configured, Server: $server, User: $user');
      
      if (configured && server.isNotEmpty && user.isNotEmpty && pass.isNotEmpty) {
        print('AutoLogin - Attempting login...');
        final token = await AuthService.instance.login();
        if (!mounted) return;
        
        print('AutoLogin - Login successful, token: ${token.substring(0, 8)}...');
        
        // Start background monitoring after successful login
        await _startBackgroundMonitoring();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authenticated. Token: ${token.substring(0, 8)}...')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProblemsScreen()),
        );
      } else {
        print('AutoLogin - Skipped (not configured or missing credentials)');
      }
    } catch (e, stackTrace) {
      print('AutoLogin - Error: $e');
      print('AutoLogin - Stack trace: $stackTrace');
      if (!mounted) return;
      
      // Show a more detailed error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Autologin failed: $e'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Configure',
            onPressed: () {
              Navigator.pushNamed(context, '/configure');
            },
          ),
        ),
      );
    }
  }

  Future<void> _startBackgroundMonitoring() async {
    if (_backgroundMonitoringStarted) {
      print('Background monitoring already started, skipping...');
      return;
    }
    
    try {
      // Request battery optimization exemption
      await ZabbixBackgroundTaskManager.requestIgnoreBatteryOptimization();
      
      // Start background monitoring
      final started = await ZabbixBackgroundTaskManager.startMonitoring();
      if (started && mounted) {
        _backgroundMonitoringStarted = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background monitoring started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start background monitoring: $e')),
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
              } else if (value == 'about') {
                _showAboutDialog(context);
              } else if (value == 'settings') {
                Navigator.pushNamed(context, '/configure');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Server settings'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'reset',
                child: Text('Reset configuration'),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Text('About'),
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
              width: 640,
              height: 640,
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
                      // Stop background monitoring on logout
                      await ZabbixBackgroundTaskManager.stopMonitoring();
                      setState(() => _token = null);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Logged out and monitoring stopped')),
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
