import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';
import 'package:score_app/features/customer/catalogue/three_wheeler_parts_screen.dart';

void main() {
  CatalogueApi buildApi() {
    return CatalogueApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/categories') {
          return http.Response(
            jsonEncode([
              {'id': 1, 'name': 'Brake Parts', 'description': 'Brake system parts'},
              {'id': 2, 'name': 'Filters', 'description': null},
            ]),
            200,
          );
        }

        if (request.url.path == '/api/v1/products') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 2,
                  'category_id': 1,
                  'category_name': 'Brake Parts',
                  'product_code': 'BRK-002',
                  'name': 'Brake Shoe',
                  'description': 'Heavy duty brake shoe',
                  'vehicle_type': '3-Wheeler',
                  'price': '320.00',
                  'image_url': null,
                },
              ],
              'pagination': {
                'total': 1,
                'page': 1,
                'page_size': 20,
                'total_pages': 1,
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

  testWidgets('shows API-backed 3-Wheeler product data', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ThreeWheelerPartsScreen(api: buildApi()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3-Wheeler'), findsAtLeastNWidgets(1));
    expect(find.text('Brake Shoe'), findsOneWidget);
    expect(find.textContaining('320.00'), findsOneWidget);
    expect(find.text('Search for parts...'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
