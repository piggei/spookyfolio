import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/main.dart';
import 'package:spookyfolio/server_info.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Connection branding follows $brightness theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: ConnectionPage(
            inspect: (_) async => const ServerInfo(isGhostfolioNg: true),
          ),
        ),
      );

      final image = tester.widget<Image>(
        find.byKey(const ValueKey('connection-branding')),
      );

      final expectedAsset = brightness == Brightness.dark
          ? 'assets/branding/splash_dark.png'
          : 'assets/branding/splash_light.png';

      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, expectedAsset);
      expect(image.width, 100);
      expect(image.height, 100);
      expect(image.fit, BoxFit.contain);
    });
  }

  testWidgets('Identifies Ghostfolio NG', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionPage(
          inspect: (_) async => const ServerInfo(isGhostfolioNg: true),
        ),
      ),
    );

    await tester.tap(find.text('Check connection'));
    await tester.pumpAndSettle();

    expect(find.text('Ghostfolio NG'), findsOneWidget);
    expect(find.text('Server identified successfully'), findsOneWidget);
  });

  testWidgets('Identifies standard Ghostfolio', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConnectionPage(
          inspect: (_) async => const ServerInfo(isGhostfolioNg: false),
        ),
      ),
    );

    await tester.tap(find.text('Check connection'));
    await tester.pumpAndSettle();

    expect(find.text('Ghostfolio'), findsOneWidget);
  });
}
