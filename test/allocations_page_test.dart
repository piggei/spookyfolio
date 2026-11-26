import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spookyfolio/allocations_page.dart';
import 'package:spookyfolio/allocation_chart.dart';
import 'package:spookyfolio/portfolio_allocations.dart';
import 'package:spookyfolio/allocation_world_map.dart';
import 'package:spookyfolio/portfolio_client.dart';

import 'support/local_map_bundle.dart';

Map<String, dynamic> portfolio([bool restricted = false]) => jsonDecode(
  File(
    'test/fixtures/dashboard_portfolio${restricted ? '_restricted' : ''}.json',
  ).readAsStringSync(),
) as Map<String, dynamic>;

Future<void> showContent(
  WidgetTester tester,
  Map<String, dynamic> data, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8250DF),
          brightness: brightness,
        ),
      ),
      home: DefaultAssetBundle(
        bundle: LocalMapBundle(),
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: AllocationsContent(
              snapshot: PortfolioSnapshot.fromJson(data),
              baseCurrency: 'EUR',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder panel(String id) => find.byKey(ValueKey('allocation-card-$id'));
Future<void> reveal(WidgetTester tester, String id) async {
  await tester.scrollUntilVisible(
    panel(id),
    400,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('allocations-page')),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'all 13 representations use Phase 1 outputs and the genuine map asset',
    (tester) async {
      await showContent(tester, portfolio());
      expect(
        find.byKey(const ValueKey('net-worth-proportion')),
        findsOneWidget,
      );
      expect(find.text('50.00%'), findsOneWidget);
      final titles = {
        'net-worth': 'Proportion of Net Worth',
        'platform': 'By Platform',
        'currency': 'By Currency',
        'asset-class': 'By Asset Class',
        'holding': 'By Holding',
        'sector': 'By Sector',
        'continent': 'By Continent',
        'market': 'By Market',
        'regions': 'Regions / World Map',
        'country': 'By Country',
        'account': 'By Account',
        'etf-provider': 'By ETF Provider',
        'etf-holding': 'By ETF Holding',
      };
      for (final entry in titles.entries) {
        await reveal(tester, entry.key);
        expect(
          find.descendant(
            of: panel(entry.key),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Experimental · Approximate'), findsOneWidget);
      expect(
        find.textContaining('not a complete reconstruction'),
        findsNothing,
      );
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const PageStorageKey('allocations-page')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await reveal(tester, 'regions');
      expect(
        find.byKey(const ValueKey('allocation-world-map')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel('regions'),
          matching: find.text('Regional total: 1000.00 EUR'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel('regions'),
          matching: find.text('Total exposure: 900.00 EUR'),
        ),
        findsNothing,
      );
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('allocation-world-map')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as AllocationMapPainter;
      expect(painter.geometry.countries, hasLength(177));
      expect(
        painter.geometry.countries
            .singleWhere((country) => country.id == 'DE')
            .path
            .contains(const Offset(193.4, 37.5)),
        isTrue,
      );
      expect(
        painter.geometry.countries
            .singleWhere((country) => country.id == 'US')
            .path
            .contains(const Offset(80, 50)),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'class hierarchy and category inspection preserve identifiers and values',
    (tester) async {
      await showContent(tester, portfolio());
      await reveal(tester, 'asset-class');
      await tester.tap(find.text('Subclasses (1)').first);
      await tester.pumpAndSettle();
      expect(find.text('ETF'), findsWidgets);
      await reveal(tester, 'holding');
      await tester.tap(
        find.byKey(const ValueKey('allocation-row-holding-FUND')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Identifier: FUND'), findsOneWidget);
      expect(find.text('Data sources: YAHOO, MANUAL'), findsOneWidget);
      expect(find.textContaining('Combined exposure'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
    },
  );

  testWidgets(
    'restricted charts use fractions without substituting monetary values',
    (tester) async {
      await showContent(tester, portfolio(true));
      expect(
        find.text('Percentage-only data · monetary values unavailable'),
        findsOneWidget,
      );
      await reveal(tester, 'currency');
      final value = tester.widget<Text>(
        find.byKey(const ValueKey('allocation-value-currency-USD')),
      );
      expect(value.data, '80.00%');
      expect(
        find.descendant(
          of: panel('currency'),
          matching: find.textContaining(' EUR'),
        ),
        findsNothing,
      );
      await reveal(tester, 'etf-holding');
      expect(find.text('10.00% of portfolio'), findsOneWidget);
      expect(
        find.text('Funds with available composition: 80.00%'),
        findsOneWidget,
      );
    },
  );

  testWidgets('null money stays unavailable when other amounts are known', (
    tester,
  ) async {
    final body = portfolio();
    body['holdings'][0]['valueInBaseCurrency'] = null;
    await showContent(tester, body);
    await reveal(tester, 'currency');
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('allocation-value-currency-USD')),
          )
          .data,
      'Unavailable',
    );
    expect(
      find.descendant(
        of: panel('currency'),
        matching: find.textContaining('Missing values are not counted as zero'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: panel('currency'),
        matching: find.textContaining('80.00%'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'known UNKNOWN totals and incomplete weight sums have different disclosures',
    (tester) async {
      await showContent(tester, portfolio());
      await reveal(tester, 'country');
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.text('Total exposure: 900.00 EUR'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.text('Includes unknown or unclassified exposure.'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.text('Classification complete.'),
        ),
        findsNothing,
      );
      final body = portfolio();
      body['holdings'] = [body['holdings'][0]];
      body['holdings'][0]['assetProfile']['countries'] = [
        {'code': 'US', 'continent': 'North America', 'weight': .5},
      ];
      await showContent(tester, body);
      await reveal(tester, 'country');
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.text('Total exposure: 600.00 EUR'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.text('Unknown / unclassified'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: panel('country'),
          matching: find.byKey(const ValueKey('allocation-donut')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'ETF coverage gaps remain visible and are never described as complete look-through',
    (tester) async {
      final body = portfolio();
      body['holdings'][1]['assetProfile']['holdings'] = [];
      await showContent(tester, body);
      await reveal(tester, 'etf-holding');
      expect(find.text('Missing composition (1)'), findsOneWidget);
      expect(
        find.text('Funds with available composition: 600.00 EUR'),
        findsOneWidget,
      );
      await tester.tap(find.text('Missing composition (1)'));
      await tester.pumpAndSettle();
      expect(find.text('MANUAL:FUND'), findsOneWidget);
      expect(find.text('Experimental · Approximate'), findsOneWidget);
    },
  );

  testWidgets(
    'map supports accessible value selection and explicit unmapped countries',
    (tester) async {
      final body = portfolio();
      body['holdings'][0]['assetProfile']['countries'] = [
        {'code': 'SG', 'name': 'Singapore', 'continent': 'Asia', 'weight': 1},
      ];
      await showContent(tester, body);
      await reveal(tester, 'regions');
      expect(find.textContaining('Not outlined at this scale:'), findsNothing);
      expect(find.textContaining('Grey: no reported value'), findsNothing);
      expect(find.text('Country exposure · excludes cash'), findsNothing);
      expect(
        find.text('Uses a separate market total, which may include cash.'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('allocation-country-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('allocation-country-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SG · Singapore').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('allocation-map-selection')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('allocation-map-selection')),
          matching: find.text('600.00 EUR'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('allocation-world-map')),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty and unavailable breakdowns have distinct states', (
    tester,
  ) async {
    await showContent(tester, {
      'holdings': [],
      'accounts': <String, dynamic>{},
      'platforms': <String, dynamic>{},
    });
    expect(
      find.text('No holdings available for allocation analysis.'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsWidgets);
    await reveal(tester, 'platform');
    expect(
      find.descendant(
        of: panel('platform'),
        matching: find.text('No allocation data.'),
      ),
      findsOneWidget,
    );
    await reveal(tester, 'market');
    expect(
      find.descendant(
        of: panel('market'),
        matching: find.text('This breakdown is unavailable from the server.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('long category lists expand without clipping values', (
    tester,
  ) async {
    final body = portfolio();
    body['holdings'] = [
      for (var i = 0; i < 30; i++)
        {
          'assetProfile': {
            'symbol': 'SYMBOL-$i',
            'name': 'A long descriptive asset name number $i',
            'currency': 'EUR',
          },
          'valueInBaseCurrency': 123456789.12345,
          'allocationInPercentage': 1 / 30,
        },
    ];
    await showContent(tester, body);
    await reveal(tester, 'holding');
    final button = find.descendant(
      of: panel('holding'),
      matching: find.text('Show all 30 categories'),
    );
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('allocations-page')),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('allocation-row-holding-SYMBOL-29')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: panel('holding'),
        matching: find.text('123456789.12 EUR'),
      ),
      findsNWidgets(30),
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'narrow screen with enlarged text supports all cards in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await showContent(
          tester,
          portfolio(),
          brightness: brightness,
          scale: 1.8,
        );
        for (final id in [
          'net-worth',
          'platform',
          'currency',
          'asset-class',
          'holding',
          'sector',
          'continent',
          'market',
          'regions',
          'country',
          'account',
          'etf-provider',
          'etf-holding',
        ]) {
          await reveal(tester, id);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'net-worth proportion uses the server value including zero and missing values',
    (tester) async {
      final data = portfolio();
      data['summary']['filteredValueInPercentage'] = .123456;
      await showContent(tester, data);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('net-worth-proportion')))
            .data,
        '12.35%',
      );
      data['summary']['filteredValueInPercentage'] = 0;
      await showContent(tester, data);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('net-worth-proportion')))
            .data,
        '0.00%',
      );
      data['summary'].remove('filteredValueInPercentage');
      await showContent(tester, data);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('net-worth-proportion')))
            .data,
        'Unavailable',
      );
    },
  );

  testWidgets(
    'unit selection includes standalone platform and market contracts',
    (tester) async {
      await showContent(tester, {
        'holdings': [],
        'platforms': {
          'p': {'name': 'Platform', 'valueInPercentage': 1},
        },
      });
      await reveal(tester, 'platform');
      expect(
        tester
            .widget<AllocationChart>(
              find.byKey(const ValueKey('allocation-chart-platform')),
            )
            .data
            .unit,
        AllocationUnit.fraction,
      );
      expect(
        find.descendant(of: panel('platform'), matching: find.text('100.00%')),
        findsOneWidget,
      );
      await showContent(tester, {
        'holdings': [],
        'marketsAdvanced': {
          'northAmerica': {
            'id': 'northAmerica',
            'valueInBaseCurrency': 12,
            'valueInPercentage': .5,
          },
        },
      });
      await reveal(tester, 'market');
      expect(
        tester
            .widget<AllocationChart>(
              find.byKey(const ValueKey('allocation-chart-market')),
            )
            .data
            .unit,
        AllocationUnit.baseCurrency,
      );
      expect(
        find.descendant(of: panel('market'), matching: find.text('12.00 EUR')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'category inspection exposes one accessible value and a tap action',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await showContent(tester, portfolio());
        await reveal(tester, 'holding');
        final value = find.bySemanticsLabel('iShares World, 800.00 EUR');
        expect(value, findsOneWidget);
        expect(
          tester
              .getSemantics(value)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await tester.tap(value);
        await tester.pumpAndSettle();
        expect(find.text('Identifier: FUND'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    },
  );

  final directory = Platform.environment['ALLOCATION_PREVIEW_DIR'];
  final fontDirectory = Platform.environment['ALLOCATION_PREVIEW_FONTS'];
  if (directory != null && fontDirectory != null) {
    testWidgets('rendered allocation previews', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('PreviewRoboto');
        for (final name in [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ]) {
          font.addFont(
            Future.value(
              ByteData.sublistView(
                File('$fontDirectory/$name').readAsBytesSync(),
              ),
            ),
          );
        }
        await font.load();
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(
                ByteData.sublistView(
                  File('$fontDirectory/MaterialIcons-Regular.otf')
                      .readAsBytesSync(),
                ),
              ),
            ))
            .load();
      });
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'PreviewRoboto',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF8250DF),
                brightness: brightness,
              ),
            ),
            home: Scaffold(
              body: DefaultAssetBundle(
                bundle: LocalMapBundle(),
                child: Builder(
                  builder: (context) => RepaintBoundary(
                    key: const ValueKey('preview'),
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: AllocationsContent(
                        snapshot: PortfolioSnapshot.fromJson(portfolio()),
                        baseCurrency: 'EUR',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> save(String name) async {
          final boundary = tester.renderObject(
            find.byKey(const ValueKey('preview')),
          ) as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$directory/allocations-$name-${brightness.name}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await save('top');
        await reveal(tester, 'regions');
        await save('map');
      }
    });
  }
}
