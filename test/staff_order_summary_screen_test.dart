import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/staff/orders/staff_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_orders_screen.dart';

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
  });
}
