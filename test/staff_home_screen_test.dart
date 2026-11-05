import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/app/app.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/staff/catalogue/staff_three_wheeler_catalogue_screen.dart';
import 'package:score_app/features/staff/catalogue/staff_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/staff/dealers/staff_dealers_associated_screen.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';
import 'package:score_app/features/staff/login/staff_login_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_status_screen.dart';
import 'package:score_app/features/staff/payment_status/staff_payment_status_screen.dart';
import 'package:score_app/features/staff/points_history/staff_points_history_screen.dart';

void main() {
  group('StaffHomeScreen Tests', () {
    testWidgets('renders redesigned StaffHomeScreen with header, New Arrivals, and 6 action buttons',
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

      // 1. Header: Authenticated staff greeting is displayed.
      expect(find.text('Welcome, Staff'), findsOneWidget);
      expect(
          find.text('Thank you for being our valuable staff'), findsOneWidget);

      // 2. Header: Centered logo is present.
      expect(find.byType(Image), findsWidgets);

      // 3. Header: Notification bell icon and red badge are absent.
      expect(find.byIcon(Icons.notifications), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      expect(find.byIcon(Icons.notifications_none), findsNothing);
      expect(find.byKey(const Key('staff_notification_badge')), findsNothing);

      // 4. Old statistics cards (Dealers, Pending Orders, Pending Payments) are removed.
      expect(find.text('Pending Orders'), findsNothing);
      expect(find.text('Pending Payments'), findsNothing);

      // 5. New Arrivals section is displayed.
      expect(find.text('New Arrivals'), findsOneWidget);
      expect(find.text('Newly Added'), findsOneWidget);
      expect(find.text('Sample Starter Motor Pro'), findsOneWidget);
      expect(find.text('Sample Disc Brake Assembly'), findsOneWidget);
      expect(find.text('Sample Piston Kit Heavy Duty'), findsOneWidget);

      // 6. Exactly six action buttons are displayed.
      expect(find.text('2W'), findsOneWidget);
      expect(find.text('3W'), findsOneWidget);
      expect(find.text('Dealers\nAssociated'), findsOneWidget);
      expect(find.text('Order\nStatus'), findsOneWidget);
      expect(find.text('Payment\nStatus'), findsOneWidget);
      expect(find.text('Points\nHistory'), findsOneWidget);

      // 7. Bottom navigation items are displayed.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping New Arrivals card opens product details bottom sheet',
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

      final arrivalCard = find.text('Sample Starter Motor Pro');
      expect(arrivalCard, findsOneWidget);
      await tester.tap(arrivalCard);
      await tester.pumpAndSettle();

      // Product details sheet opens showing code, MRP, category/type, and Close button
      expect(find.text('Code: SAMPLE-STAFF-NA-01'), findsOneWidget);
      expect(find.text('MRP'), findsWidgets);
      expect(find.text('₹ 1,550.00'), findsWidgets);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Code: SAMPLE-STAFF-NA-01'), findsNothing);
    });

    testWidgets('tapping 2W action button opens StaffTwoWheelerCatalogueScreen',
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

      final buttonFinder = find.text('2W');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffTwoWheelerCatalogueScreen), findsOneWidget);
      expect(find.text('2-Wheeler'), findsWidgets);
    });

    testWidgets('tapping 3W action button opens StaffThreeWheelerCatalogueScreen',
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

      final buttonFinder = find.text('3W');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffThreeWheelerCatalogueScreen), findsOneWidget);
      expect(find.text('3-Wheeler'), findsWidgets);
    });

    testWidgets('tapping Dealers Associated action card opens StaffDealersAssociatedScreen',
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
      expect(find.byType(StaffDealersAssociatedScreen), findsOneWidget);
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
