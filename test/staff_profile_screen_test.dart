import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/login/staff_login_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  group('StaffProfileScreen Tests', () {
    testWidgets(
        'shows the authenticated Staff profile and clears session on logout',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-token',
        user: const StaffUser(
          id: 9,
          name: 'Staff Name',
          mobile: '9000000009',
          role: 'staff',
          isActive: true,
          staffId: 'STF-009',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: StaffProfileScreen(sessionManager: session)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Staff Name'), findsOneWidget);
      expect(find.text('Staff ID: STF-009'), findsOneWidget);
      expect(find.text('9000000009'), findsOneWidget);
      expect(find.text('STF-009'), findsOneWidget);

      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(session.currentUser, isNull);
      expect(await session.getToken(), isNull);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets(
        'renders StaffProfileScreen without fabricated details or QR code',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Staff Profile screen renders
      expect(find.byType(StaffProfileScreen), findsOneWidget);

      // 2. "Profile" heading is visible
      expect(find.text('Profile'), findsWidgets);

      // 3. The Staff profile subtitle is visible.
      expect(find.text('Your staff details'), findsOneWidget);

      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Profile details unavailable'), findsOneWidget);
      expect(find.text('Not available'), findsNWidgets(2));
      expect(find.text('QR unavailable'), findsOneWidget);

      // 11. "Change Password" is NOT present
      expect(find.text('Change Password'), findsNothing);

      // 12. "Logout" is visible
      expect(find.text('Logout'), findsOneWidget);

      // 13. Home/Profile bottom navigation is visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsWidgets);

      expect(find.text('Rahul Traders'), findsNothing);
      expect(find.text('Rahul_Trs'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('15. Tapping Home navigates to Staff Home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(find.text('Welcome, Staff'), findsOneWidget);
    });

    testWidgets(
        '16. Tapping Logout navigates to Welcome Screen and Change Password is not present',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);

      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Customer Login'), findsOneWidget);
      expect(find.text('Partner Login'), findsOneWidget);
      expect(find.text('Staff Login'), findsOneWidget);
    });

    testWidgets('17. Existing Staff Home -> Profile navigation works',
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

      expect(find.byType(StaffHomeScreen), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
      expect(find.text('Your staff details'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
    });

    testWidgets('18. Staff login does not open home without backend auth',
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

      expect(find.byType(StaffLoginScreen), findsOneWidget);

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
      expect(
        find.text('Invalid Staff ID or password'),
        findsOneWidget,
      );
    });
  });
}
