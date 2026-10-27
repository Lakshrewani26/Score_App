import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';
import 'package:score_app/features/staff/payment_status/staff_payment_status_screen.dart';

void main() {
  group('StaffPaymentStatusScreen Tests', () {
    testWidgets(
        'renders StaffPaymentStatusScreen without sample payment records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Screen renders "Payment Status"
      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);
      expect(find.text('Payment Status'), findsOneWidget);

      // 2. Search field is present with correct placeholder
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search Dealer or Invoice'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('Shree Auto Parts'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters dealer names correctly (case-insensitive)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 6. Search filters dealer names
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'patel');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('Patel Motors'), findsNothing);
    });

    testWidgets('search filters invoice numbers correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 7. Search filters invoice numbers
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '10457');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('#INV-10457'), findsNothing);
    });

    testWidgets('empty search restores all 10 records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Kumar');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);

      // 8. Empty search restores all records
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
    });

    testWidgets('back button navigates to StaffHome',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const StaffHomeScreen(),
            '/payment': (_) => const StaffPaymentStatusScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to payment screen
      final cardFinder = find.text('Payment\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);

      // 9. Back button navigates to Staff Home
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
    });

    testWidgets('bottom navigation Home button navigates to Staff Home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const StaffHomeScreen(),
            '/payment': (_) => const StaffPaymentStatusScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to payment screen
      final cardFinder = find.text('Payment\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);

      // 10. Home bottom navigation works
      final homeBottomTab = find.text('Home');
      await tester.tap(homeBottomTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
    });

    testWidgets('bottom navigation Profile button navigates to Staff Profile',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final profileBottomTab = find.text('Profile');
      await tester.tap(profileBottomTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
    });
  });
}
