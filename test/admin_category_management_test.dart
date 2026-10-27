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
import 'package:score_app/features/admin/catalogue/widgets/admin_category_form_dialog.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  final initialCategoriesFixture = [
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
          ],
      'pagination': {
        'total': items?.length ?? 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      },
      'total': items?.length ?? 1,
      'page': 1,
      'page_size': 20,
      'total_pages': 1,
    };
  }

  group('Admin Category Management Widget Tests', () {
    testWidgets('1. Add Category action opens the form', (tester) async {
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
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      // Switch to Categories tab
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Verify Add Category action button is clearly visible
      expect(find.byKey(const Key('add_category_button')), findsOneWidget);
      expect(find.text('Add Category'), findsOneWidget);

      // Tap Add Category button
      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      // Verify reusable form dialog opened with expected fields
      expect(find.byType(AdminCategoryFormDialog), findsOneWidget);
      expect(find.text('Add New Category'), findsOneWidget);
      expect(find.byKey(const Key('category_name_input')), findsOneWidget);
      expect(find.byKey(const Key('category_description_input')), findsOneWidget);
      expect(find.byKey(const Key('category_form_active_switch')), findsOneWidget);
      expect(find.byKey(const Key('category_form_submit_button')), findsOneWidget);
    });

    testWidgets('2. Required-field validation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int createCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories') {
          createCallCount++;
          return http.Response('{}', 201);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      // Switch to Categories tab and open dialog
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      // Attempt submit without filling category name
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Category name is required'), findsOneWidget);
      expect(createCallCount, 0);

      // Attempt submit with whitespace only
      await tester.enterText(find.byKey(const Key('category_name_input')), '     ');
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Category name is required'), findsOneWidget);
      expect(createCallCount, 0);
    });

    testWidgets('3. Successful category creation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final categoriesList = List<Map<String, dynamic>>.from(initialCategoriesFixture);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final newCat = {
            'id': 10,
            'name': body['name'],
            'description': body['description'],
            'is_active': body['is_active'] ?? true,
            'product_count': 0,
          };
          categoriesList.add(newCat);
          return http.Response(jsonEncode(newCat), 201);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(categoriesList), 200);
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

      // Switch to Categories tab
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Open Add Category dialog
      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      // Fill valid fields
      await tester.enterText(find.byKey(const Key('category_name_input')), 'Transmission System');
      await tester.enterText(find.byKey(const Key('category_description_input')), 'Gears and clutches');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pumpAndSettle();

      // Form dialog should be closed
      expect(find.byType(AdminCategoryFormDialog), findsNothing);

      // Success SnackBar should appear
      expect(find.text('Category created successfully'), findsOneWidget);

      // Category list should now contain the new category
      expect(find.text('Transmission System'), findsOneWidget);
      expect(find.text('Gears and clutches'), findsOneWidget);
    });

    testWidgets('4. Duplicate-name/conflict error display', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(
            jsonEncode({'detail': 'A category with this name already exists'}),
            409,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      // Switch to Categories tab
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Open Add Category dialog
      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      // Enter duplicate category name
      await tester.enterText(find.byKey(const Key('category_name_input')), 'Brake System');
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pumpAndSettle();

      // Dialog should remain open
      expect(find.byType(AdminCategoryFormDialog), findsOneWidget);

      // Conflict error banner must display backend detail clearly
      expect(find.byKey(const Key('category_form_error_banner')), findsOneWidget);
      expect(find.text('A category with this name already exists'), findsOneWidget);

      // No false success SnackBar
      expect(find.text('Category created successfully'), findsNothing);
    });

    testWidgets('5. Network/API error handling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(
            jsonEncode({'detail': 'Database connection failed'}),
            500,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('category_name_input')), 'New Category');
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pumpAndSettle();

      // Dialog remains open
      expect(find.byType(AdminCategoryFormDialog), findsOneWidget);

      // Error banner displays
      expect(find.byKey(const Key('category_form_error_banner')), findsOneWidget);
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.text('Category created successfully'), findsNothing);
    });

    testWidgets('6. Double-submission prevention', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final completer = Completer<http.Response>();
      int postCallCount = 0;

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories') {
          postCallCount++;
          return completer.future;
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_category_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('category_name_input')), 'Suspension');

      // Tap submit first time
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pump(); // Render in-flight loading state

      expect(postCallCount, 1);

      // Tap again while in-flight
      await tester.tap(find.byKey(const Key('category_form_submit_button')));
      await tester.pump();

      // Second tap should be blocked
      expect(postCallCount, 1);

      // Resolve the future
      completer.complete(
        http.Response(
          jsonEncode({
            'id': 20,
            'name': 'Suspension',
            'description': null,
            'is_active': true,
            'product_count': 0,
          }),
          201,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminCategoryFormDialog), findsNothing);
      expect(find.text('Category created successfully'), findsOneWidget);
    });

    testWidgets('7. Activation requires confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int statusCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories/4/status') {
          statusCallCount++;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Find inactive category 'Filters' (id: 4) action button
      final activateButton = find.byKey(const Key('category_status_button_4'));
      expect(activateButton, findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);

      // Tap Activate button
      await tester.tap(activateButton);
      await tester.pumpAndSettle();

      // Confirmation dialog must be shown
      expect(find.byKey(const Key('category_status_confirm_dialog')), findsOneWidget);
      expect(find.text('Activate Category'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('category_status_confirm_dialog')),
          matching: find.textContaining('Filters'),
        ),
        findsOneWidget,
      );

      // Tap Cancel button
      await tester.tap(find.byKey(const Key('category_status_cancel_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog dismissed; no API call initiated
      expect(find.byKey(const Key('category_status_confirm_dialog')), findsNothing);
      expect(statusCallCount, 0);
    });

    testWidgets('8. Deactivation requires confirmation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int statusCallCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories/3/status') {
          statusCallCount++;
          return http.Response('{}', 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Find active category 'Brake System' (id: 3) action button
      final deactivateButton = find.byKey(const Key('category_status_button_3'));
      expect(deactivateButton, findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);

      // Tap Deactivate button
      await tester.tap(deactivateButton);
      await tester.pumpAndSettle();

      // Confirmation dialog must appear
      expect(find.byKey(const Key('category_status_confirm_dialog')), findsOneWidget);
      expect(find.text('Deactivate Category'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('category_status_confirm_dialog')),
          matching: find.textContaining('Brake System'),
        ),
        findsOneWidget,
      );

      // Tap Cancel button
      await tester.tap(find.byKey(const Key('category_status_cancel_button')));
      await tester.pumpAndSettle();

      // Dialog dismissed without mutation
      expect(find.byKey(const Key('category_status_confirm_dialog')), findsNothing);
      expect(statusCallCount, 0);
    });

    testWidgets('9. Successful status change refreshes the list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final categoriesList = [
        {
          'id': 3,
          'name': 'Brake System',
          'description': 'Brakes and related components',
          'is_active': true,
          'product_count': 14,
        },
      ];

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories/3/status') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          categoriesList[0]['is_active'] = body['is_active'];
          return http.Response(
            jsonEncode({
              'id': 3,
              'name': 'Brake System',
              'description': 'Brakes and related components',
              'is_active': body['is_active'],
              'product_count': 14,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(categoriesList), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Tap Deactivate button on Brake System
      await tester.tap(find.byKey(const Key('category_status_button_3')));
      await tester.pumpAndSettle();

      // Confirm deactivation
      await tester.tap(find.byKey(const Key('category_status_confirm_button')));
      await tester.pumpAndSettle();

      // Deactivation success SnackBar
      expect(find.text('Category deactivated successfully'), findsOneWidget);

      // Now category button should show Activate
      expect(find.text('Activate'), findsOneWidget);
    });

    testWidgets('10. Failed mutation does not falsely show success', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/v1/admin/catalogue/categories/3/status') {
          return http.Response(
            jsonEncode({'detail': 'Category cannot be modified right now'}),
            500,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Tap Deactivate button on Brake System
      await tester.tap(find.byKey(const Key('category_status_button_3')));
      await tester.pumpAndSettle();

      // Confirm deactivation
      await tester.tap(find.byKey(const Key('category_status_confirm_button')));
      await tester.pumpAndSettle();

      // Error message should be shown
      expect(find.text('Server error. Please try again later.'), findsOneWidget);

      // Must NOT falsely show success
      expect(find.text('Category deactivated successfully'), findsNothing);
      expect(find.text('Category activated successfully'), findsNothing);

      // Category should remain active
      expect(find.text('Deactivate'), findsOneWidget);
    });

    testWidgets('11. Existing category search/status filters remain functional', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final requestedUrls = <Uri>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/categories') {
          requestedUrls.add(request.url);
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(jsonEncode(mockProductsPaginatedResponse()), 200);
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

      // Switch to Categories tab
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();

      // Enter search term
      await tester.enterText(find.byKey(const Key('category_search_input')), 'Filter');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Verify that category search query parameter was sent
      expect(requestedUrls.any((u) => u.queryParameters['search'] == 'Filter'), isTrue);

      // Change category status filter dropdown to 'inactive'
      await tester.tap(find.byKey(const Key('category_status_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive').last);
      await tester.pumpAndSettle();

      // Verify status query parameter was sent
      expect(requestedUrls.any((u) => u.queryParameters['status'] == 'inactive'), isTrue);
    });

    testWidgets('12. Product catalogue and product management regression coverage remains intact',
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
          return http.Response(jsonEncode(initialCategoriesFixture), 200);
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

      // Verify initial products tab is selected and displays products
      expect(find.byKey(const Key('add_product_button')), findsOneWidget);
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);

      // Switch to Categories tab
      await tester.tap(find.byKey(const Key('tab_categories')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add_category_button')), findsOneWidget);
      expect(find.text('Brake System'), findsOneWidget);

      // Switch back to Products tab
      await tester.tap(find.byKey(const Key('tab_products')));
      await tester.pumpAndSettle();

      // Products tab remains completely intact
      expect(find.byKey(const Key('add_product_button')), findsOneWidget);
      expect(find.text('Ceramic Brake Pad Set'), findsOneWidget);
    });
  });
}
