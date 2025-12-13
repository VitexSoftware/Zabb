import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Zabb logo - 70% of screen width
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7 * 0.4,
                child: SvgPicture.asset(
                  'assets/zabb.svg',
                  fit: BoxFit.contain,
                  placeholderBuilder: (context) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Text('SVG Loading...')),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Zabb',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Monitor your Zabbix servers from your phone.\nLet\'s configure your server to get started.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/configure');
                  },
                  child: const Text('Configure Server'),
                ),
              ),
              const SizedBox(height: 24),
              // nymfette3-smile.png - 70% of screen width
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.width * 0.7 * 0.5,
                child: Image.asset(
                  'assets/nymfette3-smile.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: Text('PNG Error')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Link to Vitex Software
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://vitexsoftware.com');
                  try {
                    await launchUrl(url);
                  } catch (e) {
                    // Handle any errors
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error opening website: $e'),
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'by Vitex Software',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
