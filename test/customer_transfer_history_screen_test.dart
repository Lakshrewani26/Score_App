import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/profile/customer_profile_screen.dart';
import 'package:score_app/features/customer/transfer_history/customer_transfer_history_screen.dart';

void main() {
  testWidgets('displays an honest empty state without fabricated transactions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header & Title elements
    expect(find.text('Transfer History'), findsOneWidget);
    expect(find.text('View your recent transfer transactions'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    expect(
      find.byKey(const Key('customer-transfer-history-empty-state')),
      findsOneWidget,
    );
    expect(find.text('Amit Sharma'), findsNothing);

    // 4. Bottom Navigation Bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // 6. Verify no layout exceptions
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction container has bounded height leaving visible background space below it', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-transfer-history-empty-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state preserves the fixed header and bottom nav', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial state
    expect(find.text('Transfer History'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    expect(
      find.byKey(const Key('customer-transfer-history-empty-state')),
      findsOneWidget,
    );
    expect(find.text('Transfer History'), findsOneWidget);
    expect(find.text('View your recent transfer transactions'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates from CustomerHomeScreen to CustomerTransferHistoryScreen when Points History is tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Points History'), findsOneWidget);
    await tester.ensureVisible(find.text('Points History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Points History'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerTransferHistoryScreen), findsOneWidget);
    expect(find.text('View your recent transfer transactions'), findsOneWidget);
    expect(
      find.byKey(const Key('customer-transfer-history-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('navigates from CustomerTransferHistoryScreen to CustomerHomeScreen via top back button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Points History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Points History'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerTransferHistoryScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('navigates from CustomerTransferHistoryScreen to CustomerHomeScreen via bottom nav Home button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('navigates from CustomerTransferHistoryScreen to CustomerProfileScreen via bottom nav Profile button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerProfileScreen), findsOneWidget);
  });
}
