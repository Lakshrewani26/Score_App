import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';

void main() {
  group('CatalogueApi', () {
    test('loads active categories from API response', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/categories');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Brake Parts',
              'description': 'Brake system parts'
            },
            {'id': 2, 'name': 'Filters', 'description': null},
          ]),
          200,
        );
      });

      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');
      final categories = await api.loadCategories();

      expect(categories.length, 2);
      expect(categories.first.name, 'Brake Parts');
      expect(categories.last.description, isNull);
    });

    test('parses null price and product pagination correctly', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/products');
        expect(request.url.queryParameters['vehicle_type'], '2-Wheeler');
        expect(request.url.queryParameters['search'], 'filter');
        expect(request.url.queryParameters['category_id'], '3');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['page_size'], '17');

        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 22,
                'category_id': 3,
                'category_name': 'Filters',
                'product_code': 'FLTR-22',
                'name': 'Air Filter',
                'description': 'Air filter for 2-wheelers',
                'vehicle_type': '2-Wheeler',
                'price': null,
                'image_url': null,
              },
            ],
            'pagination': {
              'total': 1,
              'page': 2,
              'page_size': 17,
              'total_pages': 1,
            },
          }),
          200,
        );
      });

      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');
      final page = await api.loadProducts(
        categoryId: 3,
        vehicleType: '2-Wheeler',
        search: 'filter',
        page: 2,
        pageSize: 17,
      );

      expect(page.items.first.displayPrice, 'Price to be confirmed');
      expect(page.pagination.total, 1);
      expect(page.pagination.page, 2);
      expect(page.pagination.pageSize, 17);
      expect(page.pagination.totalPages, 1);
    });

    test('throws a CatalogueApiException for failing HTTP responses', () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');

      await expectLater(
          api.loadProducts(), throwsA(isA<CatalogueApiException>()));
    });

    test('loads a single product detail by id', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/products/99');
        return http.Response(
          jsonEncode({
            'id': 99,
            'category_id': 5,
            'category_name': 'Lighting',
            'product_code': 'LED-99',
            'name': 'LED Headlamp',
            'description': 'Bright headlamp',
            'vehicle_type': '3-Wheeler',
            'price': '1899.50',
            'image_url': 'https://example.com/image.jpg',
          }),
          200,
        );
      });

      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');
      final product = await api.getProduct(99);

      expect(product.name, 'LED Headlamp');
      expect(product.displayPrice, '₹ 1,899.50');
      expect(product.vehicleType, '3-Wheeler');
    });
  });
}
