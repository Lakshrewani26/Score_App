import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_orders_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/admin/orders/admin_orders_screen.dart';

void main() {
  late AdminSessionManager sessionManager;

  setUp(() async {
    sessionManager =
        AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
    await sessionManager.saveSession(
      token: 'test-admin-jwt-token',
      user: const AdminUser(
        id: 1,
        name: 'Super Admin',
        mobile: '9876543210',
        role: 'admin',
        isActive: true,
      ),
    );
  });

  Widget createTestWidget({
    required AdminOrdersApi ordersApi,
    AdminApi? adminApi,
  }) {
    return MaterialApp(
      home: AdminOrdersScreen(
        ordersApi: ordersApi,
        adminApi: adminApi,
        sessionManager: sessionManager,
      ),
    );
  }

  group('Admin Orders Screen & Navigation Tests', () {
    testWidgets('1. Dashboard does not display the Orders & Requests tile',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Orders & Requests'), findsNothing);
      expect(find.text('Partner orders & stock requests'), findsNothing);
    });

    testWidgets('2. Switches between Orders and Stock Requests tabs',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-001',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'partner_mobile': '9876543211',
                  'status': 'approved_processing',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 5,
                  'order_total': '1500.00',
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/stock-requests') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 10,
                  'request_number': 'REQ-010',
                  'partner_id': 3,
                  'partner_name': 'Partner B',
                  'partner_mobile': '9876543212',
                  'status': 'pending_approval',
                  'created_at': '2026-10-25T14:00:00Z',
                  'item_count': 2,
                  'total_quantity': 40,
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Orders tab is active by default
      expect(find.text('ORD-001'), findsOneWidget);
      expect(find.text('Partner A'), findsOneWidget);

      // Switch to Stock Requests tab
      await tester
          .tap(find.byKey(const Key('admin_orders_tab_stock_requests')));
      await tester.pumpAndSettle();

      expect(find.text('REQ-010'), findsOneWidget);
      expect(find.text('Partner B'), findsOneWidget);

      // Switch back to Orders tab
      await tester.tap(find.byKey(const Key('admin_orders_tab_orders')));
      await tester.pumpAndSettle();

      expect(find.text('ORD-001'), findsOneWidget);
    });

    testWidgets('3. Handles error state and retry for orders', (tester) async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          callCount++;
          if (callCount == 1) {
            return http.Response('Server Error', 500);
          }
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 2,
                  'order_number': 'ORD-002',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'partner_mobile': '9876543211',
                  'status': 'dispatched',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 2,
                  'order_total': '800.00',
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Error message and retry button should be visible
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('ORD-002'), findsOneWidget);
    });

    testWidgets('4. Search input triggers debounced search query',
        (tester) async {
      String? lastSearch;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          lastSearch = request.url.queryParameters['search'];
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Type in search box
      await tester.enterText(
          find.byKey(const Key('admin_orders_search_input')), 'ORD-999');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(lastSearch, 'ORD-999');
    });

    testWidgets('5. Status and Vehicle dropdowns update filters',
        (tester) async {
      String? lastStatus;
      String? lastVehicle;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          lastStatus = request.url.queryParameters['status'];
          lastVehicle = request.url.queryParameters['vehicle_type'];
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Change status filter
      await tester.tap(find.byKey(const Key('admin_orders_status_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Processing').last);
      await tester.pumpAndSettle();

      expect(lastStatus, 'approved_processing');

      // Change vehicle filter
      await tester.tap(find.byKey(const Key('admin_orders_vehicle_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2-Wheeler').last);
      await tester.pumpAndSettle();

      expect(lastVehicle, '2-Wheeler');
    });

    testWidgets('6. Pagination navigation works and respects boundaries',
        (tester) async {
      int requestedPage = 1;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          requestedPage = int.parse(request.url.queryParameters['page'] ?? '1');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': requestedPage,
                  'order_number': 'ORD-00$requestedPage',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'partner_mobile': '9876543211',
                  'status': 'dispatched',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 2,
                  'order_total': '800.00',
                }
              ],
              'total': 45,
              'page': requestedPage,
              'page_size': 20,
              'total_pages': 3,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 3 (45 orders)'), findsOneWidget);

      // Tap Next Page
      await tester.tap(find.byKey(const Key('pagination_next_orders')));
      await tester.pumpAndSettle();

      expect(requestedPage, 2);
      expect(find.text('Page 2 of 3 (45 orders)'), findsOneWidget);

      // Tap Previous Page
      await tester.tap(find.byKey(const Key('pagination_prev_orders')));
      await tester.pumpAndSettle();

      expect(requestedPage, 1);
    });

    testWidgets(
        '7. Opening order detail displays items, prices, and status history',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-001',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'business_name': 'Auto Care India',
                  'partner_mobile': '9876543211',
                  'status': 'approved_processing',
                  'notes': 'Deliver by Monday',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 5,
                  'order_total': '2250.00',
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'order_number': 'ORD-001',
              'partner_id': 2,
              'partner_name': 'Partner A',
              'business_name': 'Auto Care India',
              'partner_mobile': '9876543211',
              'status': 'approved_processing',
              'notes': 'Deliver by Monday',
              'created_at': '2026-10-25T12:00:00Z',
              'approved_by': 3,
              'approved_by_name': 'Staff Vikram',
              'approved_at': '2026-10-25T13:00:00Z',
              'item_count': 1,
              'total_quantity': 5,
              'order_total': '2250.00',
              'items': [
                {
                  'id': 101,
                  'product_id': 50,
                  'product_code': 'BRK-001',
                  'product_name': 'Disc Brake Pad',
                  'vehicle_type': '2-Wheeler',
                  'quantity': 5,
                  'unit_price': '450.00',
                  'subtotal': '2250.00',
                }
              ],
              'status_history': [
                {
                  'id': 201,
                  'old_status': 'pending_approval',
                  'new_status': 'approved_processing',
                  'changed_by': 3,
                  'changed_by_name': 'Staff Vikram',
                  'changed_at': '2026-10-25T13:00:00Z',
                  'remarks': 'Approved',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Tap Order Card
      await tester.tap(find.byKey(const Key('admin_order_card_1')));
      await tester.pumpAndSettle();

      // Order Detail Sheet should show details
      expect(find.text('Disc Brake Pad'), findsOneWidget);
      expect(find.text('₹2,250.00'), findsWidgets);
      expect(find.text('Auto Care India (Partner A)'), findsWidgets);
      expect(find.text('Staff Vikram'), findsWidgets);

      await tester.scrollUntilVisible(
        find.byKey(const Key('admin_order_dispatch_button')),
        100.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
          find.byKey(const Key('admin_order_dispatch_button')), findsOneWidget);
    });

    testWidgets(
        '8. Status progression Dispatch Order requires confirmation and updates order',
        (tester) async {
      bool patchCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-001',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'partner_mobile': '9876543211',
                  'status': patchCalled ? 'dispatched' : 'approved_processing',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 5,
                  'order_total': '2250.00',
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'order_number': 'ORD-001',
              'partner_id': 2,
              'partner_name': 'Partner A',
              'partner_mobile': '9876543211',
              'status': patchCalled ? 'dispatched' : 'approved_processing',
              'created_at': '2026-10-25T12:00:00Z',
              'item_count': 1,
              'total_quantity': 5,
              'order_total': '2250.00',
              'items': [],
              'status_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1/status' &&
            request.method == 'PATCH') {
          patchCalled = true;
          return http.Response(
            jsonEncode({
              'id': 1,
              'order_number': 'ORD-001',
              'partner_id': 2,
              'partner_name': 'Partner A',
              'partner_mobile': '9876543211',
              'status': 'dispatched',
              'created_at': '2026-10-25T12:00:00Z',
              'item_count': 1,
              'total_quantity': 5,
              'order_total': '2250.00',
              'items': [],
              'status_history': [
                {
                  'id': 301,
                  'old_status': 'approved_processing',
                  'new_status': 'dispatched',
                  'changed_at': '2026-10-25T14:00:00Z',
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byKey(const Key('admin_order_card_1')));
      await tester.pumpAndSettle();

      // Tap Dispatch Order button
      await tester
          .ensureVisible(find.byKey(const Key('admin_order_dispatch_button')));
      await tester.tap(find.byKey(const Key('admin_order_dispatch_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.byKey(const Key('confirm_dialog_action_button')),
          findsOneWidget);

      // Confirm
      await tester.tap(find.byKey(const Key('confirm_dialog_action_button')));
      await tester.pumpAndSettle();

      expect(patchCalled, isTrue);
      await tester.ensureVisible(find.text('Mark as Delivered'));
      expect(find.text('Mark as Delivered'), findsOneWidget);
    });

    testWidgets(
        '9. Failed status change displays error SnackBar without false UI update',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-001',
                  'partner_id': 2,
                  'partner_name': 'Partner A',
                  'partner_mobile': '9876543211',
                  'status': 'approved_processing',
                  'created_at': '2026-10-25T12:00:00Z',
                  'item_count': 1,
                  'total_quantity': 5,
                  'order_total': '2250.00',
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 1,
              'order_number': 'ORD-001',
              'partner_id': 2,
              'partner_name': 'Partner A',
              'partner_mobile': '9876543211',
              'status': 'approved_processing',
              'created_at': '2026-10-25T12:00:00Z',
              'item_count': 1,
              'total_quantity': 5,
              'order_total': '2250.00',
              'items': [],
              'status_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1/status' &&
            request.method == 'PATCH') {
          return http.Response(
            jsonEncode({'detail': 'Database lock timeout. Please retry.'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byKey(const Key('admin_order_card_1')));
      await tester.pumpAndSettle();

      // Tap Dispatch Order
      await tester
          .ensureVisible(find.byKey(const Key('admin_order_dispatch_button')));
      await tester.tap(find.byKey(const Key('admin_order_dispatch_button')));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.byKey(const Key('confirm_dialog_action_button')));
      await tester.pumpAndSettle();

      // SnackBar with error detail displayed
      expect(find.text('Database lock timeout. Please retry.'), findsOneWidget);

      // Status should remain approved_processing
      await tester.scrollUntilVisible(
        find.byKey(const Key('admin_order_dispatch_button')),
        100.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
          find.byKey(const Key('admin_order_dispatch_button')), findsOneWidget);
    });

    testWidgets(
        '10. Opening stock request detail sheet displays items and read-only notice',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 0
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/stock-requests') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 20,
                  'request_number': 'REQ-020',
                  'partner_id': 4,
                  'partner_name': 'Partner C',
                  'business_name': 'City Motors',
                  'partner_mobile': '9876543213',
                  'status': 'pending_approval',
                  'notes': 'Buffer parts',
                  'created_at': '2026-10-25T14:00:00Z',
                  'item_count': 1,
                  'total_quantity': 50,
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/stock-requests/20') {
          return http.Response(
            jsonEncode({
              'id': 20,
              'request_number': 'REQ-020',
              'partner_id': 4,
              'partner_name': 'Partner C',
              'business_name': 'City Motors',
              'partner_mobile': '9876543213',
              'status': 'pending_approval',
              'notes': 'Buffer parts',
              'created_at': '2026-10-25T14:00:00Z',
              'item_count': 1,
              'total_quantity': 50,
              'items': [
                {
                  'id': 1,
                  'product_id': 15,
                  'product_code': 'WSH-001',
                  'product_name': 'Lock Washer',
                  'vehicle_type': 'Both',
                  'quantity': 50,
                }
              ],
              'status_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Switch to Stock Requests tab
      await tester
          .tap(find.byKey(const Key('admin_orders_tab_stock_requests')));
      await tester.pumpAndSettle();

      // Tap Stock Request card
      await tester.tap(find.byKey(const Key('admin_stock_request_card_20')));
      await tester.pumpAndSettle();

      // Detail sheet should open
      expect(find.text('REQ-020'), findsWidgets);
      expect(find.text('Lock Washer'), findsOneWidget);
      expect(find.text('50 pcs'), findsWidgets);
      expect(find.text('City Motors (Partner C)'), findsWidgets);
      expect(
        find.text(
            'Stock Request approvals and rejections are managed exclusively by Staff. Admin access is read-only.'),
        findsOneWidget,
      );
    });
  });
}
