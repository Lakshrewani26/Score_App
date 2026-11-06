import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_catalogue_api.dart';
import 'package:score_app/core/services/admin_reports_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/catalogue/widgets/admin_product_detail_sheet.dart';
import 'package:score_app/features/admin/reports/admin_reports_screen.dart';
import 'package:score_app/features/admin/users/admin_zone_management_screen.dart';
import 'package:score_app/features/admin/users/widgets/create_customer_dialog.dart';
import 'package:score_app/features/admin/users/widgets/edit_user_dialog.dart';
import 'package:score_app/features/admin/users/widgets/user_detail_sheet.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  group('Admin Phase A: Create Customer Dialog Tests', () {
    testWidgets('Validates required fields and creates customer successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool customerCreated = false;
      bool apiCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/customers') {
          apiCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Ramesh Customer');
          expect(body['mobile'], '9876543211');
          expect(body['password'], 'SecurePass123');
          expect(body['state'], 'Maharashtra');
          expect(body['city'], 'Pune');
          expect(body['segment'], 'Retail');

          return http.Response(
            jsonEncode({
              'id': 201,
              'name': 'Ramesh Customer',
              'mobile': '9876543211',
              'role': 'customer',
              'is_active': true,
              'created_at': '2026-11-01T10:00:00',
              'state': 'Maharashtra',
              'city': 'Pune',
              'segment': 'Retail',
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => CreateCustomerDialog(
                    adminApi: adminApi,
                    token: 'admin_test_token',
                    onSuccess: () {
                      customerCreated = true;
                    },
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('submit_create_customer_button')), findsOneWidget);

      // Attempt submit without filling fields
      await tester.tap(find.byKey(const Key('submit_create_customer_button')));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Mobile number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Fill in fields
      await tester.enterText(find.byKey(const Key('customer_name_field')), 'Ramesh Customer');
      await tester.enterText(find.byKey(const Key('customer_mobile_field')), '9876543211');
      await tester.enterText(find.byKey(const Key('customer_password_field')), 'SecurePass123');
      await tester.enterText(find.byKey(const Key('customer_state_field')), 'Maharashtra');
      await tester.enterText(find.byKey(const Key('customer_city_field')), 'Pune');
      await tester.enterText(find.byKey(const Key('customer_segment_field')), 'Retail');

      await tester.tap(find.byKey(const Key('submit_create_customer_button')));
      await tester.pumpAndSettle();

      expect(apiCalled, isTrue);
      expect(customerCreated, isTrue);
    });
  });

  group('Admin Phase E: Zone Management Screen Tests', () {
    testWidgets('Renders zones list, adds a zone, and toggles zone active status', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final zonesList = [
        {
          'id': 1,
          'name': 'North Zone',
          'description': 'Northern regional distribution',
          'is_active': true,
          'partner_count': 14,
          'created_at': '2026-10-01T00:00:00',
        },
        {
          'id': 2,
          'name': 'South Zone',
          'description': 'Southern territory',
          'is_active': false,
          'partner_count': 5,
          'created_at': '2026-10-02T00:00:00',
        },
      ];

      bool createCalled = false;
      bool statusToggleCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/zones' && request.method == 'GET') {
          return http.Response(
            jsonEncode({'items': zonesList, 'total': 2}),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/zones' && request.method == 'POST') {
          createCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'East Zone');
          expect(body['description'], 'Eastern territory');
          return http.Response(
            jsonEncode({
              'id': 3,
              'name': 'East Zone',
              'description': 'Eastern territory',
              'is_active': true,
              'partner_count': 0,
              'created_at': '2026-11-06T12:00:00',
            }),
            201,
          );
        }
        if (request.url.path == '/api/v1/admin/zones/1/status' && request.method == 'POST') {
          statusToggleCalled = true;
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'North Zone',
              'description': 'Northern regional distribution',
              'is_active': false,
              'partner_count': 14,
              'created_at': '2026-10-01T00:00:00',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);
      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: session);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminZoneManagementScreen(
            adminApi: adminApi,
            sessionManager: session,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Zone Management'), findsOneWidget);
      expect(find.text('North Zone'), findsOneWidget);
      expect(find.text('14 Partners'), findsOneWidget);
      expect(find.text('South Zone'), findsOneWidget);
      expect(find.text('5 Partners'), findsOneWidget);

      // Toggle status of North Zone (id: 1) -> opens confirmation dialog
      await tester.tap(find.byKey(const Key('toggle_zone_btn_1')));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate Zone'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(statusToggleCalled, isTrue);

      // Open Add Zone Dialog
      await tester.tap(find.byKey(const Key('admin_add_zone_button')));
      await tester.pumpAndSettle();

      expect(find.text('Create New Zone'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('create_zone_name_field')), 'East Zone');
      await tester.enterText(find.byKey(const Key('create_zone_desc_field')), 'Eastern territory');

      await tester.tap(find.byKey(const Key('submit_create_zone_button')));
      await tester.pumpAndSettle();

      expect(createCalled, isTrue);
    });
  });

  group('Admin Phase A & E: Edit User Dialog Tests', () {
    testWidgets('Partner edit dialog loads zones and submits updated details with zoneId', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool updateCalled = false;
      AdminUserSummary? updatedResult;

      final zonesList = [
        {
          'id': 10,
          'name': 'West Zone',
          'description': 'Western Region',
          'is_active': true,
          'partner_count': 8,
          'created_at': '2026-10-01T00:00:00',
        },
      ];

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/zones') {
          return http.Response(
            jsonEncode({'items': zonesList, 'total': 1}),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/users/105' && request.method == 'PUT') {
          updateCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Updated Partner Name');
          expect(body['business_name'], 'Updated Garage Ltd');
          expect(body['zone_id'], 10);

          return http.Response(
            jsonEncode({
              'id': 105,
              'name': 'Updated Partner Name',
              'mobile': '9822334455',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-10-25T10:00:00',
              'business_name': 'Updated Garage Ltd',
              'partner_code': 'PRT999',
              'zone_id': 10,
              'zone_name': 'West Zone',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost');

      const userSummary = AdminUserSummary(
        id: 105,
        name: 'Initial Partner',
        mobile: '9822334455',
        role: 'partner',
        isActive: true,
        businessName: 'Initial Garage',
        partnerCode: 'PRT999',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => EditUserDialog(
                    user: userSummary,
                    adminApi: adminApi,
                    token: 'admin_test_token',
                    onSuccess: (res) {
                      updatedResult = res;
                    },
                  ),
                ),
                child: const Text('Open Edit Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Edit PARTNER Account'), findsOneWidget);

      // Edit name and business name
      await tester.enterText(find.byKey(const Key('edit_user_name_field')), 'Updated Partner Name');
      await tester.enterText(find.byKey(const Key('edit_partner_business_name_field')), 'Updated Garage Ltd');

      // Select zone from dropdown
      final dropdownFinder = find.byKey(const Key('edit_partner_zone_dropdown'));
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('West Zone').last);
      await tester.pumpAndSettle();

      // Submit changes
      final submitBtnFinder = find.byKey(const Key('submit_edit_user_button'));
      await tester.ensureVisible(submitBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(updateCalled, isTrue);
      expect(updatedResult?.name, 'Updated Partner Name');
      expect(updatedResult?.zoneId, 10);
      expect(updatedResult?.zoneName, 'West Zone');
    });
  });

  group('Admin Phase A: UserDetailSheet Delete Action Tests', () {
    testWidgets('Prompts confirmation and safely deletes or deactivates user', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool userDeleted = false;
      bool apiDeleteCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/102' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 102,
              'name': 'Test Partner',
              'mobile': '9811122233',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-10-25T10:00:00',
              'partner_profile': {
                'business_name': 'Super Motors',
                'partner_code': 'SM01',
                'zone_name': 'North Zone',
                'business_address': 'Main Highway',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/users/102' && request.method == 'DELETE') {
          apiDeleteCalled = true;
          return http.Response(
            jsonEncode({
              'status': 'deactivated',
              'message': 'Partner account deactivated because it is referenced in historical records.',
              'was_deactivated': true,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);
      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: session);

      const userSummary = AdminUserSummary(
        id: 102,
        name: 'Test Partner',
        mobile: '9811122233',
        role: 'partner',
        isActive: true,
        businessName: 'Super Motors',
        zoneName: 'North Zone',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => UserDetailSheet(
                    userSummary: userSummary,
                    adminApi: adminApi,
                    sessionManager: session,
                    onStatusChanged: (_) {},
                    onUserDeleted: () {
                      userDeleted = true;
                    },
                  ),
                ),
                child: const Text('Open User Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open User Sheet'));
      await tester.pumpAndSettle();

      // Assigned zone should be displayed for partner
      expect(find.text('North Zone'), findsWidgets);

      // Scroll to and tap Delete Account button
      final deleteBtnFinder = find.byKey(const Key('user_detail_delete_button'));
      expect(deleteBtnFinder, findsOneWidget);
      await tester.ensureVisible(deleteBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible with safe deactivation notice
      expect(find.text('Delete Account'), findsWidgets);
      expect(find.byKey(const Key('confirm_delete_user_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_delete_user_button')));
      await tester.pumpAndSettle();

      expect(apiDeleteCalled, isTrue);
      expect(userDeleted, isTrue);
    });
  });

  group('Admin Phase B: AdminProductDetailSheet Delete Action Tests', () {
    testWidgets('Prompts confirmation and safely deletes or deactivates product', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool productDeleted = false;
      bool apiDeleteCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/catalogue/products/50' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 50,
              'product_code': 'PRD-050',
              'name': 'Spark Plug Gold',
              'category_id': 1,
              'category_name': 'Ignition',
              'category_is_active': true,
              'vehicle_type': '2-Wheeler',
              'price': 350.00,
              'description': 'High performance spark plug',
              'is_active': true,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products/50' && request.method == 'DELETE') {
          apiDeleteCalled = true;
          return http.Response(
            jsonEncode({
              'status': 'deactivated',
              'message': 'Product deactivated because it is referenced in orders.',
              'was_deactivated': true,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);
      final catalogueApi = AdminCatalogueApi(client: client, baseUrl: 'http://localhost', sessionManager: session);

      const product = AdminProduct(
        id: 50,
        productCode: 'PRD-050',
        name: 'Spark Plug Gold',
        categoryId: 1,
        categoryName: 'Ignition',
        categoryIsActive: true,
        vehicleType: '2-Wheeler',
        price: 350.00,
        description: 'High performance spark plug',
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: ctx,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AdminProductDetailSheet(
                    product: product,
                    catalogueApi: catalogueApi,
                    onProductDeleted: () {
                      productDeleted = true;
                    },
                  ),
                ),
                child: const Text('Open Product Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Product Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Spark Plug Gold'), findsWidgets);

      // Scroll to and tap Delete Product button
      final deleteBtnFinder = find.byKey(const Key('product_detail_delete_button'));
      expect(deleteBtnFinder, findsOneWidget);
      await tester.ensureVisible(deleteBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(find.byKey(const Key('product_delete_confirm_dialog')), findsOneWidget);
      expect(find.byKey(const Key('product_delete_confirm_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('product_delete_confirm_button')));
      await tester.pumpAndSettle();

      expect(apiDeleteCalled, isTrue);
      expect(productDeleted, isTrue);
    });
  });

  group('Admin Phase E: Reports Screen Tab Switching Tests', () {
    testWidgets('Switches to Zone-wise and Staff-wise tabs successfully', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/reports/overview') {
          return http.Response(
            jsonEncode({
              'date_filter': {'preset': 'all'},
              'overview': {'total_orders': 25, 'total_order_value': 50000},
              'catalogue': {'total_products': 50, 'active_products': 48, 'inactive_products': 2},
              'order_status_distribution': {},
              'stock_request_distribution': {},
              'order_trends': [],
              'unsupported_metrics': [],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/reports/zone-wise') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'zone_id': 1,
                  'zone_name': 'North Territory',
                  'partner_count': 12,
                  'order_count': 45,
                  'total_order_value': 120000.0,
                  'payment_count': 30,
                  'total_payments_collected': 95000.0,
                },
              ],
              'total_zones': 1,
              'total_orders': 45,
              'total_order_value': 120000.0,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/reports/staff-wise') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'staff_user_id': 20,
                  'staff_id': 'STF-01',
                  'name': 'Ajay Staff',
                  'mobile': '9899900011',
                  'assigned_partner_count': 6,
                  'order_count': 18,
                  'total_order_value': 48000.0,
                  'payment_count': 12,
                  'total_payments_collected': 32000.0,
                },
              ],
              'total_staff': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/zones') {
          return http.Response(jsonEncode({'items': [], 'total': 0}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);
      final reportsApi = AdminReportsApi(client: client, baseUrl: 'http://localhost', sessionManager: session);
      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: session);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReportsScreen(
            reportsApi: reportsApi,
            adminApi: adminApi,
            sessionManager: session,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check overview
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      // Switch to Zone-wise tab
      final zoneTabFinder = find.byKey(const Key('report_tab_zone'));
      await tester.ensureVisible(zoneTabFinder);
      await tester.pumpAndSettle();
      await tester.tap(zoneTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('North Territory'), findsOneWidget);
      expect(find.text('12 Partners'), findsOneWidget);

      // Switch to Staff-wise tab
      final staffTabFinder = find.byKey(const Key('report_tab_staff'));
      await tester.ensureVisible(staffTabFinder);
      await tester.pumpAndSettle();
      await tester.tap(staffTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('Ajay Staff'), findsOneWidget);
      expect(find.textContaining('STF-01'), findsOneWidget);
    });
  });
}
