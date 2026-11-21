import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionTitle extends StatefulWidget {
  const AppVersionTitle({super.key});

  @override
  State<AppVersionTitle> createState() => _AppVersionTitleState();
}

class _AppVersionTitleState extends State<AppVersionTitle> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final info = snapshot.data;

        if (info == null) {
          return const Text('Spookyfolio');
        }

        return Text(
          'Spookyfolio ${info.version} - ${info.buildNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
