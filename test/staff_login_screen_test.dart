import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/app/app.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/staff/login/staff_login_screen.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

class _FakeStaffApi extends StaffApi {
  _FakeStaffApi({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<StaffAuthResponse> login({
    required String staffId,
    required String password,
  }) async {
    if (shouldFail) {
      throw const StaffApiException('Invalid Staff ID or password',
          statusCode: 401);
    }
    return const StaffAuthResponse(
      accessToken: 'staff-token',
      user: StaffUser(
        id: 5,
        name: 'Test Staff',
        mobile: '9000000001',
        role: 'staff',
        isActive: true,
        staffId: 'STF-001',
      ),
    );
  }

  @override
  Future<StaffUser> getMe({String? token}) async {
    expect(token, 'staff-token');
    return const StaffUser(
      id: 5,
      name: 'Test Staff',
      mobile: '9000000001',
      role: 'staff',
      isActive: true,
      staffId: 'STF-001',
    );
  }
}

void main() {
  group('StaffLoginScreen Tests', () {
    testWidgets(
        'renders StaffLoginScreen with all required UI elements, obscured password, and no signup/forgot password UI',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Staff Login screen renders
      expect(find.byType(StaffLoginScreen), findsOneWidget);

      // 2. "Staff Login" title is displayed
      expect(find.text('Staff Login'), findsOneWidget);

      // 3. Staff_ID field is displayed
      expect(find.text('Staff_ID'), findsOneWidget);

      // 4. Password field is displayed
      expect(find.text('Password'), findsOneWidget);

      // 5. Submit button is displayed
      expect(find.text('Submit'), findsOneWidget);

      // 6. No "Sign Up" or "Create Account" text exists
      expect(find.textContaining('Sign Up', findRichText: true), findsNothing);
      expect(find.textContaining('Create Account', findRichText: true),
          findsNothing);
      expect(find.textContaining('Create an account', findRichText: true),
          findsNothing);

      // 7. No "Forgot Password" text exists
      expect(find.textContaining('Forgot Password', findRichText: true),
          findsNothing);

      // 8. Password input is obscured
      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText == true,
      );
      expect(passwordFieldFinder, findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts text input in Staff_ID and Password fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Staff_ID field and enter text
      final staffIdFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Staff_ID',
      );
      expect(staffIdFieldFinder, findsOneWidget);
      await tester.enterText(staffIdFieldFinder, 'ST12345');
      await tester.pump();
      expect(find.text('ST12345'), findsOneWidget);

      // Find Password field and enter text
      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );
      expect(passwordFieldFinder, findsOneWidget);
      await tester.enterText(passwordFieldFinder, 'Pass1234');
      await tester.pump();
      expect(find.text('Pass1234'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'empty Staff_ID or Password triggers frontend validation message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Validation snackbar message appears
      expect(
          find.text('Please enter both Staff ID and Password'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the real API error when Staff login fails',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffLoginScreen(api: _FakeStaffApi(shouldFail: true)),
        ),
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

      await tester.enterText(staffIdFieldFinder, 'ST999');
      await tester.enterText(passwordFieldFinder, 'Secret123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Staff ID or password'), findsOneWidget);
      expect(find.byType(StaffHomeScreen), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'verifies and saves the backend Staff session before navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StaffLoginScreen(
            api: _FakeStaffApi(),
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'Staff_ID',
        ),
        'STF-001',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.hintText == 'Password',
        ),
        'Secret123',
      );
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(session.currentUser?.name, 'Test Staff');
      expect(await session.getToken(), 'staff-token');
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigates from Welcome screen to Staff Login screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Tap Staff Login option on Welcome screen
      await tester.tap(find.text('Staff Login'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffLoginScreen), findsOneWidget);
      expect(find.text('Staff_ID'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'existing Customer and Partner navigation flows remain unaffected',
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

      expect(tester.takeException(), isNull);
    });
  });
}
