import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';
import 'package:score_app/features/partner/catalogue/partner_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';

import 'catalogue_test_support.dart';

void main() {
  Future<void> pumpCatalogue(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('loads API products and starts quantities at zero', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpCatalogue(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    expect(find.byType(PartnerTwoWheelerCatalogueScreen), findsOneWidget);
    expect(find.text('2-Wheeler Part 1'), findsOneWidget);
    expect(find.text('Search for parts...'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(requests.single.queryParameters['vehicle_type'], '2-Wheeler');
    expect(requests.single.queryParameters['page'], '1');
    expect(requests.single.queryParameters['page_size'], '20');
    expect(find.text('0'), findsNWidgets(2));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('quantity-minus-1')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a safe error and retries after a network failure', (
    tester,
  ) async {
    var failFirstRequest = true;
    final api = CatalogueApi(
      baseUrl: 'http://127.0.0.1:8000',
      client: MockClient((request) async {
        if (failFirstRequest) {
          failFirstRequest = false;
          throw http.ClientException('Connection refused', request.url);
        }
        if (request.url.path == '/api/v1/categories') {
          return http.Response(
            '[{"id":1,"name":"Brake Parts","description":null}]',
            200,
          );
        }
        return http.Response(
          '{"items":[],"pagination":{"total":0,"page":1,"page_size":20,"total_pages":0}}',
          200,
        );
      }),
    );

    await pumpCatalogue(
      tester,
      PartnerTwoWheelerCatalogueScreen(api: api),
    );

    expect(find.text('Unable to load catalogue data.'), findsOneWidget);
    expect(find.textContaining('Connection refused'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No products match your search.'), findsOneWidget);
    expect(find.text('Unable to load catalogue data.'), findsNothing);
  });

  testWidgets('quantity increases and cannot decrement below zero', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpCatalogue(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    await tester.tap(find.byKey(const Key('quantity-plus-1')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quantity-minus-1')));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('quantity-minus-1')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('back navigation returns to partner catalogue selector', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpCatalogue(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerProductCatalogueScreen), findsOneWidget);
  });
}
