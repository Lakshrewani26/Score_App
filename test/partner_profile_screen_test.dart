import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  group('PartnerProfileScreen Tests', () {
    testWidgets('renders PartnerProfileScreen without fabricated account details', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Partner Profile renders
      expect(find.byType(PartnerProfileScreen), findsOneWidget);

      // 2. "Profile" is visible
      expect(find.text('Profile'), findsWidgets);

      // 3. "Your partner details" is visible
      expect(find.text('Your partner details'), findsOneWidget);

      expect(find.text('Partner'), findsOneWidget);
      expect(find.text('Partner profile'), findsOneWidget);
      expect(find.text('QR unavailable'), findsOneWidget);
      expect(find.text('Rahul Traders'), findsNothing);

      // 12. "Change Password" is NOT present
      expect(find.text('Change Password'), findsNothing);

      // 13. "Logout" is visible
      expect(find.text('Logout'), findsOneWidget);

      // 14. Home tab is visible
      expect(find.text('Home'), findsOneWidget);

      // 15. Profile tab is visible
      expect(find.text('Profile'), findsWidgets);

      // 16. Profile tab is selected (verify person_rounded icon or indicator is present)
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('17. Tapping Home opens Partner Home', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      expect(find.text('Welcome, Partner'), findsOneWidget);
    });

    testWidgets('18. Tapping Logout opens Welcome Screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Customer Login'), findsOneWidget);
      expect(find.text('Partner Login'), findsOneWidget);
      expect(find.text('Staff Login'), findsOneWidget);
    });

    testWidgets('19. Existing Partner Home -> Profile navigation works', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerProfileScreen), findsOneWidget);
      expect(find.text('Your partner details'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
    });

    testWidgets('20. Partner login does not open home without real credentials', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerLoginScreen), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsNothing);
      expect(
        find.text('Please enter both Mobile Number and Password'),
        findsOneWidget,
      );
    });
  });
}
