import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_catalogue_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_catalogue_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  const dummyToken = 'jwt_test_token_admin_catalogue';

  AdminSessionManager createSessionWithToken([String token = dummyToken]) {
    final storage = InMemoryAdminTokenStorage();
    storage.saveToken(token);
    return AdminSessionManager(tokenStorage: storage);
  }

  // Representative FastAPI fixture matching backend/app/schemas/admin_catalogue.py
  final singleProductFixture = {
    'id': 101,
    'product_code': 'PRD-101',
    'name': 'Ceramic Brake Pad Set',
    'category_id': 3,
    'category_name': 'Brake System',
    'category_is_active': true,
    'vehicle_type': '2-Wheeler',
    'price': '850.50',
    'description': 'High performance ceramic brake pads',
    'image_url': 'https://example.com/images/pad.png',
    'is_active': true,
  };

  final productListFixture = {
    'items': [
      singleProductFixture,
      {
        'id': 102,
        'product_code': 'PRD-102',
        'name': 'Standard Oil Filter',
        'category_id': 4,
        'category_name': 'Filters',
        'category_is_active': true,
        'vehicle_type': '3-Wheeler',
        'price': null,
        'description': null,
        'image_url': null,
        'is_active': false,
      },
    ],
    'pagination': {
      'total': 2,
      'page': 1,
      'page_size': 20,
      'total_pages': 1,
    },
    'total': 2,
    'page': 1,
    'page_size': 20,
    'total_pages': 1,
  };

  final singleCategoryFixture = {
    'id': 3,
    'name': 'Brake System',
    'description': 'Brakes and related components',
    'is_active': true,
    'product_count': 14,
  };

  final categoryListFixture = [
    singleCategoryFixture,
    {
      'id': 4,
      'name': 'Filters',
      'description': null,
      'is_active': false,
      'product_count': 0,
    },
  ];

  group('AdminProduct and AdminCategory Models Unit Tests', () {
    test('AdminProduct parses all fields from JSON correctly', () {
      final product = AdminProduct.fromJson(singleProductFixture);

      expect(product.id, 101);
      expect(product.productCode, 'PRD-101');
      expect(product.name, 'Ceramic Brake Pad Set');
      expect(product.categoryId, 3);
      expect(product.categoryName, 'Brake System');
      expect(product.categoryIsActive, isTrue);
      expect(product.vehicleType, '2-Wheeler');
      expect(product.price, 850.50);
      expect(product.description, 'High performance ceramic brake pads');
      expect(product.imageUrl, 'https://example.com/images/pad.png');
      expect(product.isActive, isTrue);
      expect(product.displayPrice, '₹ 850.50');
    });

    test('AdminProduct handles null price and formats displayPrice as fallback', () {
      final product = AdminProduct.fromJson({
        'id': 102,
        'product_code': 'PRD-102',
        'name': 'Standard Oil Filter',
        'category_id': 4,
        'vehicle_type': '3-Wheeler',
        'price': null,
        'is_active': true,
      });

      expect(product.price, isNull);
      expect(product.displayPrice, 'Price to be confirmed');
    });

    test('AdminProduct correctly formats thousands separator in displayPrice', () {
      final product = AdminProduct.fromJson({
        'id': 103,
        'product_code': 'PRD-103',
        'name': 'Complete Engine Assembly',
        'category_id': 5,
        'vehicle_type': 'Both',
        'price': 125450.75,
        'is_active': true,
      });

      expect(product.price, 125450.75);
      expect(product.displayPrice, '₹ 125,450.75');
    });

    test('AdminProduct equality and hashCode check', () {
      final p1 = AdminProduct.fromJson(singleProductFixture);
      final p2 = AdminProduct.fromJson(singleProductFixture);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('AdminCategory parses JSON correctly with productCount', () {
      final cat = AdminCategory.fromJson(singleCategoryFixture);

      expect(cat.id, 3);
      expect(cat.name, 'Brake System');
      expect(cat.description, 'Brakes and related components');
      expect(cat.isActive, isTrue);
      expect(cat.productCount, 14);
    });

    test('AdminProductUpdateRequest distinguishes unset price from explicit null price', () {
      // 1. Unset price: price field should NOT be in JSON
      const unsetRequest = AdminProductUpdateRequest(
        name: 'Updated Name Only',
      );
      final unsetJson = unsetRequest.toJson();
      expect(unsetJson.containsKey('price'), isFalse);
      expect(unsetJson['name'], 'Updated Name Only');

      // 2. Explicit numeric price: price field is present with value
      const priceRequest = AdminProductUpdateRequest(
        price: 499.00,
      );
      final priceJson = priceRequest.toJson();
      expect(priceJson.containsKey('price'), isTrue);
      expect(priceJson['price'], 499.00);

      // 3. Explicit clearPrice = true: price field is present with null value
      const clearRequest = AdminProductUpdateRequest(
        clearPrice: true,
      );
      final clearJson = clearRequest.toJson();
      expect(clearJson.containsKey('price'), isTrue);
      expect(clearJson['price'], isNull);

      // 4. Convenience factory clearPrice: price field is present with null value
      final factoryClearRequest = AdminProductUpdateRequest.clearPrice(
        name: 'Clear Price Name',
      );
      final factoryClearJson = factoryClearRequest.toJson();
      expect(factoryClearJson.containsKey('price'), isTrue);
      expect(factoryClearJson['price'], isNull);
      expect(factoryClearJson['name'], 'Clear Price Name');
    });

    test('AdminProductCreateRequest serializes expected fields', () {
      const request = AdminProductCreateRequest(
        productCode: 'PRD-NEW',
        name: 'New Spark Plug',
        categoryId: 2,
        vehicleType: '2-Wheeler',
        price: 150.0,
        description: 'Quality spark plug',
        imageUrl: 'https://example.com/spark.png',
        isActive: true,
      );

      final json = request.toJson();
      expect(json['product_code'], 'PRD-NEW');
      expect(json['name'], 'New Spark Plug');
      expect(json['category_id'], 2);
      expect(json['vehicle_type'], '2-Wheeler');
      expect(json['price'], 150.0);
      expect(json['description'], 'Quality spark plug');
      expect(json['image_url'], 'https://example.com/spark.png');
      expect(json['is_active'], isTrue);
    });
  });

  group('Product List API Tests', () {
    test('getAdminProducts parses paginated response correctly', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/catalogue/products');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['page_size'], '20');

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final result = await api.getAdminProducts(page: 1, pageSize: 20);

      expect(result.items.length, 2);
      expect(result.total, 2);
      expect(result.page, 1);
      expect(result.pageSize, 20);
      expect(result.totalPages, 1);
      expect(result.pagination.total, 2);

      final first = result.items.first;
      expect(first.id, 101);
      expect(first.productCode, 'PRD-101');
      expect(first.price, 850.50);

      final second = result.items.last;
      expect(second.id, 102);
      expect(second.price, isNull);
      expect(second.isActive, isFalse);
    });

    test('getAdminProducts handles empty product list', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [],
            'pagination': {
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 0,
            },
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0,
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final result = await api.getAdminProducts();

      expect(result.items, isEmpty);
      expect(result.total, 0);
      expect(result.totalPages, 0);
    });

    test('getAdminProducts correctly serializes page and page size', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['page'], '3');
        expect(request.url.queryParameters['page_size'], '50');

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts(page: 3, pageSize: 50);
    });

    test('getAdminProducts serializes search, category, vehicleType, and status filters', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['search'], 'brake pad');
        expect(request.url.queryParameters['category_id'], '3');
        expect(request.url.queryParameters['vehicle_type'], '2-Wheeler');
        expect(request.url.queryParameters['status'], 'inactive');

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts(
        search: ' brake pad ',
        categoryId: 3,
        vehicleType: '2-Wheeler',
        status: 'inactive',
      );
    });

    test('getAdminProducts preserves hasPrice: false and priceMissing: false', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['has_price'], 'false');
        expect(request.url.queryParameters['price_missing'], 'false');
        expect(request.url.queryParameters['is_active'], 'false');

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts(
        hasPrice: false,
        priceMissing: false,
        isActive: false,
      );
    });

    test('getAdminProducts preserves hasPrice: true and priceMissing: true', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['has_price'], 'true');
        expect(request.url.queryParameters['price_missing'], 'true');
        expect(request.url.queryParameters['is_active'], 'true');

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts(
        hasPrice: true,
        priceMissing: true,
        isActive: true,
      );
    });

    test('getAdminProducts omits unset optional filters and does not send string "null"', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters.containsKey('search'), isFalse);
        expect(request.url.queryParameters.containsKey('category_id'), isFalse);
        expect(request.url.queryParameters.containsKey('vehicle_type'), isFalse);
        expect(request.url.queryParameters.containsKey('status'), isFalse);
        expect(request.url.queryParameters.containsKey('is_active'), isFalse);
        expect(request.url.queryParameters.containsKey('has_price'), isFalse);
        expect(request.url.queryParameters.containsKey('price_missing'), isFalse);
        expect(request.url.query.contains('null'), isFalse);

        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts();
    });

    test('getAdminProducts safely encodes special characters in search', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['search'], 'oil & filter/part#1');
        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts(search: 'oil & filter/part#1');
    });
  });

  group('Product Detail & Mutations API Tests', () {
    test('getAdminProductDetail retrieves and parses single product', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/catalogue/products/101');
        return http.Response(jsonEncode(singleProductFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final product = await api.getAdminProductDetail(101);

      expect(product.id, 101);
      expect(product.name, 'Ceramic Brake Pad Set');
      expect(product.price, 850.50);
    });

    test('createProduct sends POST to /api/v1/admin/catalogue/products with valid JSON', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/products');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['product_code'], 'PRD-101');
        expect(body['name'], 'Ceramic Brake Pad Set');
        expect(body['category_id'], 3);
        expect(body['vehicle_type'], '2-Wheeler');
        expect(body['price'], 850.50);
        expect(body['is_active'], isTrue);

        return http.Response(jsonEncode(singleProductFixture), 201);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      const requestPayload = AdminProductCreateRequest(
        productCode: 'PRD-101',
        name: 'Ceramic Brake Pad Set',
        categoryId: 3,
        vehicleType: '2-Wheeler',
        price: 850.50,
        description: 'High performance ceramic brake pads',
        imageUrl: 'https://example.com/images/pad.png',
        isActive: true,
      );

      final created = await api.createProduct(requestPayload);

      expect(created.id, 101);
      expect(created.name, 'Ceramic Brake Pad Set');
    });

    test('updateProduct sends POST to /api/v1/admin/catalogue/products/{id}/update', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/products/101/update');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Updated Brake Pad');
        expect(body.containsKey('price'), isFalse);

        return http.Response(
          jsonEncode({
            ...singleProductFixture,
            'name': 'Updated Brake Pad',
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final updated = await api.updateProduct(
        101,
        const AdminProductUpdateRequest(name: 'Updated Brake Pad'),
      );

      expect(updated.id, 101);
      expect(updated.name, 'Updated Brake Pad');
    });

    test('updateProduct distinguishes omitted price from explicit price: null over HTTP', () async {
      // Step A: Update with explicit null price
      final clientClearingPrice = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/products/101/update');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('price'), isTrue);
        expect(body['price'], isNull);

        return http.Response(
          jsonEncode({
            ...singleProductFixture,
            'price': null,
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final apiClearing = AdminCatalogueApi(
        client: clientClearingPrice,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final clearedProduct = await apiClearing.updateProduct(
        101,
        const AdminProductUpdateRequest(clearPrice: true),
      );
      expect(clearedProduct.price, isNull);

      // Step B: Update with new numeric price
      final clientSettingPrice = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('price'), isTrue);
        expect(body['price'], 999.0);

        return http.Response(
          jsonEncode({
            ...singleProductFixture,
            'price': 999.0,
          }),
          200,
        );
      });

      final apiSetting = AdminCatalogueApi(
        client: clientSettingPrice,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final setProduct = await apiSetting.updateProduct(
        101,
        const AdminProductUpdateRequest(price: 999.0),
      );
      expect(setProduct.price, 999.0);
    });

    test('updateProductStatus deactivates product via POST to .../status', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/products/101/status');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['is_active'], isFalse);

        return http.Response(
          jsonEncode({
            ...singleProductFixture,
            'is_active': false,
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final deactivated = await api.updateProductStatus(101, false);
      expect(deactivated.isActive, isFalse);
    });

    test('updateProductStatus activates product via POST to .../status', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/products/101/status');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['is_active'], isTrue);

        return http.Response(
          jsonEncode({
            ...singleProductFixture,
            'is_active': true,
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final activated = await api.updateProductStatus(101, true);
      expect(activated.isActive, isTrue);
    });
  });

  group('Category API Tests', () {
    test('getAdminCategories fetches and parses list with status and search filters', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/catalogue/categories');
        expect(request.url.queryParameters['status'], 'active');
        expect(request.url.queryParameters['search'], 'brake');

        return http.Response(jsonEncode(categoryListFixture), 200);
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final categories = await api.getAdminCategories(
        status: 'active',
        search: 'brake',
      );

      expect(categories.length, 2);
      expect(categories.first.id, 3);
      expect(categories.first.name, 'Brake System');
      expect(categories.first.productCount, 14);
      expect(categories.first.isActive, isTrue);

      expect(categories.last.id, 4);
      expect(categories.last.isActive, isFalse);
      expect(categories.last.productCount, 0);
    });

    test('createCategory sends POST to /api/v1/admin/catalogue/categories with valid JSON', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/categories');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Exhaust System');
        expect(body['description'], 'Pipes and mufflers');
        expect(body['is_active'], isTrue);

        return http.Response(
          jsonEncode({
            'id': 10,
            'name': 'Exhaust System',
            'description': 'Pipes and mufflers',
            'is_active': true,
            'product_count': 0,
          }),
          201,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final created = await api.createCategory(
        const AdminCategoryCreateRequest(
          name: 'Exhaust System',
          description: 'Pipes and mufflers',
          isActive: true,
        ),
      );

      expect(created.id, 10);
      expect(created.name, 'Exhaust System');
      expect(created.productCount, 0);
    });

    test('updateCategoryStatus sends POST to /api/v1/admin/catalogue/categories/{id}/status', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/catalogue/categories/3/status');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['is_active'], isFalse);

        return http.Response(
          jsonEncode({
            ...singleCategoryFixture,
            'is_active': false,
          }),
          200,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final updated = await api.updateCategoryStatus(3, false);
      expect(updated.id, 3);
      expect(updated.isActive, isFalse);
    });
  });

  group('Authentication and Error Handling Tests', () {
    test('Every request includes current Bearer token in Authorization header', () async {
      const secretToken = 'secret_bearer_token_xyz999';
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer $secretToken');
        return http.Response(jsonEncode(productListFixture), 200);
      });

      final session = createSessionWithToken(secretToken);
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      await api.getAdminProducts();
    });

    test('Missing token fails safely before making network call', () async {
      final client = MockClient((request) async {
        fail('HTTP request should not be initiated when token is missing');
      });

      final emptyStorage = InMemoryAdminTokenStorage();
      final emptySession = AdminSessionManager(tokenStorage: emptyStorage);
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: emptySession,
      );

      expect(
        () => api.getAdminProducts(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'No authentication token provided'),
        ),
      );
    });

    test('HTTP 401 Unauthorized surfaces safe error and never leaks token', () async {
      const secretToken = 'super_secret_jwt_token_401';
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid or expired session token'}),
          401,
        );
      });

      final session = createSessionWithToken(secretToken);
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      try {
        await api.getAdminProducts();
        fail('Should throw AdminApiException');
      } on AdminApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, 'Invalid or expired session token');
        expect(e.toString().contains(secretToken), isFalse);
      }
    });

    test('HTTP 403 Forbidden surfaces safe admin access denied error', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Admin privileges required'}),
          403,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.getAdminProducts(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Admin privileges required'),
        ),
      );
    });

    test('HTTP 404 Not Found surfaces resource not found error with detail', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Product not found'}),
          404,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.getAdminProductDetail(9999),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Product not found'),
        ),
      );
    });

    test('HTTP 409 Conflict surfaces duplicate category error', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'A category with this name already exists'}),
          409,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.createCategory(
          const AdminCategoryCreateRequest(name: 'Duplicate Category'),
        ),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'A category with this name already exists',
              ),
        ),
      );
    });

    test('HTTP 422 Unprocessable Entity extracts validation message from detail list', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'price'],
                'msg': 'Price cannot be negative',
                'type': 'value_error',
              }
            ],
          }),
          422,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.createProduct(
          const AdminProductCreateRequest(
            productCode: 'BAD-PRICE',
            name: 'Negative Price Product',
            categoryId: 1,
            vehicleType: '2-Wheeler',
            price: -50,
          ),
        ),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message', 'Price cannot be negative'),
        ),
      );
    });

    test('HTTP 500 does not return fake success and gives generic server error', () async {
      final client = MockClient((request) async {
        return http.Response(
          'Internal Server Error with stack trace /home/user/app.py',
          500,
        );
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.getAdminProducts(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'Server error. Please try again later.'),
        ),
      );
    });

    test('ClientException (network drop) surfaces network error without fake success', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.getAdminProducts(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.message, 'message', contains('Network error')),
        ),
      );
    });

    test('TimeoutException surfaces timeout error without fake success', () async {
      final client = MockClient((request) async {
        throw TimeoutException('Request timed out after 30s');
      });

      final session = createSessionWithToken();
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      expect(
        () => api.getAdminProducts(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.message, 'message', contains('Connection timed out')),
        ),
      );
    });

    test('Token values never appear in AdminApiException string or message', () async {
      const secretToken = 'super_confidential_jwt_token_987654';
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Some error'}), 400);
      });

      final session = createSessionWithToken(secretToken);
      final api = AdminCatalogueApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      try {
        await api.getAdminProducts();
      } on AdminApiException catch (e) {
        expect(e.message.contains(secretToken), isFalse);
        expect(e.toString().contains(secretToken), isFalse);
      }
    });
  });

  group('AdminApi Catalogue Delegation Tests', () {
    test('AdminApi forwards catalogue calls to AdminCatalogueApi seamlessly', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(productListFixture), 200);
        } else if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(categoryListFixture), 200);
        }
        return http.Response('Not found', 404);
      });

      final session = createSessionWithToken();
      final adminApi = AdminApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: session,
      );

      final products = await adminApi.getAdminProducts();
      expect(products.items.length, 2);

      final categories = await adminApi.getAdminCategories();
      expect(categories.length, 2);
    });
  });
}
