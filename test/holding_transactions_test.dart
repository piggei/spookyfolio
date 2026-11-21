import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/activity_models.dart';
import 'package:spookyfolio/holding_transactions.dart';
import 'package:spookyfolio/portfolio_client.dart';

void main() {
  test('holding activities use both upstream filters and pagination', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/activities');
        expect(request.url.queryParameters, {
          'skip': '20',
          'take': '20',
          'sortColumn': 'date',
          'sortDirection': 'desc',
          'symbol': 'VWCE.MI',
          'dataSource': '4534c002',
        });
        expect(request.headers['authorization'], 'Bearer test-jwt');
        return http.Response(
          jsonEncode({'activities': [], 'count': 0}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final result = await api.getHoldingActivities(
      serverUrl: 'https://ghostfol.io',
      jwt: 'test-jwt',
      dataSource: '4534c002',
      symbol: 'VWCE.MI',
      skip: 20,
      take: 20,
    );
    expect(result.activities, isEmpty);
  });

  test('invalid holding filters are rejected before network', () async {
    final api = PortfolioClient(
      clientFactory: () => MockClient((_) async {
        fail('No request expected');
      }),
    );
    await expectLater(
      api.getHoldingActivities(
        serverUrl: 'https://ghostfol.io',
        jwt: 'token',
        dataSource: 'bad/source',
        symbol: 'VWCE.MI',
      ),
      throwsFormatException,
    );
    await expectLater(
      api.getHoldingActivities(
        serverUrl: 'https://ghostfol.io',
        jwt: 'token',
        dataSource: '4534c002',
        symbol: '',
      ),
      throwsFormatException,
    );
  });

  testWidgets('holding transaction list shows server records', (tester) async {
    final api = _FakeClient();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HoldingTransactions(
              serverUrl: 'https://ghostfol.io',
              jwt: 'test',
              dataSource: '4534c002',
              symbol: 'VWCE.MI',
              client: api,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('1 transactions'), findsOneWidget);
    expect(find.text('VWCE.MI'), findsOneWidget);
    expect(api.requestedSource, '4534c002');
    expect(api.requestedSymbol, 'VWCE.MI');
  });
}

class _FakeClient extends PortfolioClient {
  String? requestedSource;
  String? requestedSymbol;

  @override
  Future<ActivityBatch> getHoldingActivities({
    required String serverUrl,
    required String jwt,
    required String dataSource,
    required String symbol,
    int skip = 0,
    int take = 20,
  }) async {
    requestedSource = dataSource;
    requestedSymbol = symbol;
    return ActivityBatch(
      activities: [
        PortfolioActivity(
          id: '1',
          date: DateTime(2026, 11, 16),
          type: 'BUY',
          name: 'ETF',
          symbol: 'VWCE.MI',
          currency: 'EUR',
          quantity: 1,
          unitPrice: 169.1,
          value: 169.1,
          fee: 0,
        ),
      ],
      count: 1,
    );
  }
}
