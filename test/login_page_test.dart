import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/login_page.dart';

void main() {
  testWidgets('Sign in submits security token and JWT', (tester) async {
    String? submittedToken;
    String? capturedToken;
    String? capturedJwt;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          serverUrl: 'https://ghostfol.io',
          edition: 'Ghostfolio',
          authenticate:
              ({required String serverUrl, required String accessToken}) async {
                expect(serverUrl, 'https://ghostfol.io');
                submittedToken = accessToken;
                return 'jwt-test';
              },
          onAuthenticated: (securityToken, jwt) async {
            capturedToken = securityToken;
            capturedJwt = jwt;
          },
        ),
      ),
    );

    final tokenField = find.byType(TextField);
    expect(tokenField, findsOneWidget);

    await tester.enterText(tokenField, ' test-token ');
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Sign in');
    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      submittedToken,
      'test-token',
      reason: 'Authentication service was not invoked',
    );

    expect(
      capturedToken,
      'test-token',
      reason: 'Authenticated callback was not invoked',
    );

    expect(capturedJwt, 'jwt-test');
  });

  testWidgets('LAN HTTP warning appears only for cleartext connections', (
    tester,
  ) async {
    Widget page(String url) => MaterialApp(
      home: LoginPage(
        serverUrl: url,
        edition: 'Ghostfolio',
        onAuthenticated: (_, _) async {},
      ),
    );

    await tester.pumpWidget(page('http://192.168.1.14:3333'));
    expect(find.textContaining('tokens are sent in cleartext'), findsOneWidget);

    await tester.pumpWidget(page('https://ghostfol.io'));
    expect(find.textContaining('tokens are sent in cleartext'), findsNothing);
  });
}
