import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_status_screen.dart';

StaffApi _createMockStaffApi({
  List<Map<String, dynamic>>? initialOrders,
  void Function(http.Request)? onRequest,
  http.Response? Function(http.Request)? customHandler,
}) {
  final session = StaffSessionManager();
  session.saveSession(
    token: 'test-staff-token',
    user: const StaffUser(
      id: 11,
      name: 'Staff Member',
      mobile: '+919999900001',
      role: 'staff',
      isActive: true,
      staffId: 'STF-001',
    ),
  );

  List<Map<String, dynamic>> orders = (initialOrders ??
      [
        {
          'id': 101,
          'order_number': 'INV-24027',
          'partner_id': 20,
          'partner_name': 'Rahul Partner',
          'business_name': 'Rahul Auto Spares',
          'partner_mobile': '+919876543210',
          'status': 'pending_approval',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 3,
          'total_quantity': 5,
          'order_total': '2500.00',
          'items': <dynamic>[],
          'status_history': <dynamic>[],
        },
        {
          'id': 102,
          'order_number': 'INV-24028',
          'partner_id': 21,
          'partner_name': 'Amit Sharma',
          'business_name': 'Sharma Motors',
          'partner_mobile': '+919876543211',
          'status': 'pending_approval',
          'created_at': '2025-10-02T11:00:00',
          'item_count': 1,
          'total_quantity': 2,
          'order_total': '1200.00',
          'items': <dynamic>[],
          'status_history': <dynamic>[],
        },
      ])
      .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
      .toList();

  final client = MockClient((request) async {
    onRequest?.call(request);
    expect(request.headers['Authorization'], 'Bearer test-staff-token');

    if (customHandler != null) {
      final customResp = customHandler(request);
      if (customResp != null) {
        return customResp;
      }
    }

    if (request.method == 'GET' &&
        request.url.path == '/api/v1/staff/orders') {
      final statusParam = request.url.queryParameters['status'];
      if (statusParam != null && statusParam.isNotEmpty && statusParam != 'all') {
        final filtered =
            orders.where((o) => o['status'] == statusParam).toList();
        return http.Response(jsonEncode(filtered), 200);
      }
      return http.Response(jsonEncode(orders), 200);
    }

    if (request.method == 'PATCH' &&
        request.url.path.startsWith('/api/v1/staff/orders/') &&
        request.url.path.endsWith('/status')) {
      final segments = request.url.pathSegments;
      final orderId = int.parse(segments[segments.length - 2]);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final targetStatus = body['status'] as String;
      final remarks = body['remarks'] as String?;

      final orderIndex = orders.indexWhere((o) => o['id'] == orderId);
      if (orderIndex != -1) {
        final existing = orders[orderIndex];
        final history = List<Map<String, dynamic>>.from(
            (existing['status_history'] as List?) ?? []);
        history.add({
          'id': history.length + 1,
          'order_id': orderId,
          'old_status': existing['status'],
          'new_status': targetStatus,
          'remarks': remarks,
          'changed_by': 11,
          'changed_at': DateTime.now().toIso8601String(),
        });
        final updated = {
          ...existing,
          'status': targetStatus,
          'status_history': history,
        };
        orders[orderIndex] = updated;
        return http.Response(jsonEncode(updated), 200);
      }
      return http.Response(jsonEncode({'detail': 'Order not found'}), 404);
    }

    if (request.method == 'GET' &&
        request.url.pathSegments.isNotEmpty &&
        int.tryParse(request.url.pathSegments.last) != null) {
      final orderId = int.parse(request.url.pathSegments.last);
      final order = orders.firstWhere(
        (o) => o['id'] == orderId,
        orElse: () => <String, dynamic>{},
      );
      if (order.isNotEmpty) {
        return http.Response(jsonEncode(order), 200);
      }
      return http.Response(jsonEncode({'detail': 'Not found'}), 404);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/approve')) {
      final orderId = int.parse(
          request.url.pathSegments[request.url.pathSegments.length - 2]);
      orders = orders.where((o) => o['id'] != orderId).toList();
      return http.Response(
        jsonEncode({
          'id': orderId,
          'order_number': 'INV-24027',
          'partner_id': 20,
          'partner_name': 'Rahul Partner',
          'business_name': 'Rahul Auto Spares',
          'partner_mobile': '+919876543210',
          'status': 'approved_processing',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 3,
          'total_quantity': 5,
          'order_total': '2500.00',
          'items': [],
          'status_history': [
            {
              'id': 1,
              'order_id': orderId,
              'old_status': 'pending_approval',
              'new_status': 'approved_processing',
              'changed_by': 11,
              'changed_at': '2025-10-01T10:05:00',
            }
          ],
        }),
        200,
      );
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/reject')) {
      final orderId = int.parse(
          request.url.pathSegments[request.url.pathSegments.length - 2]);
      orders = orders.where((o) => o['id'] != orderId).toList();
      return http.Response(
        jsonEncode({
          'id': orderId,
          'order_number': 'INV-24028',
          'partner_id': 21,
          'partner_name': 'Amit Sharma',
          'business_name': 'Sharma Motors',
          'partner_mobile': '+919876543211',
          'status': 'rejected',
          'created_at': '2025-10-02T11:00:00',
          'item_count': 1,
          'total_quantity': 2,
          'order_total': '1200.00',
          'items': [],
          'status_history': [],
        }),
        200,
      );
    }

    return http.Response('Not found', 404);
  });

  return StaffApi(client: client, sessionManager: session);
}

