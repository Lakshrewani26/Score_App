import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_orders_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/pdf_printer/pdf_printer.dart';
import 'package:score_app/features/admin/orders/admin_all_orders_screen.dart';

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
    Size? physicalSize,
    PdfPrinterFn? pdfPrinter,
  }) {
    return MaterialApp(
      home: AdminAllOrdersScreen(
        ordersApi: ordersApi,
        sessionManager: sessionManager,
        pdfPrinter: pdfPrinter,
      ),
    );
  }

  group('Admin All Orders Screen Tests', () {
    testWidgets('1. Header and empty state render correctly', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
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

      expect(find.text('All Orders'), findsOneWidget);
      expect(
        find.text('Complete list of Partner & Staff orders (Read-Only)'),
        findsOneWidget,
      );
      expect(find.text('No Orders Found'), findsOneWidget);
      expect(
        find.text('No normal orders match the selected filters or search query.'),
        findsOneWidget,
      );
    });

    testWidgets(
        '2. Displays partner-created and staff-created orders with creator badges',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-PTN-001',
                  'partner_id': 2,
                  'partner_name': 'Rajesh Sharma',
                  'business_name': 'Rajesh Auto Spares',
                  'partner_mobile': '9876543211',
                  'status': 'pending_approval',
                  'created_at': '2026-11-18T10:00:00Z',
                  'created_by_user_id': 2,
                  'created_by_name': 'Rajesh Sharma',
                  'created_by_role': 'partner',
                  'item_count': 1,
                  'total_quantity': 2,
                  'order_total': '990.00',
                  'subtotal_before_discount': '1100.00',
                  'discount_percentage': '10.00',
                  'total_discount': '110.00',
                  'final_total': '990.00',
                },
                {
                  'id': 2,
                  'order_number': 'ORD-STF-002',
                  'partner_id': 3,
                  'partner_name': 'Sunil Patil',
                  'business_name': 'Patil Wheels Mumbai',
                  'partner_mobile': '9876543212',
                  'status': 'approved_processing',
                  'created_at': '2026-11-18T11:00:00Z',
                  'created_by_user_id': 4,
                  'created_by_name': 'Vikram SalesStaff',
                  'created_by_role': 'staff',
                  'item_count': 2,
                  'total_quantity': 4,
                  'order_total': '2090.00',
                  'subtotal_before_discount': '2200.00',
                  'discount_percentage': '5.00',
                  'total_discount': '110.00',
                  'final_total': '2090.00',
                },
              ],
              'total': 2,
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

      // Check order numbers rendered
      expect(find.text('ORD-PTN-001'), findsOneWidget);
      expect(find.text('ORD-STF-002'), findsOneWidget);

      // Check partner / business names rendered
      expect(find.text('Rajesh Auto Spares'), findsOneWidget);
      expect(find.text('Patil Wheels Mumbai'), findsOneWidget);

      // Check creator roles and names rendered
      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Vikram SalesStaff'), findsOneWidget);
    });

    testWidgets('3. Strictly excludes stock requests and queries normal orders only',
        (tester) async {
      bool queriedStockRequests = false;
      bool queriedOrders = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          queriedOrders = true;
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('stock-request')) {
          queriedStockRequests = true;
          return http.Response('Error', 500);
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

      expect(queriedOrders, isTrue);
      expect(queriedStockRequests, isFalse);
    });

    testWidgets('4. Search field triggers API query with search parameter',
        (tester) async {
      String? capturedSearch;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          capturedSearch = request.url.queryParameters['search'];
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
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

      // Enter search term
      await tester.enterText(
        find.byKey(const Key('all_orders_search_input')),
        'ORD-PTN-001',
      );
      // Wait for debounce timer (400ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(capturedSearch, equals('ORD-PTN-001'));
    });

    testWidgets(
        '5. Detail sheet is strictly read-only and has Print Order button',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool pdfDownloaded = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'order_number': 'ORD-PTN-001',
                  'partner_id': 2,
                  'partner_name': 'Rajesh Sharma',
                  'business_name': 'Rajesh Auto Spares',
                  'partner_mobile': '9876543211',
                  'status': 'pending_approval',
                  'created_at': '2026-11-18T10:00:00Z',
                  'created_by_user_id': 2,
                  'created_by_name': 'Rajesh Sharma',
                  'created_by_role': 'partner',
                  'item_count': 1,
                  'total_quantity': 2,
                  'order_total': '990.00',
                  'subtotal_before_discount': '1100.00',
                  'discount_percentage': '10.00',
                  'total_discount': '110.00',
                  'final_total': '990.00',
                },
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
              'order_number': 'ORD-PTN-001',
              'partner_id': 2,
              'partner_name': 'Rajesh Sharma',
              'business_name': 'Rajesh Auto Spares',
              'partner_mobile': '9876543211',
              'status': 'pending_approval',
              'created_at': '2026-11-18T10:00:00Z',
              'created_by_user_id': 2,
              'created_by_name': 'Rajesh Sharma',
              'created_by_role': 'partner',
              'notes': 'VRL Logistics',
              'item_count': 1,
              'total_quantity': 2,
              'order_total': '990.00',
              'subtotal_before_discount': '1100.00',
              'discount_percentage': '10.00',
              'total_discount': '110.00',
              'final_total': '990.00',
              'items': [
                {
                  'id': 1,
                  'product_id': 10,
                  'product_code': 'BRK-001',
                  'product_name': 'Ceramic Disc Brake Pad Set',
                  'vehicle_type': '2-Wheeler',
                  'quantity': 2,
                  'unit_price': '495.00',
                  'subtotal': '990.00',
                  'original_price': '550.00',
                  'mrp': '600.00',
                  'list_price': '550.00',
                  'discount_percentage': '10.00',
                  'discount_amount': '55.00',
                  'discounted_price': '495.00',
                },
              ],
              'status_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/1/pdf') {
          pdfDownloaded = true;
          return http.Response(
            'fake-pdf-bytes',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response('Not Found', 404);
      });

      Uint8List? printedBytes;
      String? printedFileName;

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(
        ordersApi: ordersApi,
        pdfPrinter: ({required bytes, required fileName}) async {
          printedBytes = bytes;
          printedFileName = fileName;
        },
      ));
      await tester.pumpAndSettle();

      // Tap order row to view details
      await tester.tap(find.text('ORD-PTN-001'));
      await tester.pumpAndSettle();

      // Detail sheet is displayed
      expect(find.text('Order #ORD-PTN-001'), findsOneWidget);
      expect(find.textContaining('This view is strictly read-only'), findsOneWidget);
      expect(find.text('Ceramic Disc Brake Pad Set'), findsOneWidget);
      expect(find.text('Print Order'), findsOneWidget);

      // Verify strictly NO approval, rejection, or edit controls exist
      expect(find.text('Approve Order'), findsNothing);
      expect(find.text('Reject Order'), findsNothing);
      expect(find.text('Update Status'), findsNothing);

      // Tap Print Order button
      await tester.tap(find.byKey(const Key('all_orders_detail_print_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(pdfDownloaded, isTrue);
      expect(printedBytes, isNotNull);
      expect(utf8.decode(printedBytes!), equals('fake-pdf-bytes'));
      expect(printedFileName, equals('Score_Order_ORD-PTN-001.pdf'));
      expect(find.text('Print preview opened for Order #ORD-PTN-001.'), findsOneWidget);
    });

    testWidgets('6. Error state shows retry button and retry reloads data',
        (tester) async {
      int attempts = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          attempts++;
          if (attempts == 1) {
            return http.Response('Internal Server Error', 500);
          }
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
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

      // Error state displayed
      expect(find.text('Failed to load orders'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(attempts, equals(2));
      expect(find.text('No Orders Found'), findsOneWidget);
    });

    testWidgets(
        '7. Displays historical unattributed orders with Unknown / Legacy creator badge',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 3,
                  'order_number': 'ORD-HIST-003',
                  'partner_id': 2,
                  'partner_name': 'Rajesh Sharma',
                  'business_name': 'Rajesh Auto Spares',
                  'partner_mobile': '9876543211',
                  'status': 'delivered',
                  'created_at': '2026-10-18T10:00:00Z',
                  'created_by_user_id': null,
                  'created_by_name': 'Unknown / Legacy',
                  'created_by_role': 'unknown',
                  'item_count': 1,
                  'total_quantity': 1,
                  'order_total': '550.00',
                  'subtotal_before_discount': '550.00',
                  'discount_percentage': '0.00',
                  'total_discount': '0.00',
                  'final_total': '550.00',
                },
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

      expect(find.text('ORD-HIST-003'), findsOneWidget);
      expect(find.text('Rajesh Auto Spares'), findsOneWidget);
      expect(find.text('Unknown / Legacy'), findsNWidgets(2));
    });

    testWidgets(
        '8. Print button in desktop table requests correct order ID and triggers print workflow',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int? requestedPdfOrderId;
      Uint8List? printedBytes;
      String? printedFileName;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 42,
                  'order_number': 'ORD-ACTUAL-042',
                  'partner_id': 5,
                  'partner_name': 'Kavita Rao',
                  'business_name': 'Rao Motors',
                  'partner_mobile': '9876543242',
                  'status': 'dispatched',
                  'created_at': '2026-11-18T10:00:00Z',
                  'created_by_user_id': 5,
                  'created_by_name': 'Kavita Rao',
                  'created_by_role': 'partner',
                  'item_count': 1,
                  'total_quantity': 3,
                  'order_total': '1500.00',
                  'subtotal_before_discount': '1500.00',
                  'discount_percentage': '0.00',
                  'total_discount': '0.00',
                  'final_total': '1500.00',
                },
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/42/pdf') {
          requestedPdfOrderId = 42;
          return http.Response(
            'actual-order-42-pdf-bytes',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(
        ordersApi: ordersApi,
        pdfPrinter: ({required bytes, required fileName}) async {
          printedBytes = bytes;
          printedFileName = fileName;
        },
      ));
      await tester.pumpAndSettle();

      // Tap table print button
      final printBtn = find.byKey(const Key('print_order_42'));
      await tester.ensureVisible(printBtn);
      await tester.tap(printBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requestedPdfOrderId, equals(42));
      expect(printedBytes, isNotNull);
      expect(utf8.decode(printedBytes!), equals('actual-order-42-pdf-bytes'));
      expect(printedFileName, equals('Score_Order_ORD-ACTUAL-042.pdf'));
      expect(
        find.text('Print preview opened for Order #ORD-ACTUAL-042.'),
        findsOneWidget,
      );
    });

    testWidgets(
        '9. Handles PDF download API failure properly and shows error SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool printerCalled = false;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 15,
                  'order_number': 'ORD-ERR-015',
                  'partner_id': 2,
                  'partner_name': 'Test Partner',
                  'business_name': 'Test Spares',
                  'partner_mobile': '9876543210',
                  'status': 'pending_approval',
                  'created_at': '2026-11-18T10:00:00Z',
                  'created_by_user_id': 2,
                  'created_by_name': 'Test Partner',
                  'created_by_role': 'partner',
                  'item_count': 1,
                  'total_quantity': 1,
                  'order_total': '100.00',
                  'subtotal_before_discount': '100.00',
                  'discount_percentage': '0.00',
                  'total_discount': '0.00',
                  'final_total': '100.00',
                },
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/15/pdf') {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(
        ordersApi: ordersApi,
        pdfPrinter: ({required bytes, required fileName}) async {
          printerCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      final printBtn = find.byKey(const Key('print_order_15'));
      await tester.ensureVisible(printBtn);
      await tester.tap(printBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(printerCalled, isFalse);
      expect(
        find.textContaining('Failed to print order: Failed to download order PDF'),
        findsOneWidget,
      );
      // Ensure it does not falsely report success
      expect(find.textContaining('Print preview opened'), findsNothing);
    });

    testWidgets(
        '10. Handles browser printing failure (e.g. popup blocked) and shows error SnackBar',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 16,
                  'order_number': 'ORD-BLOCKED-016',
                  'partner_id': 2,
                  'partner_name': 'Test Partner',
                  'business_name': 'Test Spares',
                  'partner_mobile': '9876543210',
                  'status': 'pending_approval',
                  'created_at': '2026-11-18T10:00:00Z',
                  'created_by_user_id': 2,
                  'created_by_name': 'Test Partner',
                  'created_by_role': 'partner',
                  'item_count': 1,
                  'total_quantity': 1,
                  'order_total': '100.00',
                  'subtotal_before_discount': '100.00',
                  'discount_percentage': '0.00',
                  'total_discount': '0.00',
                  'final_total': '100.00',
                },
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/orders/16/pdf') {
          return http.Response(
            'pdf-data',
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(
        ordersApi: ordersApi,
        pdfPrinter: ({required bytes, required fileName}) async {
          throw Exception('Print popup was blocked by browser. Please allow popups for this site to print.');
        },
      ));
      await tester.pumpAndSettle();

      final printBtn = find.byKey(const Key('print_order_16'));
      await tester.ensureVisible(printBtn);
      await tester.tap(printBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Failed to print order: Print popup was blocked by browser'),
        findsOneWidget,
      );
      expect(find.textContaining('Print preview opened'), findsNothing);
    });

    testWidgets(
        '11. Verifies All Orders screen strictly renders real API data without static fallbacks',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/orders') {
          // Verify that query parameters are forwarded to backend API
          expect(request.url.queryParameters['page'], equals('1'));
          expect(request.url.queryParameters['page_size'], equals('20'));
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
        return http.Response('Not Found', 404);
      });

      final ordersApi = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(createTestWidget(ordersApi: ordersApi));
      await tester.pumpAndSettle();

      // Confirms empty state when backend returns empty list (no hardcoded orders injected)
      expect(find.text('No Orders Found'), findsOneWidget);
      expect(find.text('ORD-PTN-001'), findsNothing);
      expect(find.text('ORD-STF-002'), findsNothing);
      expect(find.text('ORD-HIST-003'), findsNothing);
    });
  });
}
