import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/registration_client.dart';
import 'package:spookyfolio/registration_page.dart';
import 'package:spookyfolio/session_store.dart';

void main() {
  testWidgets(
    'registration saves credentials once and confirms the token before entering app',
    (tester) async {
      var requests = 0;
      var saves = 0;
      SavedCredentials? stored;
      String? finalToken;
      String? finalJwt;

      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationPage(
            serverUrl: 'https://ghostfol.io',
            onBack: () {},
            register: ({required serverUrl}) async {
              expect(serverUrl, 'https://ghostfol.io');
              requests++;
              return const RegistrationResult(
                securityToken: 'secret-token',
                jwt: 'session-jwt',
              );
            },
            saveCredentials: (credentials) async {
              saves++;
              stored = credentials;
            },
            onRegistered: (token, jwt) async {
              finalToken = token;
              finalJwt = jwt;
            },
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(saves, 1);
      expect(stored?.securityToken, 'secret-token');
      expect(stored?.serverUrl, 'https://ghostfol.io');
      expect(find.text('secret-token'), findsOneWidget);
      expect(finalToken, isNull);

      await tester.tap(find.text('I have saved my security token'));
      await tester.pumpAndSettle();
      final continueButton = find.widgetWithText(
        FilledButton,
        'Continue to Spookyfolio',
      );
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(finalToken, 'secret-token');
      expect(finalJwt, 'session-jwt');
      expect(saves, 1);
    },
  );
}
