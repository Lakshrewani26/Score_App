import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';

CatalogueApi buildTestCatalogueApi(List<Uri> productRequests) {
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
        final categoryId =
            int.tryParse(request.url.queryParameters['category_id'] ?? '') ?? 1;
        final firstProductId = (page - 1) * 20 + 1;
        final products = List.generate(2, (index) {
          final productId = firstProductId + index;
          return {
            'id': productId,
            'category_id': categoryId,
            'category_name': categoryId == 2 ? 'Filters' : 'Brake Parts',
            'product_code': 'PART-$productId',
            'name': '$vehicleType Part $productId',
            'description': null,
            'vehicle_type': vehicleType,
            'price': '10.00',
            'image_url': null,
          };
        });

        return http.Response(
          jsonEncode({
            'items': products,
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