void main() {
  group('StaffOrderStatusScreen Tests', () {
    testWidgets(
        'renders StaffOrderStatusScreen with live pending orders from StaffApi',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Screen title and subtitle
      expect(find.byType(StaffOrderStatusScreen), findsOneWidget);
      expect(find.text('Order Status'), findsOneWidget);
      expect(find.text('Review pending dealer invoices'), findsOneWidget);

      // Order count header
      expect(find.text('2 pending orders'), findsOneWidget);

      // Dealer names and invoice numbers
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('INV-24027'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('INV-24028'), findsOneWidget);

      // Action buttons exist for each order
      expect(find.byKey(const Key('staff-order-approve-101')), findsOneWidget);
      expect(find.byKey(const Key('staff-order-reject-101')), findsOneWidget);
      expect(find.byKey(const Key('staff-order-approve-102')), findsOneWidget);
      expect(find.byKey(const Key('staff-order-reject-102')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters orders by dealer name and invoice number',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // Filter by dealer name 'Sharma'
      await tester.enterText(searchField, 'Sharma');
      await tester.pumpAndSettle();

      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('Rahul Auto Spares'), findsNothing);
      expect(find.text('1 pending order'), findsOneWidget);

      // Filter by invoice number '24027'
      await tester.enterText(searchField, '24027');
      await tester.pumpAndSettle();

      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('2 pending orders'), findsOneWidget);
    });

    testWidgets('tapping approve opens dialog and approves order successfully',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final approveBtn = find.byKey(const Key('staff-order-approve-101'));
      await tester.ensureVisible(approveBtn);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('Approve Order'), findsOneWidget);
      expect(find.text('Approve order INV-24027 for processing?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-approve-order-button')));
      await tester.pumpAndSettle();

      // Success SnackBar and order removed from list
      expect(find.text('Order INV-24027 approved successfully.'), findsOneWidget);
      expect(find.text('Rahul Auto Spares'), findsNothing);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('1 pending order'), findsOneWidget);
    });

    testWidgets('tapping reject opens dialog with remarks and rejects order',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final rejectBtn = find.byKey(const Key('staff-order-reject-102'));
      await tester.ensureVisible(rejectBtn);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Rejection dialog with remarks input
      expect(find.text('Reject Order'), findsOneWidget);
      expect(find.text('Are you sure you want to reject order INV-24028?'),
          findsOneWidget);

      final remarksField = find.widgetWithText(TextField, 'Remarks / Reason (Optional)');
      expect(remarksField, findsOneWidget);
      await tester.enterText(remarksField, 'Out of stock');

      await tester.tap(find.byKey(const Key('confirm-reject-order-button')));
      await tester.pumpAndSettle();

      // Rejection snackbar and order removed from list
      expect(find.text('Order INV-24028 rejected.'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsNothing);
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('1 pending order'), findsOneWidget);
    });

    testWidgets('displays empty state when no pending orders exist',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi(initialOrders: []);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('staff-orders-empty-state')), findsOneWidget);
      expect(find.text('No pending orders.'), findsOneWidget);
      expect(find.text('0 pending orders'), findsOneWidget);
    });

    testWidgets(
        'tapping order card opens order details and back navigation returns to status screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final orderRow = find.text('Rahul Auto Spares');
      expect(orderRow, findsOneWidget);
      await tester.tap(orderRow);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerOrderSummaryScreen), findsOneWidget);
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('INV-24027'), findsWidgets);

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrderStatusScreen), findsOneWidget);
      expect(find.text('Order Status'), findsOneWidget);
    });

    testWidgets('filter chips switch status views and show correct empty states',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialOrders = [
        {
          'id': 201,
          'order_number': 'INV-201',
          'partner_id': 20,
          'partner_name': 'Pending Dealer',
          'business_name': 'Pending Dealer Co',
          'partner_mobile': '+919876543210',
          'status': 'pending_approval',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 1,
          'total_quantity': 1,
          'order_total': '1000.00',
          'items': [],
        },
        {
          'id': 202,
          'order_number': 'INV-202',
          'partner_id': 21,
          'partner_name': 'Processing Dealer',
          'business_name': 'Processing Dealer Co',
          'partner_mobile': '+919876543211',
          'status': 'approved_processing',
          'created_at': '2025-10-02T11:00:00',
          'item_count': 2,
          'total_quantity': 3,
          'order_total': '2000.00',
          'items': [],
        },
        {
          'id': 203,
          'order_number': 'INV-203',
          'partner_id': 22,
          'partner_name': 'Dispatched Dealer',
          'business_name': 'Dispatched Dealer Co',
          'partner_mobile': '+919876543212',
          'status': 'dispatched',
          'created_at': '2025-10-03T12:00:00',
          'item_count': 1,
          'total_quantity': 1,
          'order_total': '500.00',
          'items': [],
        },
        {
          'id': 204,
          'order_number': 'INV-204',
          'partner_id': 23,
          'partner_name': 'Delivered Dealer',
          'business_name': 'Delivered Dealer Co',
          'partner_mobile': '+919876543213',
          'status': 'delivered',
          'created_at': '2025-10-04T13:00:00',
          'item_count': 4,
          'total_quantity': 6,
          'order_total': '4000.00',
          'items': [],
        },
      ];

      final api = _createMockStaffApi(initialOrders: initialOrders);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Pending view by default
      expect(find.text('Pending Dealer Co'), findsOneWidget);
      expect(find.text('Processing Dealer Co'), findsNothing);
      expect(find.text('1 pending order'), findsOneWidget);

      // Switch to Processing
      final processingChip = find.byKey(const Key('filter-chip-processing'));
      await tester.ensureVisible(processingChip);
      await tester.tap(processingChip);
      await tester.pumpAndSettle();

      expect(find.text('Review processing dealer invoices'), findsOneWidget);
      expect(find.text('Processing Dealer Co'), findsOneWidget);
      expect(find.text('1 processing order'), findsOneWidget);
      expect(find.byKey(const Key('staff-order-dispatch-202')), findsOneWidget);

      // Switch to Dispatched
      final dispatchedChip = find.byKey(const Key('filter-chip-dispatched'));
      await tester.ensureVisible(dispatchedChip);
      await tester.tap(dispatchedChip);
      await tester.pumpAndSettle();

      expect(find.text('Review dispatched dealer invoices'), findsOneWidget);
      expect(find.text('Dispatched Dealer Co'), findsOneWidget);
      expect(find.text('1 dispatched order'), findsOneWidget);
      expect(find.byKey(const Key('staff-order-deliver-203')), findsOneWidget);

      // Switch to Delivered
      final deliveredChip = find.byKey(const Key('filter-chip-delivered'));
      await tester.ensureVisible(deliveredChip);
      await tester.tap(deliveredChip);
      await tester.pumpAndSettle();

      expect(find.text('Review delivered dealer invoices'), findsOneWidget);
      expect(find.text('Delivered Dealer Co'), findsOneWidget);
      expect(find.text('1 delivered order'), findsOneWidget);
      expect(find.text('Delivered'), findsWidgets);

      // Switch to All
      final allChip = find.byKey(const Key('filter-chip-all'));
      await tester.ensureVisible(allChip);
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(find.text('Review all dealer invoices'), findsOneWidget);
      expect(find.text('4 orders'), findsOneWidget);
      expect(find.text('Pending Dealer Co'), findsOneWidget);
      expect(find.text('Processing Dealer Co'), findsOneWidget);
      expect(find.text('Dispatched Dealer Co'), findsOneWidget);
      expect(find.text('Delivered Dealer Co'), findsOneWidget);
    });

    testWidgets(
        'Staff can dispatch an approved_processing order with optional remarks',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? capturedStatus;
      String? capturedRemarks;

      final initialOrders = [
        {
          'id': 301,
          'order_number': 'INV-301',
          'partner_id': 20,
          'partner_name': 'Fast Wheels',
          'business_name': 'Fast Wheels Spares',
          'partner_mobile': '+919876543210',
          'status': 'approved_processing',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 2,
          'total_quantity': 4,
          'order_total': '3200.00',
          'items': [],
        },
      ];

      final api = _createMockStaffApi(
        initialOrders: initialOrders,
        onRequest: (request) {
          if (request.method == 'PATCH' &&
              request.url.path == '/api/v1/staff/orders/301/status') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            capturedStatus = body['status'] as String?;
            capturedRemarks = body['remarks'] as String?;
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Processing chip
      final procChip = find.byKey(const Key('filter-chip-processing'));
      await tester.ensureVisible(procChip);
      await tester.tap(procChip);
      await tester.pumpAndSettle();

      final dispatchBtn = find.byKey(const Key('staff-order-dispatch-301'));
      expect(dispatchBtn, findsOneWidget);
      await tester.tap(dispatchBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mark order INV-301 as dispatched?'), findsOneWidget);

      final remarksField = find.widgetWithText(
          TextField, 'Remarks / Tracking details (Optional)');
      expect(remarksField, findsOneWidget);
      await tester.enterText(remarksField, 'Courier DTDC #TRK9988');

      await tester.tap(find.byKey(const Key('confirm-dispatch-order-button')));
      await tester.pumpAndSettle();

      // Verify request payload
      expect(capturedStatus, 'dispatched');
      expect(capturedRemarks, 'Courier DTDC #TRK9988');

      // Verify SnackBar success
      expect(
          find.text('Order INV-301 marked as dispatched.'), findsOneWidget);

      // Order should now be gone from Processing filter
      expect(find.text('No processing orders.'), findsOneWidget);
    });

    testWidgets(
        'Staff can deliver a dispatched order with optional remarks',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? capturedStatus;
      String? capturedRemarks;

      final initialOrders = [
        {
          'id': 401,
          'order_number': 'INV-401',
          'partner_id': 20,
          'partner_name': 'Express Spares',
          'business_name': 'Express Spares Co',
          'partner_mobile': '+919876543210',
          'status': 'dispatched',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 1,
          'total_quantity': 2,
          'order_total': '1500.00',
          'items': [],
        },
      ];

      final api = _createMockStaffApi(
        initialOrders: initialOrders,
        onRequest: (request) {
          if (request.method == 'PATCH' &&
              request.url.path == '/api/v1/staff/orders/401/status') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            capturedStatus = body['status'] as String?;
            capturedRemarks = body['remarks'] as String?;
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Dispatched chip
      final dispatchedChip = find.byKey(const Key('filter-chip-dispatched'));
      await tester.ensureVisible(dispatchedChip);
      await tester.tap(dispatchedChip);
      await tester.pumpAndSettle();

      final deliverBtn = find.byKey(const Key('staff-order-deliver-401'));
      expect(deliverBtn, findsOneWidget);
      await tester.tap(deliverBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mark order INV-401 as delivered?'), findsOneWidget);

      final remarksField = find.widgetWithText(
          TextField, 'Remarks / Delivery notes (Optional)');
      expect(remarksField, findsOneWidget);
      await tester.enterText(remarksField, 'Delivered to store owner');

      await tester.tap(find.byKey(const Key('confirm-deliver-order-button')));
      await tester.pumpAndSettle();

      // Verify request payload
      expect(capturedStatus, 'delivered');
      expect(capturedRemarks, 'Delivered to store owner');

      // Verify SnackBar success
      expect(find.text('Order INV-401 marked as delivered.'), findsOneWidget);

      // Order should now be gone from Dispatched filter
      expect(find.text('No dispatched orders.'), findsOneWidget);
    });

    testWidgets('shows error snackbar and does not indicate success when fulfillment fails',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialOrders = [
        {
          'id': 501,
          'order_number': 'INV-501',
          'partner_id': 20,
          'partner_name': 'Error Dealer',
          'business_name': 'Error Dealer Co',
          'partner_mobile': '+919876543210',
          'status': 'approved_processing',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 1,
          'total_quantity': 1,
          'order_total': '800.00',
          'items': [],
        },
      ];

      final api = _createMockStaffApi(
        initialOrders: initialOrders,
        customHandler: (request) {
          if (request.method == 'PATCH') {
            return http.Response(
              jsonEncode({
                'detail': 'Staff is not assigned to this partner',
              }),
              403,
            );
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final procChip = find.byKey(const Key('filter-chip-processing'));
      await tester.ensureVisible(procChip);
      await tester.tap(procChip);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('staff-order-dispatch-501')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-dispatch-order-button')));
      await tester.pumpAndSettle();

      // Failure snackbar displayed
      expect(
          find.text(
              'Failed to update order status: Staff is not assigned to this partner'),
          findsOneWidget);
      // Success snackbar never displayed
      expect(find.text('Order INV-501 marked as dispatched.'), findsNothing);
    });

    testWidgets(
        'Staff Order Detail in PartnerOrderSummaryScreen shows fulfillment actions and updates status',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialOrders = [
        {
          'id': 601,
          'order_number': 'INV-601',
          'partner_id': 20,
          'partner_name': 'Detail Dealer',
          'business_name': 'Detail Dealer Spares',
          'partner_mobile': '+919876543210',
          'status': 'approved_processing',
          'created_at': '2025-10-01T10:00:00',
          'item_count': 1,
          'total_quantity': 2,
          'order_total': '1500.00',
          'items': [
            {
              'id': 1,
              'product_id': 10,
              'product_code': 'PRD-10',
              'product_name': 'Brake Pad',
              'vehicle_type': '2-Wheeler',
              'quantity': 2,
              'unit_price': '750.00',
              'subtotal': '1500.00',
            }
          ],
          'status_history': [
            {
              'id': 1,
              'order_id': 601,
              'old_status': 'pending_approval',
              'new_status': 'approved_processing',
              'remarks': 'Staff approved',
              'changed_by': 11,
              'changed_at': '2025-10-01T10:15:00',
            }
          ],
        },
      ];

      final api = _createMockStaffApi(initialOrders: initialOrders);
      final initialOrderObj =
          PartnerOrderResponse.fromJson(initialOrders.first);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            orderId: 601,
            existingOrder: initialOrderObj,
            staffApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show 'Mark as Dispatched' button for approved_processing
      final dispatchBtn =
          find.byKey(const Key('staff-detail-dispatch-button'));
      await tester.ensureVisible(dispatchBtn);
      expect(dispatchBtn, findsOneWidget);

      // Should show status history section
      expect(find.text('Status History'), findsOneWidget);
      expect(find.text('Staff approved'), findsOneWidget);

      // Tap Mark as Dispatched
      await tester.tap(dispatchBtn);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
          find.text('Update order INV-601 status to Dispatched?'),
          findsOneWidget);

      final remarksField = find.widgetWithText(
          TextField, 'Remarks / Tracking details (Optional)');
      expect(remarksField, findsOneWidget);
      await tester.enterText(remarksField, 'Handed to courier');

      await tester
          .tap(find.byKey(const Key('confirm-staff-detail-status-button')));
      await tester.pumpAndSettle();

      // SnackBar shows success
      expect(
          find.text('Order INV-601 marked as dispatched.'), findsOneWidget);

      // Now order should show 'Mark as Delivered' button
      final deliverBtn =
          find.byKey(const Key('staff-detail-deliver-button'));
      await tester.ensureVisible(deliverBtn);
      expect(deliverBtn, findsOneWidget);

      // Tap Mark as Delivered
      await tester.tap(deliverBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
          find.text('Update order INV-601 status to Delivered?'),
          findsOneWidget);

      await tester
          .tap(find.byKey(const Key('confirm-staff-detail-status-button')));
      await tester.pumpAndSettle();

      // SnackBar shows success
      expect(
          find.text('Order INV-601 marked as delivered.'), findsOneWidget);

      // Now order is delivered - no fulfillment buttons
      expect(find.byKey(const Key('staff-detail-dispatch-button')),
          findsNothing);
      expect(find.byKey(const Key('staff-detail-deliver-button')),
          findsNothing);
    });
  });
}
