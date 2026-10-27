import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';
import 'package:score_app/features/customer/catalogue/catalogue_product_list_screen.dart';
import 'package:score_app/features/customer/catalogue/three_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/catalogue/two_wheeler_parts_screen.dart';

void main() {
  CatalogueApi buildApi(List<Uri> productRequests) {
    return CatalogueApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/categories') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Brake Parts', 'description': null},
              {'id': 2, 'name': 'Filters', 'description': null},
            ]),
            200,
          );
        }

        if (request.url.path == '/api/v1/products') {
          productRequests.add(request.url);
          final page = int.parse(request.url.queryParameters['page']!);
          final vehicleType = request.url.queryParameters['vehicle_type']!;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': page,
                  'category_id': 1,
                  'category_name': 'Brake Parts',
                  'product_code': 'PART-$page',
                  'name': 'Page $page $vehicleType Part',
                  'description': null,
                  'vehicle_type': vehicleType,
                  'price': '10.00',
                  'image_url': null,
                },
              ],
              'pagination': {
                'total': 45,
                'page': page,
                'page_size': 20,
                'total_pages': 3,
              },
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      }),
      baseUrl: 'http://localhost',
    );
  }

  Future<void> showCatalogue(
    WidgetTester tester,
    Widget screen,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> goToNextPage(WidgetTester tester) async {
    final next = find.byKey(const Key('catalogue-next-page'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  testWidgets('2-Wheeler page navigation stops at the last page',
      (tester) async {
    final requests = <Uri>[];
    await showCatalogue(
      tester,
      TwoWheelerPartsScreen(api: buildApi(requests)),
    );

    expect(requests.single.queryParameters['page'], '1');
    expect(requests.single.queryParameters['page_size'], '20');
    expect(requests.single.queryParameters['vehicle_type'], '2-Wheeler');
    expect(find.text('Page 1 of 3 · 45 products'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-previous-page')),
          )
          .onPressed,
      isNull,
    );

    await goToNextPage(tester);
    expect(requests.last.queryParameters['page'], '2');
    expect(find.text('Page 2 of 3 · 45 products'), findsOneWidget);

    await goToNextPage(tester);
    expect(requests.last.queryParameters['page'], '3');
    expect(find.text('Page 3 of 3 · 45 products'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-next-page')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('search and category filters reset and persist across pages', (
    tester,
  ) async {
    final requests = <Uri>[];
    await showCatalogue(
      tester,
      TwoWheelerPartsScreen(api: buildApi(requests)),
    );

    await goToNextPage(tester);
    await tester.enterText(find.byType(TextField), 'brake');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters['page'], '1');
    expect(requests.last.queryParameters['search'], 'brake');

    final categoryFilter = find.byType(DropdownButton<int?>);
    await tester.ensureVisible(categoryFilter);
    await tester.tap(categoryFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters').last);
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters['page'], '1');
    expect(requests.last.queryParameters['search'], 'brake');
    expect(requests.last.queryParameters['category_id'], '2');

    await goToNextPage(tester);
    expect(requests.last.queryParameters['page'], '2');
    expect(requests.last.queryParameters['search'], 'brake');
    expect(requests.last.queryParameters['category_id'], '2');
  });

  testWidgets('3-Wheeler screen uses the shared pagination controls', (
    tester,
  ) async {
    final requests = <Uri>[];
    await showCatalogue(
      tester,
      ThreeWheelerPartsScreen(api: buildApi(requests)),
    );

    expect(requests.single.queryParameters['vehicle_type'], '3-Wheeler');
    await goToNextPage(tester);
    expect(requests.last.queryParameters['vehicle_type'], '3-Wheeler');
    expect(requests.last.queryParameters['page'], '2');
    expect(find.text('Page 2 of 3 · 45 products'), findsOneWidget);
  });

  testWidgets('changing vehicle filter resets to page 1', (tester) async {
    final requests = <Uri>[];
    final api = buildApi(requests);
    await showCatalogue(
      tester,
      CatalogueProductListScreen(
        api: api,
        vehicleType: '2-Wheeler',
        title: '2-Wheeler',
        heroCaption: 'Parts',
      ),
    );

    await goToNextPage(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogueProductListScreen(
          api: api,
          vehicleType: '3-Wheeler',
          title: '3-Wheeler',
          heroCaption: 'Parts',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters['vehicle_type'], '3-Wheeler');
    expect(requests.last.queryParameters['page'], '1');
    expect(find.text('Page 1 of 3 · 45 products'), findsOneWidget);
  });

  testWidgets('empty result shows zero products and disables navigation', (
    tester,
  ) async {
    final api = CatalogueApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/categories') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({
            'items': <dynamic>[],
            'pagination': {
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 0,
            },
          }),
          200,
        );
      }),
      baseUrl: 'http://localhost',
    );

    await showCatalogue(
      tester,
      TwoWheelerPartsScreen(api: api),
    );

    expect(find.text('No products match your search.'), findsOneWidget);
    expect(find.text('Page 1 of 0 · 0 products'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-previous-page')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-next-page')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('only one product request is active during filter changes', (
    tester,
  ) async {
    final requests = <Uri>[];
    final initialProductsResponse = Completer<http.Response>();
    var activeProductRequests = 0;
    var maximumConcurrentProductRequests = 0;
    final api = CatalogueApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/categories') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Brake Parts', 'description': null},
            ]),
            200,
          );
        }

        requests.add(request.url);
        activeProductRequests++;
        if (activeProductRequests > maximumConcurrentProductRequests) {
          maximumConcurrentProductRequests = activeProductRequests;
        }
        try {
          if (requests.length == 1) {
            return await initialProductsResponse.future;
          }
          return http.Response(
            jsonEncode({
              'items': <dynamic>[],
              'pagination': {
                'total': 0,
                'page': int.parse(request.url.queryParameters['page']!),
                'page_size': 20,
                'total_pages': 0,
              },
            }),
            200,
          );
        } finally {
          activeProductRequests--;
        }
      }),
      baseUrl: 'http://localhost',
    );

    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: TwoWheelerPartsScreen(api: api)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'brake');
    await tester.pump(const Duration(milliseconds: 350));
    expect(requests, hasLength(1));

    initialProductsResponse.complete(
      http.Response(
        jsonEncode({
          'items': <dynamic>[],
          'pagination': {
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0,
          },
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.last.queryParameters['search'], 'brake');
    expect(maximumConcurrentProductRequests, 1);
  });
}
