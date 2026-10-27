import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/catalogue/admin_catalogue_screen.dart';
import 'package:score_app/features/admin/catalogue/widgets/admin_product_detail_sheet.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  final mockCategoriesFixture = [
    {
      'id': 3,
      'name': 'Brake System',
      'description': 'Brakes and related components',
      'is_active': true,
      'product_count': 14,
    },
    {
      'id': 4,
      'name': 'Filters',
      'description': 'Air and oil filtration components',
      'is_active': false,
      'product_count': 5,
    },
  ];

  Map<String, dynamic> mockProductsPaginatedResponse({
    int total = 2,
    int page = 1,
    int pageSize = 20,
    int totalPages = 1,
    List<Map<String, dynamic>>? items,
  }) {
    return {
      'items': items ??
          [
            {
              'id': 101,
              'product_code': 'PRD-101',
              'name': 'Ceramic Brake Pad Set',
              'category_id': 3,
              'category_name': 'Brake System',
              'category_is_active': true,
              'vehicle_type': '2-Wheeler',
              'price': 850.50,
              'description': 'High performance ceramic brake pads',
              'image_url': null,
              'is_active': true,
            },
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
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
      },
      'total': total,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
    };
  }

  group('Admin Catalogue Screen Tests', () {
    testWidgets('1. Dashboard Catalogue Management card opens catalogue screen and back navigation works',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
            adminApi: adminApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Catalogue Management tile is present
      expect(find.text('Catalogue Management'), findsOneWidget);

      await tester.ensureVisible(find.text('Catalogue Management'));
      await tester.pumpAndSettle();

      // Tap Catalogue Management
      await tester.tap(find.text('Catalogue Management'));
      await tester.pumpAndSettle();

      // Verify AdminCatalogueScreen is displayed
      expect(find.byType(AdminCatalogueScreen), findsOneWidget);
      expect(find.text('Manage products and categories'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byKey(const Key('admin_catalogue_back_button')));
      await tester.pumpAndSettle();

      // Verify returned to AdminHomeScreen
      expect(find.byType(AdminHomeScreen), findsOneWidget);
    });

    testWidgets('2. Products and Categories sections switch correctly and preserve state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Products section
      expect(find.byKey(const Key('product_search_input')), findsOneWidget);
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);

      // Enter search text in Products
      await tester.enterText(find.byKey(const Key('product_search_input')), 'Ceramic');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Switch to Categories section
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Now on Categories section
      expect(find.byKey(const Key('category_search_input')), findsOneWidget);
      expect(find.text('Brake System'), findsOneWidget);

      // Switch back to Products section
      await tester.tap(find.byKey(const Key('tab_products')));
      await tester.pumpAndSettle();

      // Products search query is preserved
      final searchField = tester.widget<TextField>(find.byKey(const Key('product_search_input')));
      expect(searchField.controller?.text, 'Ceramic');
    });

    testWidgets('3. Product loading state renders indicator during asynchronous fetch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final productsCompleter = Completer<http.Response>();

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return productsCompleter.future;
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pump();

      // Verify loading state is visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading products...'), findsOneWidget);

      // Complete response
      productsCompleter.complete(http.Response(jsonEncode(mockProductsPaginatedResponse()), 200));
      await tester.pumpAndSettle();

      // Loading is finished
      expect(find.text('Loading products...'), findsNothing);
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);
    });

    testWidgets('4. Product list renders representative typed models and required fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product 1
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);
      expect(find.text('PRD-101'), findsOneWidget);
      expect(find.text('Brake System'), findsWidgets);
      expect(find.text('2-Wheeler'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Product 2
      expect(find.text('Standard Oil Filter'), findsOneWidget);
      expect(find.text('PRD-102'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('3-Wheeler'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('5. Null prices display correctly and never appear as zero', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product 1 has price 850.50
      expect(find.text('₹ 850.50'), findsOneWidget);

      // Product 2 has price null -> neutral label
      expect(find.text('Price not set'), findsOneWidget);

      // Verify null price NEVER appears as ₹ 0 or ₹ 0.00
      expect(find.text('₹ 0'), findsNothing);
      expect(find.text('₹ 0.00'), findsNothing);
    });

    testWidgets('6. Empty product response shows an empty state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(
            jsonEncode(mockProductsPaginatedResponse(total: 0, totalPages: 0, items: [])),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No products found'), findsOneWidget);
      expect(find.text('Try adjusting your search query or filters'), findsOneWidget);
    });

    testWidgets('7. API failure shows an error and retry action recovers data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      var failRequests = true;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          if (failRequests) {
            return http.Response(jsonEncode({'detail': 'Failed to load products'}), 400);
          }
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error message and retry button are shown
      expect(find.text('Failed to load products'), findsOneWidget);
      expect(find.byKey(const Key('product_retry_button')), findsOneWidget);

      // Now allow request to succeed and tap Retry
      failRequests = false;
      await tester.tap(find.byKey(const Key('product_retry_button')));
      await tester.pumpAndSettle();

      // Products are now shown and error is cleared
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);
      expect(find.byKey(const Key('product_retry_button')), findsNothing);
    });

    testWidgets('8. Search and filter changes request page 1 with the correct parameters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final capturedParams = <Map<String, String>>[];

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          capturedParams.add(Map<String, String>.from(request.url.queryParameters));
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial call page = 1
      expect(capturedParams.first['page'], '1');

      // Test Search filter
      await tester.enterText(find.byKey(const Key('product_search_input')), 'brake');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(capturedParams.last['search'], 'brake');
      expect(capturedParams.last['page'], '1');

      // Test Vehicle Type filter
      await tester.tap(find.byKey(const Key('product_vehicle_type_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2-Wheeler').last);
      await tester.pumpAndSettle();
      expect(capturedParams.last['vehicle_type'], '2-Wheeler');
      expect(capturedParams.last['page'], '1');

      // Test Status filter
      await tester.tap(find.byKey(const Key('product_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      expect(capturedParams.last['status'], 'active');
      expect(capturedParams.last['page'], '1');

      // Test Price filter (Price Missing)
      await tester.tap(find.byKey(const Key('product_price_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price Missing').last);
      await tester.pumpAndSettle();
      expect(capturedParams.last['price_missing'], 'true');
      expect(capturedParams.last['page'], '1');
    });

    testWidgets('9. Pagination requests the correct page', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final requestedPages = <int>[];

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          final page = int.parse(request.url.queryParameters['page'] ?? '1');
          requestedPages.add(page);

          return http.Response(
            jsonEncode(mockProductsPaginatedResponse(
              page: page,
              total: 35,
              totalPages: 2,
            )),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedPages.last, 1);
      expect(find.text('Page 1 of 2 (35 total)'), findsOneWidget);

      // Tap Next page
      await tester.tap(find.byKey(const Key('product_next_page_button')));
      await tester.pumpAndSettle();
      expect(requestedPages.last, 2);
      expect(find.text('Page 2 of 2 (35 total)'), findsOneWidget);

      // Tap Prev page
      await tester.tap(find.byKey(const Key('product_prev_page_button')));
      await tester.pumpAndSettle();
      expect(requestedPages.last, 1);
      expect(find.text('Page 1 of 2 (35 total)'), findsOneWidget);
    });

    testWidgets('10. Category list renders backend-provided category values and counts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Categories
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Category 1
      expect(find.text('Brake System'), findsOneWidget);
      expect(find.text('Brakes and related components'), findsOneWidget);
      expect(find.text('14 Products'), findsOneWidget);

      // Category 2
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Air and oil filtration components'), findsOneWidget);
      expect(find.text('5 Products'), findsOneWidget);
    });

    testWidgets('11. Category search and status filtering sends correct query parameters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final capturedCategoryParams = <Map<String, String>>[];

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          capturedCategoryParams.add(Map<String, String>.from(request.url.queryParameters));
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Categories
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Search in Categories
      await tester.enterText(find.byKey(const Key('category_search_input')), 'oil');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(capturedCategoryParams.last['search'], 'oil');

      // Filter by Status in Categories
      await tester.tap(find.byKey(const Key('category_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      expect(capturedCategoryParams.last['status'], 'active');
    });

    testWidgets('category filter failure is visible and retryable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
        token: 'active_token',
        user: mockAdminUser,
      );

      var categoryRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          categoryRequests++;
          if (categoryRequests == 1) {
            return http.Response(
              jsonEncode({'detail': 'Category service unavailable'}),
              503,
            );
          }
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_filter_error')), findsOneWidget);
      await tester.tap(find.byKey(const Key('category_filter_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category_filter_error')), findsNothing);
      expect(categoryRequests, 3);
    });

    testWidgets('12. Detail selection fetches and displays the selected product in detail sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      var detailApiCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(mockCategoriesFixture), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          detailApiCalled = true;
          return http.Response(
            jsonEncode({
              'id': 101,
              'product_code': 'PRD-101',
              'name': 'Ceramic Brake Pad Set',
              'category_id': 3,
              'category_name': 'Brake System',
              'category_is_active': true,
              'vehicle_type': '2-Wheeler',
              'price': 850.50,
              'description': 'High performance ceramic brake pads',
              'image_url': null,
              'is_active': true,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCatalogueScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Ceramic Brake Pad Set
      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      // Verify detail sheet is displayed
      expect(find.byType(AdminProductDetailSheet), findsOneWidget);
      expect(find.text('Product Details'), findsOneWidget);
      expect(detailApiCalled, isTrue);

      // Verify detail fields
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('High performance ceramic brake pads'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.byKey(const Key('product_detail_close_button')));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.byType(AdminProductDetailSheet), findsNothing);
    });
  });
}
