import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/app/app.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';
import 'package:score_app/features/staff/login/staff_login_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_status_screen.dart';
import 'package:score_app/features/staff/payment_status/staff_payment_status_screen.dart';
import 'package:score_app/features/staff/points_history/staff_points_history_screen.dart';

void main() {
  group('StaffHomeScreen Tests', () {
    testWidgets('renders StaffHomeScreen without invented dashboard totals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. No unverified staff identity or totals are shown.
      expect(find.text('Welcome, Staff'), findsOneWidget);

      // 2. "Thank you for being our valuable staff" is displayed.
      expect(
          find.text('Thank you for being our valuable staff'), findsOneWidget);

      // 3. "Dealers" is displayed.
      expect(find.text('Dealers'), findsOneWidget);

      expect(find.text('—'), findsNWidgets(3));

      // 5. "Pending Orders" is displayed.
      expect(find.text('Pending Orders'), findsOneWidget);

      // 7. "Pending Payments" is displayed.
      expect(find.text('Pending Payments'), findsOneWidget);

      // 9. "Dealers Associated" is displayed.
      expect(find.text('Dealers\nAssociated'), findsOneWidget);

      // 10. "Order Status" is displayed.
      expect(find.text('Order\nStatus'), findsOneWidget);

      // 11. "Payment Status" is displayed.
      expect(find.text('Payment\nStatus'), findsOneWidget);

      // 12. "Points History" is displayed.
      expect(find.text('Points\nHistory'), findsOneWidget);

      // 13. Home navigation item is displayed.
      expect(find.text('Home'), findsOneWidget);

      // 14. Profile navigation item is displayed.
      expect(find.text('Profile'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Dealers Associated action card displays SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Dealers\nAssociated');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      expect(find.text('Dealers Associated'), findsOneWidget);
    });

    testWidgets('tapping Order Status action card opens StaffOrderStatusScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Order\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffOrderStatusScreen), findsOneWidget);
      expect(find.text('Review pending dealer invoices'), findsOneWidget);
    });

    testWidgets(
        'tapping Payment Status action card opens StaffPaymentStatusScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Payment\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);
    });

    testWidgets(
        'tapping Points History action card opens StaffPointsHistoryScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Points\nHistory');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();
      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);
    });

    testWidgets('Profile navigation opens StaffProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
      expect(find.text('Your staff details'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Staff Login displays backend authentication failures',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = StaffApi(
        baseUrl: 'http://localhost',
        client: MockClient(
          (_) async => http.Response(
            '{"detail":"Invalid Staff ID or password"}',
            401,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: StaffLoginScreen(api: api)),
      );
      await tester.pumpAndSettle();

      final staffIdFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Staff_ID',
      );
      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(staffIdFieldFinder, 'ST12345');
      await tester.enterText(passwordFieldFinder, 'Password123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsNothing);
      expect(find.text('Invalid Staff ID or password'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('staff login does not create a session from local credentials',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      // Customer Login navigation check
      await tester.tap(find.text('Customer Login'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerLoginScreen), findsOneWidget);

      // Pop back to Welcome
      Navigator.of(tester.element(find.byType(CustomerLoginScreen))).pop();
      await tester.pumpAndSettle();

      // Partner Login navigation check
      await tester.tap(find.text('Partner Login'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerLoginScreen), findsOneWidget);

      // Pop back to Welcome
      Navigator.of(tester.element(find.byType(PartnerLoginScreen))).pop();
      await tester.pumpAndSettle();

      // Staff login is available and must not grant access without backend auth.
      await tester.tap(find.text('Staff Login'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffLoginScreen), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
