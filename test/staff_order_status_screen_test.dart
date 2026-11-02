import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_status_screen.dart';

StaffApi _createMockStaffApi({
  List<Map<String, dynamic>>? initialOrders,
  void Function(http.Request)? onRequest,
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

  var orders = initialOrders ??
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
          'items': [],
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
          'items': [],
        },
      ];

  final client = MockClient((request) async {
    onRequest?.call(request);
    expect(request.headers['Authorization'], 'Bearer test-staff-token');

    if (request.method == 'GET' &&
        request.url.path == '/api/v1/staff/orders') {
      return http.Response(jsonEncode(orders), 200);
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
  });
}
