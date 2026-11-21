import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SpookyfolioAboutPage extends StatelessWidget {
  const SpookyfolioAboutPage({super.key, this.embedded = false});

  final bool embedded;

  static const repository = 'https://github.com/piggei/spookyfolio';

  Future<void> _openRepository(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse(repository),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the repository')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = dark
        ? 'assets/branding/splash_dark.png'
        : 'assets/branding/splash_light.png';

    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            key: const ValueKey('about-page'),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Center(
                child: Image.asset(
                  icon,
                  key: const ValueKey('about-logo'),
                  height: 264,
                  width: 264,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Spookyfolio',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => Text(
                  snapshot.hasData
                      ? 'v${snapshot.data!.version} - Build ${snapshot.data!.buildNumber}'
                      : 'Version unavailable',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Independent mobile client for Ghostfolio.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Repository'),
                subtitle: const Text(repository),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openRepository(context),
              ),
              const ListTile(
                leading: Icon(Icons.gavel_outlined),
                title: Text('License'),
                subtitle: Text('GNU AGPL-3.0'),
              ),
            ],
          ),
        ),
      ),
    );
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: content,
    );
  }
}
