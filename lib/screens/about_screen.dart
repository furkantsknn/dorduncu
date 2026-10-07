import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

String _aboutText(
  BuildContext context, {
  required String tr,
  required String en,
  required String de,
}) {
  switch (Localizations.localeOf(context).languageCode.toLowerCase()) {
    case 'en':
      return en;
    case 'de':
      return de;
    default:
      return tr;
  }
}


class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      version = '${info.version} (${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F1115),
      appBar: AppBar(
        backgroundColor: const Color(0xff0F1115),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _aboutText(context, tr: 'Hakkında', en: 'About', de: 'Über'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              Image.asset(
                'assets/branding/dort_logo_white_orange.png',
                width: 190,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 28),
              Text(
                'Oyunun Eksik Oyuncusunu Bul',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff171A20),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: Text(
                  _aboutText(context, tr: 'Dört., insanların oyun, spor ve sosyal etkinlikler için ihtiyaç duydukları eksik oyuncuyu bulmalarını sağlayan bir platformdur.', en: 'Dört. is a platform that helps people find missing players for games, sports and social activities.', de: 'Dört. ist eine Plattform, die Menschen dabei hilft, fehlende Mitspieler für Spiele, Sport und soziale Aktivitäten zu finden.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (version.isNotEmpty)
                Text(
                  _aboutText(context, tr: 'Sürüm $version', en: 'Version $version', de: 'Version $version'),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                '© 2026 Dört.',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}