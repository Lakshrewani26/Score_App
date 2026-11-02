import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/partner_order_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';

void main() {
  group('PartnerOrderSummaryScreen Tests', () {
    testWidgets(
        'renders PartnerOrderSummaryScreen without fabricated sample items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerOrderSummaryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Order Summary screen renders
      expect(find.byType(PartnerOrderSummaryScreen), findsOneWidget);

      // 2. "Order Summary" is visible
      expect(find.text('Order Summary'), findsOneWidget);

      // 3. "Review your selected items" is visible
      expect(find.text('Review your selected items'), findsOneWidget);

      // 4. "ITEM", "QUANTITY", and "MRP" headers are visible
      expect(find.text('ITEM'), findsOneWidget);
      expect(find.text('QUANTITY'), findsOneWidget);
      expect(find.text('MRP'), findsOneWidget);

      expect(find.text('No items in order summary'), findsOneWidget);
      expect(find.text('Tyre'), findsNothing);

      // 8. "Place Order" button exists
      expect(find.text('Place Order'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Place Order reports that the cart is empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerOrderSummaryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final placeOrderFinder = find.text('Place Order');
      await tester.ensureVisible(placeOrderFinder);
      await tester.pumpAndSettle();
      await tester.tap(placeOrderFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('No items in order summary to place.'),
        findsOneWidget,
      );
    });

    testWidgets('Back button returns to PartnerTwoWheelerCatalogueScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerOrderSummaryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTwoWheelerCatalogueScreen), findsOneWidget);
    });

    testWidgets('renders existing order in View mode with items and totals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(
        token: 'test-token',
        user: const PartnerUser(
          id: 5,
          name: 'Ramesh',
          mobile: '9876543210',
          role: 'partner',
          businessName: 'Ramesh Auto Parts',
        ),
      );

      final existingOrder = PartnerOrderResponse(
        id: 201,
        orderNumber: 'INV-99001',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2025, 10, 15, 12, 30),
        itemCount: 1,
        totalQuantity: 4,
        orderTotal: 1000.0,
        items: const [
          PartnerOrderItemResponse(
            id: 1,
            productId: 10,
            productCode: 'TY-01',
            productName: 'Tubeless Tyre 90/90-12',
            vehicleType: '2-Wheeler',
            quantity: 4,
            unitPrice: 250.0,
            subtotal: 1000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and partner details
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Invoice #INV-99001'), findsOneWidget);
      expect(find.text('Ramesh Auto Parts'), findsOneWidget);
      expect(find.text('Pending Approval'), findsOneWidget);

      // Order items
      expect(find.text('Tubeless Tyre 90/90-12'), findsOneWidget);
      expect(find.text('TY-01 · ₹ 250.00'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('₹ 1000.00'), findsOneWidget);

      // Grand total
      expect(find.byKey(const Key('order-grand-total-text')), findsOneWidget);
      expect(find.text('₹ 1,000.00'), findsOneWidget);

      // Action buttons
      expect(find.byKey(const Key('download-pdf-button')), findsOneWidget);
      expect(find.byKey(const Key('cancel-order-button')), findsOneWidget);
    });

    testWidgets('View mode allows cancelling pending order with confirmation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(
        token: 'test-token',
        user: const PartnerUser(
          id: 5,
          name: 'Ramesh',
          mobile: '9876543210',
          role: 'partner',
        ),
      );

      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/orders/201/cancel') {
          return http.Response(
            jsonEncode({
              'id': 201,
              'order_number': 'INV-99001',
              'partner_id': 5,
              'partner_name': 'Ramesh',
              'partner_mobile': '9876543210',
              'status': 'cancelled',
              'created_at': '2025-10-15T12:30:00',
              'item_count': 1,
              'total_quantity': 4,
              'order_total': '1000.00',
              'items': [],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final api = PartnerOrderApi(client: client, sessionManager: session);

      final existingOrder = PartnerOrderResponse(
        id: 201,
        orderNumber: 'INV-99001',
        partnerId: 5,
        partnerName: 'Ramesh',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2025, 10, 15, 12, 30),
        itemCount: 1,
        totalQuantity: 4,
        orderTotal: 1000.0,
        items: const [
          PartnerOrderItemResponse(
            id: 1,
            productId: 10,
            productCode: 'TY-01',
            productName: 'Tubeless Tyre 90/90-12',
            vehicleType: '2-Wheeler',
            quantity: 4,
            unitPrice: 250.0,
            subtotal: 1000.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            api: api,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cancelBtn = find.byKey(const Key('cancel-order-button'));
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog confirms
      expect(find.widgetWithText(AlertDialog, 'Cancel Order'), findsOneWidget);
      expect(find.text('Are you sure you want to cancel order INV-99001?'),
          findsOneWidget);

      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();

      expect(
          find.text('Order INV-99001 has been cancelled successfully.'),
          findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(
          find.text('Order is Cancelled and cannot be cancelled.'),
          findsOneWidget);
    });
  });
}
