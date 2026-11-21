import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/main.dart';
import 'package:spookyfolio/server_info.dart';

void main() {
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
