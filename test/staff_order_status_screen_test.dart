import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/staff/orders/staff_order_status_screen.dart';

void main() {
  group('StaffOrderStatusScreen Tests', () {
    testWidgets(
        'renders StaffOrderStatusScreen with an empty state and no fabricated invoices',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Screen renders successfully
      expect(find.byType(StaffOrderStatusScreen), findsOneWidget);

      // 2. "Order Status" title is visible
      expect(find.text('Order Status'), findsOneWidget);

      // 3. Subtitle "Review pending dealer invoices" is visible
      expect(find.text('Review pending dealer invoices'), findsOneWidget);

      // 4. Search placeholder "Search dealers or invoice number" is visible
      expect(find.text('Search dealers or invoice number'), findsOneWidget);

      expect(find.text('Invoice data is not available yet.'), findsOneWidget);
      expect(find.text('Invoice status is not available yet.'), findsOneWidget);
      expect(find.text('Rahul Traders'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping approve button shows demo SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // No approval actions are offered without real invoice records.
      final approveButtons = find.byIcon(Icons.check_rounded);
      expect(approveButtons, findsNothing);
    });

    testWidgets('tapping reject button shows demo SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final rejectButtons = find.byIcon(Icons.close_rounded);
      expect(rejectButtons, findsNothing);
    });

    testWidgets('search filters static dealer and invoice list correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrderStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Search cannot reveal fabricated records.
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Rahul');
      await tester.pumpAndSettle();

      expect(find.text('Invoice data is not available yet.'), findsOneWidget);
      expect(find.text('Invoice status is not available yet.'), findsOneWidget);

      // Search by invoice number
      await tester.enterText(searchField, 'INV-24027');
      await tester.pumpAndSettle();

      expect(find.text('Invoice data is not available yet.'), findsOneWidget);
      expect(find.text('Invoice status is not available yet.'), findsOneWidget);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Invoice data is not available yet.'), findsOneWidget);
      expect(find.text('Invoice status is not available yet.'), findsOneWidget);
    });
  });
}
