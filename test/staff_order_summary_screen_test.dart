import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/catalogue_models.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/features/staff/orders/staff_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_orders_screen.dart';

const _samplePartner = StaffAssignedPartner(
  id: 21,
  name: 'Nisha Partner',
  businessName: 'Nisha Traders',
  mobile: '9000000021',
  businessAddress: 'Market Road',
  partnerCode: 'PAR-21',
);

const _product1 = CatalogueProduct(
  id: 101,
  categoryId: 1,
  productCode: 'PRD-2W-01',
  name: 'Spark Plug 2W',
  vehicleType: '2-Wheeler',
  price: 150.00,
);

const _product2 = CatalogueProduct(
  id: 102,
  categoryId: 2,
  productCode: 'PRD-3W-01',
  name: 'Brake Drum 3W',
  vehicleType: '3-Wheeler',
  price: 850.00,
);

class _FakeStaffOrderApi extends StaffApi {
  _FakeStaffOrderApi();

  int? createdForPartnerId;
  List<CartItem>? createdItems;
  int callCount = 0;

  @override
  Future<PartnerOrderResponse> createOrder({
    required int partnerId,
    required List<CartItem> items,
    String? notes,
    String? idempotencyKey,
  }) async {
    callCount++;
    createdForPartnerId = partnerId;
    createdItems = List.from(items);

    return PartnerOrderResponse(
      id: 777,
      orderNumber: 'ORD-2026-777',
      partnerId: partnerId,
      partnerName: 'Nisha Partner',
      businessName: 'Nisha Traders',
      partnerMobile: '9000000021',
      status: 'pending_approval',
      createdAt: DateTime.now(),
      itemCount: items.length,
      totalQuantity: items.fold(0, (sum, i) => sum + i.quantity),
      orderTotal: items.fold(0.0, (sum, i) => sum + (i.lineTotal?.toDouble() ?? 0.0)),
    );
  }
}

void main() {
  group('StaffOrderSummaryScreen Widget Tests', () {
    testWidgets('renders an empty summary instead of sample order items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderSummaryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Screen renders
      expect(find.byType(StaffOrderSummaryScreen), findsOneWidget);

      // 2. "Order Summary" is visible
      expect(find.textContaining('Order'), findsWidgets);
      expect(find.textContaining('Summary'), findsWidgets);

      // 3. "Review your selected items" is visible
      expect(find.text('Review your selected items'), findsOneWidget);

      // 4. "ITEM" is visible
      expect(find.text('ITEM'), findsOneWidget);

      // 5. "QUANTITY" is visible
      expect(find.text('QUANTITY'), findsOneWidget);

      // 6. "MRP" is visible
      expect(find.text('MRP'), findsOneWidget);

      expect(find.text('Staff order placement is not available yet.'),
          findsOneWidget);
      expect(find.text('Tyre'), findsNothing);

      // 10. "Place Order" button is visible
      expect(find.text('Place Order'), findsOneWidget);
    });

    testWidgets(
        '11. Tapping Place Order shows the placeholder SnackBar/message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderSummaryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final placeOrderBtn = find.text('Place Order');
      await tester.ensureVisible(placeOrderBtn);
      await tester.tap(placeOrderBtn);
      await tester.pump();

      expect(
          find.text('Order placement will be available soon.'), findsOneWidget);
    });

    testWidgets('12. Back button navigation returns to Staff Orders',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrderSummaryScreen), findsOneWidget);

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrdersScreen), findsOneWidget);
    });

    testWidgets(
        'renders selected items, quantities, and MRP in dynamic summary mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderSummaryScreen(
            partner: _samplePartner,
            cartItems: const [
              CartItem(product: _product1, quantity: 2),
              CartItem(product: _product2, quantity: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dealer badge
      expect(find.text('Dealer: Nisha Traders'), findsOneWidget);

      // Selected items
      expect(find.text('Spark Plug 2W'), findsOneWidget);
      expect(find.text('Brake Drum 3W'), findsOneWidget);

      // Quantities
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Line totals
      expect(find.text('₹ 300.00'), findsOneWidget);
      expect(find.text('₹ 850.00'), findsOneWidget);

      // Grand total: 300 + 850 = 1150
      expect(find.text('₹ 1,150.00'), findsOneWidget);
      expect(find.text('3 units'), findsOneWidget);
    });

    testWidgets('removing an item from summary updates the list and total',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderSummaryScreen(
            partner: _samplePartner,
            cartItems: const [
              CartItem(product: _product1, quantity: 2),
              CartItem(product: _product2, quantity: 1),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spark Plug 2W'), findsOneWidget);
      expect(find.text('₹ 1,150.00'), findsOneWidget);

      // Tap remove button for the first item (Spark Plug 2W)
      final removeButtons = find.byTooltip('Remove');
      expect(removeButtons, findsNWidgets(2));
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      // Spark Plug 2W should now be removed
      expect(find.text('Spark Plug 2W'), findsNothing);
      expect(find.text('Brake Drum 3W'), findsOneWidget);

      // Grand total should update to ₹ 850.00
      expect(find.text('₹ 850.00'), findsWidgets);
      expect(find.text('1 units'), findsOneWidget);
    });

    testWidgets(
        'placing order calls StaffApi.createOrder with selected Dealer Partner ID and items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeStaffOrderApi();
      await tester.pumpWidget(
        MaterialApp(
          home: StaffOrderSummaryScreen(
            partner: _samplePartner,
            cartItems: const [
              CartItem(product: _product1, quantity: 2),
            ],
            orderApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final placeOrderBtn = find.text('Place Order');
      await tester.ensureVisible(placeOrderBtn);
      await tester.tap(placeOrderBtn);
      await tester.pumpAndSettle();

      // Verify that API was called with the exact Partner ID 21
      expect(api.callCount, 1);
      expect(api.createdForPartnerId, 21);
      expect(api.createdItems?.length, 1);
      expect(api.createdItems?.first.product.id, 101);
      expect(api.createdItems?.first.quantity, 2);

      // Confirmation dialog is shown
      expect(find.text('Order Placed!'), findsOneWidget);
      expect(find.text('Order #ORD-2026-777'), findsOneWidget);
      expect(find.text('Dealer: Nisha Traders'), findsWidgets);

      // Close dialog
      final closeButton = find.text('Done');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
    });
  });
}
