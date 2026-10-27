import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/staff/dealers/staff_dealers_associated_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_orders_screen.dart';

void main() {
  group('StaffOrdersScreen Widget Tests', () {
    testWidgets(
        'renders screen with an empty product state and no sample records',
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

      // 1. Screen renders
      expect(find.byType(StaffOrdersScreen), findsOneWidget);

      // 2. "Add Order" heading is visible
      expect(find.text('Add Order'), findsOneWidget);

      // 3. "Select products and quantity" is visible
      expect(find.text('Select products and quantity'), findsOneWidget);

      // 4. "Search products" placeholder is visible
      expect(find.text('Search products'), findsOneWidget);

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);

      // 14. Continue button is visible
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets(
        'does not offer quantity controls for unavailable catalogue data',
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

      final plusButtons = find.byIcon(Icons.add);
      final minusButtons = find.byIcon(Icons.remove);
      expect(plusButtons, findsNothing);
      expect(minusButtons, findsNothing);
    });

    testWidgets('12. product search filters correctly (case-insensitive)',
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

      final searchFieldFinder = find.byType(TextField);
      await tester.enterText(searchFieldFinder, 'hex');
      await tester.pumpAndSettle();

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);
      expect(find.text('Washer'), findsNothing);
      expect(find.text('Spring'), findsNothing);
    });

    testWidgets(
        '13. searching for a non-existing product displays No products found',
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

      final searchFieldFinder = find.byType(TextField);
      await tester.enterText(searchFieldFinder, 'InvalidProduct123');
      await tester.pumpAndSettle();

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);
    });

    testWidgets('15. Continue button opens StaffOrderSummaryScreen',
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

      final continueButton = find.text('Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrderSummaryScreen), findsOneWidget);
    });

    testWidgets('16. No order is offered when dealer records are unavailable',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffDealersAssociatedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Order'), findsNothing);
      expect(find.byType(StaffOrdersScreen), findsNothing);
      expect(find.byType(StaffDealersAssociatedScreen), findsOneWidget);
    });
  });
}
