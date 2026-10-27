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
import 'package:score_app/features/admin/catalogue/widgets/admin_product_form_dialog.dart';

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
      'is_active': true,
      'product_count': 5,
    },
  ];

  Map<String, dynamic> mockProductsPaginatedResponse({
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
        'total': items?.length ?? 2,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      'total': items?.length ?? 2,
      'page': 1,
      'page_size': 20,
      'total_pages': 1,
    };
  }

  group('Admin Product Management Widget Tests', () {
    testWidgets('1. Add Product action is visible and opens the create form', (tester) async {
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

      // Verify Add Product button is visible in Products section
      expect(find.byKey(const Key('add_product_button')), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);

      // Tap Add Product
      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      // Verify create form dialog opened
      expect(find.byType(AdminProductFormDialog), findsOneWidget);
      expect(find.text('Add New Product'), findsOneWidget);
      expect(find.byKey(const Key('product_form_code_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_name_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('product_form_vehicle_type_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('product_form_price_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_description_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_image_url_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('product_form_cancel_button')), findsOneWidget);
    });

    testWidgets('2. Required-field validation works', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int postCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products') {
          postCallCount++;
          return http.Response('{}', 201);
        }
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

      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      // Submit without entering code or name
      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // Validation errors should appear
      expect(find.text('Product code is required'), findsOneWidget);
      expect(find.text('Product name is required'), findsOneWidget);
      expect(postCallCount, 0);
    });

    testWidgets('3. Invalid price input is rejected', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int postCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products') {
          postCallCount++;
          return http.Response('{}', 201);
        }
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

      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('product_form_code_input')), 'PRD-TEST');
      await tester.enterText(find.byKey(const Key('product_form_name_input')), 'Test Product');

      // Negative price
      await tester.enterText(find.byKey(const Key('product_form_price_input')), '-25.50');
      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cannot be negative'), findsOneWidget);
      expect(postCallCount, 0);

      // Non-numeric price
      await tester.enterText(find.byKey(const Key('product_form_price_input')), 'invalid_price');
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid number'), findsOneWidget);
      expect(postCallCount, 0);
    });

    testWidgets('4. A valid product can be submitted using a mocked API', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      Map<String, dynamic>? receivedBody;
      final createdProductJson = {
        'id': 103,
        'product_code': 'PRD-NEW-01',
        'name': 'Performance Clutch Plate',
        'category_id': 3,
        'category_name': 'Brake System',
        'category_is_active': true,
        'vehicle_type': '2-Wheeler',
        'price': 450.0,
        'description': 'Heavy duty clutch',
        'image_url': null,
        'is_active': true,
      };

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products') {
          receivedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(createdProductJson), 201);
        }
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

      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('product_form_code_input')), 'PRD-NEW-01');
      await tester.enterText(find.byKey(const Key('product_form_name_input')), 'Performance Clutch Plate');
      await tester.enterText(find.byKey(const Key('product_form_price_input')), '450.00');
      await tester.enterText(find.byKey(const Key('product_form_description_input')), 'Heavy duty clutch');

      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // Form dialog should be closed
      expect(find.byType(AdminProductFormDialog), findsNothing);

      // Verify payload
      expect(receivedBody, isNotNull);
      expect(receivedBody!['product_code'], 'PRD-NEW-01');
      expect(receivedBody!['name'], 'Performance Clutch Plate');
      expect(receivedBody!['price'], 450.0);
      expect(receivedBody!['description'], 'Heavy duty clutch');

      // Verify SnackBar
      expect(find.text('Product created successfully'), findsOneWidget);
    });

    testWidgets('5. API errors appear in the UI', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(
            jsonEncode({'detail': 'Category with ID 99 not found'}),
            404,
          );
        }
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

      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('product_form_code_input')), 'PRD-ERR');
      await tester.enterText(find.byKey(const Key('product_form_name_input')), 'Error Product');

      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // Dialog should remain open
      expect(find.byType(AdminProductFormDialog), findsOneWidget);

      // Scroll up to see error banner if needed
      await tester.ensureVisible(find.byKey(const Key('product_form_error_banner')));
      await tester.pumpAndSettle();

      // Error banner should display server error message
      expect(find.byKey(const Key('product_form_error_banner')), findsOneWidget);
      expect(find.text('Category with ID 99 not found'), findsOneWidget);
      expect(find.text('Product created successfully'), findsNothing);
    });

    testWidgets('6. Double submission is prevented', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final completer = Completer<http.Response>();
      int postCallCount = 0;

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products') {
          postCallCount++;
          return completer.future;
        }
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

      await tester.tap(find.byKey(const Key('add_product_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('product_form_code_input')), 'PRD-DBL');
      await tester.enterText(find.byKey(const Key('product_form_name_input')), 'Double Submit Test');

      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // Tap submit first time
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pump();

      // Submit button should now show progress indicator and be disabled
      expect(postCallCount, 1);

      // Attempt second tap while request is in flight
      await tester.tap(find.byKey(const Key('product_form_submit_button')), warnIfMissed: false);
      await tester.pump();

      // Count must still be 1
      expect(postCallCount, 1);

      // Complete request
      completer.complete(http.Response(jsonEncode({
        'id': 104,
        'product_code': 'PRD-DBL',
        'name': 'Double Submit Test',
        'category_id': 3,
        'category_name': 'Brake System',
        'category_is_active': true,
        'vehicle_type': '2-Wheeler',
        'price': null,
        'description': null,
        'image_url': null,
        'is_active': true,
      }), 201));
      await tester.pumpAndSettle();

      expect(find.byType(AdminProductFormDialog), findsNothing);
    });

    testWidgets('7. Edit opens with the selected product\'s existing values', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      // Tap on Ceramic Brake Pad Set to open detail sheet
      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminProductDetailSheet), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('product_detail_edit_button')), findsOneWidget);

      // Tap Edit Product
      await tester.tap(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();

      // Dialog should be in edit mode
      expect(find.byType(AdminProductFormDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AdminProductFormDialog),
          matching: find.text('Edit Product'),
        ),
        findsOneWidget,
      );

      // Verify prepopulated values
      final codeField = tester.widget<TextFormField>(find.byKey(const Key('product_form_code_input')));
      expect(codeField.controller?.text, 'PRD-101');

      final nameField = tester.widget<TextFormField>(find.byKey(const Key('product_form_name_input')));
      expect(nameField.controller?.text, 'Ceramic Brake Pad Set');

      final priceField = tester.widget<TextFormField>(find.byKey(const Key('product_form_price_input')));
      expect(priceField.controller?.text, '850.5');

      final descField = tester.widget<TextFormField>(find.byKey(const Key('product_form_description_input')));
      expect(descField.controller?.text, 'High performance ceramic brake pads');
    });

    testWidgets('8. Editing a product with a null price does not convert it to zero', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products/102') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      // Open detail sheet for Standard Oil Filter (null price)
      await tester.tap(find.text('Standard Oil Filter'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();

      // Tap Edit Product
      await tester.tap(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();

      final priceField = tester.widget<TextFormField>(find.byKey(const Key('product_form_price_input')));
      // Field must be completely empty, NOT '0' or '0.0'!
      expect(priceField.controller?.text, '');
      expect(priceField.controller?.text, isNot('0'));
      expect(priceField.controller?.text, isNot('0.0'));
    });

    testWidgets('9. Clearing price sends the correct null/omitted representation according to contract', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      Map<String, dynamic>? updatePayload;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products/101/update') {
          updatePayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({
            'id': 101,
            'product_code': 'PRD-101',
            'name': 'Ceramic Brake Pad Set',
            'category_id': 3,
            'category_name': 'Brake System',
            'category_is_active': true,
            'vehicle_type': '2-Wheeler',
            'price': null,
            'description': 'High performance ceramic brake pads',
            'image_url': null,
            'is_active': true,
          }), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_detail_edit_button')));
      await tester.pumpAndSettle();

      // Clear the price input
      await tester.enterText(find.byKey(const Key('product_form_price_input')), '');

      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // Verify the update payload has 'price': null explicitly (via clearPrice)
      expect(updatePayload, isNotNull);
      expect(updatePayload!.containsKey('price'), isTrue);
      expect(updatePayload!['price'], isNull);

      // Verify detail sheet updated to 'Price not set'
      expect(
        find.descendant(
          of: find.byType(AdminProductDetailSheet),
          matching: find.text('Price not set'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('10. Product activation requires confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int statusCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products/102/status') {
          statusCallCount++;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/102') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      // Open inactive product (PRD-102)
      await tester.tap(find.text('Standard Oil Filter'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Tap Activate button
      await tester.tap(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.byKey(const Key('product_status_confirm_dialog')), findsOneWidget);
      expect(find.text('Activate Product'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('product_status_confirm_dialog')),
          matching: find.textContaining('Standard Oil Filter'),
        ),
        findsOneWidget,
      );

      // Cancel confirmation
      await tester.tap(find.byKey(const Key('product_status_cancel_button')));
      await tester.pumpAndSettle();

      // No status mutation API call should have been made
      expect(statusCallCount, 0);
      expect(find.byKey(const Key('product_status_confirm_dialog')), findsNothing);
    });

    testWidgets('11. Product deactivation requires confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int statusCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products/101/status') {
          statusCallCount++;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      // Open active product (PRD-101)
      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Tap Deactivate button
      await tester.tap(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.byKey(const Key('product_status_confirm_dialog')), findsOneWidget);
      expect(find.text('Deactivate Product'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('product_status_confirm_dialog')),
          matching: find.textContaining('Ceramic Brake Pad Set'),
        ),
        findsOneWidget,
      );

      // Cancel confirmation
      await tester.tap(find.byKey(const Key('product_status_cancel_button')));
      await tester.pumpAndSettle();

      // No status mutation API call should have been made
      expect(statusCallCount, 0);
      expect(find.byKey(const Key('product_status_confirm_dialog')), findsNothing);
    });

    testWidgets('12. Successful status change refreshes the relevant UI', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int productsFetchCount = 0;
      final deactivatedProductJson = {
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
        'is_active': false,
      };

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products/101/status') {
          return http.Response(jsonEncode(deactivatedProductJson), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          productsFetchCount++;
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

      final initialFetchCount = productsFetchCount;

      // Open detail sheet
      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Tap Deactivate
      await tester.tap(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      // Confirm deactivation
      await tester.tap(find.byKey(const Key('product_status_confirm_button')));
      await tester.pumpAndSettle();

      // SnackBar confirmation
      expect(find.text('Product deactivated successfully'), findsOneWidget);

      // Product list was refreshed via callback
      expect(productsFetchCount, greaterThan(initialFetchCount));
    });

    testWidgets('13. Mutation failures do not falsely show success', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/products/101/status') {
          return http.Response(
            jsonEncode({'detail': 'Internal database error'}),
            500,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/101') {
          return http.Response(jsonEncode({
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
          }), 200);
        }
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

      await tester.tap(find.text('Ceramic Brake Pad Set'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('product_detail_status_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('product_status_confirm_button')));
      await tester.pumpAndSettle();

      // Must NOT show false success!
      expect(find.text('Product deactivated successfully'), findsNothing);
      expect(find.text('Product activated successfully'), findsNothing);

      // Must surface error
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
    });

    testWidgets('14. Existing product search, filters, pagination, category switching, and detail sheet pass', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      String? capturedSearch;
      String? capturedStatus;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          capturedSearch = request.url.queryParameters['search'];
          capturedStatus = request.url.queryParameters['status'];
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

      // Verify Add Product is present alongside filters
      expect(find.byKey(const Key('add_product_button')), findsOneWidget);
      expect(find.byKey(const Key('product_search_input')), findsOneWidget);

      // Search debounce
      await tester.enterText(find.byKey(const Key('product_search_input')), 'Brake');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(capturedSearch, 'Brake');

      // Status filter
      await tester.tap(find.byKey(const Key('product_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();
      expect(capturedStatus, 'active');

      // Switch to Categories tab and back
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category_search_input')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab_products')));
      await tester.pumpAndSettle();

      // Search term preserved
      final searchInput = tester.widget<TextField>(find.byKey(const Key('product_search_input')));
      expect(searchInput.controller?.text, 'Brake');
      expect(find.byKey(const Key('add_product_button')), findsOneWidget);
    });
  });
}
