import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
