import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/app/app.dart';
import 'package:score_app/features/customer/create_account/create_account_screen.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  group('PartnerLoginScreen Tests', () {
    testWidgets(
        'renders PartnerLoginScreen with required UI elements, obscured password, and no signup/create account text',
        (WidgetTester tester) async {
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

      // 1. Partner Login screen renders
      expect(find.byType(PartnerLoginScreen), findsOneWidget);

      // 2. "Partner Login" title is visible
      expect(find.text('Partner Login'), findsOneWidget);

      // 3. Login uses the mobile number expected by the backend.
      expect(find.text('Mobile Number'), findsOneWidget);

      // 4. "Password" field is visible
      expect(find.text('Password'), findsOneWidget);

      // 5. Submit button is visible
      expect(find.text('Submit'), findsOneWidget);

      // 6. No "Sign Up" text exists
      expect(find.textContaining('Sign Up', findRichText: true), findsNothing);
      expect(find.text('Sign Up'), findsNothing);

      // 7. No "Create Account" text exists
      expect(find.textContaining('Create Account', findRichText: true),
          findsNothing);
      expect(find.text('Create Account'), findsNothing);

      // 8. Password input is obscured
      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText == true,
      );
      expect(passwordFieldFinder, findsOneWidget);

      // Empty credentials must not create a successful runtime session.
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter both Mobile Number and Password'),
          findsOneWidget);
      expect(find.textContaining('Welcome,'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'navigates Welcome -> Partner Login and back button returns to Welcome screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      // Verify Welcome screen initial state
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // 10. Partner button on Welcome opens PartnerLoginScreen
      await tester.tap(find.text('Partner Login'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerLoginScreen), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);

      // 9. Back button returns to Welcome
      final backButtonFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backButtonFinder, findsOneWidget);

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(PartnerLoginScreen), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'existing Customer Login and Customer Create Account navigation flows still work',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      // 11. Existing Customer Login navigation still works
      await tester.tap(find.text('Customer Login'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerLoginScreen), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);

      // 12. Existing Customer Create Account navigation still works
      final createAccountLink = find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Create an account'),
      );
      expect(createAccountLink, findsOneWidget);

      await tester.tap(createAccountLink);
      await tester.pumpAndSettle();

      expect(find.byType(CreateAccountScreen), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
