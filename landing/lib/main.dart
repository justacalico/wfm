import 'package:flutter/material.dart';
import 'nav.dart';

void main() => runApp(const LandingApp());

class LandingApp extends StatelessWidget {
  const LandingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
            children: [
              Text('WFM',
                  style: TextStyle(
                      fontSize: wide ? 64 : 44,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8B5CF6),
                      height: 1)),
              const SizedBox(height: 16),
              Text(
                'Film projects for a whole class, in one place.',
                style: TextStyle(fontSize: wide ? 28 : 20, fontWeight: FontWeight.w600, height: 1.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'WFM is a self-hosted media manager for school film programs. Students upload '
                'footage, cut in a browser editor, and queue renders. Teachers keep accounts, '
                'permissions and activity under control.',
                style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Wrap(spacing: 12, runSpacing: 12, children: const [
                _Feature(Icons.movie_outlined, 'Edit in the browser',
                    'Timeline editing powered by FilmCraft, no installs needed.'),
                _Feature(Icons.folder_outlined, 'Organized media',
                    'Raw, Audio, Images and Exports folders for every project.'),
                _Feature(Icons.rocket_launch_outlined, 'Server renders',
                    'Queue exports on the server or on remote render nodes.'),
                _Feature(Icons.group_outlined, 'Made for schools',
                    'Student, mod, teacher and admin roles with an audit log.'),
              ]),
              const SizedBox(height: 40),
              Wrap(spacing: 12, children: [
                FilledButton.icon(
                  onPressed: goApp,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open the app'),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Free and open source (AGPL-3.0).',
                  style: TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Feature(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}
