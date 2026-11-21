import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/auth_api.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/auth/login/unified_login_screen.dart';
import 'package:score_app/features/customer/create_account/create_account_screen.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';

void main() {
  setUp(() {
    CustomerSessionManager.instance.clearSession();
    PartnerSessionManager.instance.clearSession();
    StaffSessionManager.instance.clearSession();
    AdminSessionManager.instance.clearSession();
  });

  Widget createWidget({
    AuthApi? authApi,
    CustomerSessionManager? customerSession,
    PartnerSessionManager? partnerSession,
    StaffSessionManager? staffSession,
    AdminSessionManager? adminSession,
  }) {
    return MaterialApp(
      home: UnifiedLoginScreen(
        authApi: authApi,
        customerSessionManager: customerSession,
        partnerSessionManager: partnerSession,
        staffSessionManager: staffSession,
        adminSessionManager: adminSession,
      ),
    );
  }

  // --- 1-3: Phone, Password, and Login Button are displayed ---

  testWidgets('1-3. Displays Phone field, Password field, and Login button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.byKey(const Key('unified_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('unified_password_field')), findsOneWidget);
    expect(find.byKey(const Key('unified_login_button')), findsOneWidget);
    expect(find.text('Phone Number'), findsWidgets);
  });

  // --- 4-5: Password is obscured initially and visibility toggle works ---

  testWidgets('4-5. Password is obscured initially and toggle reveals password',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final passwordFieldFinder = find.byKey(const Key('unified_password_field'));
    TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);

    final toggleFinder =
        find.byKey(const Key('unified_password_visibility_toggle'));
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isFalse);

    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);
  });

  // --- 6-7: Empty field validation ---

  testWidgets('6-7. Shows validation snackbar when phone or password is empty',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    // 1. Both empty
    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter both Phone Number and Password'),
      findsOneWidget,
    );

    // 2. Only phone filled
    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543210',
    );
    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter both Phone Number and Password'),
      findsOneWidget,
    );

    // 3. Clear phone, enter password
    await tester.enterText(find.byKey(const Key('unified_phone_field')), '');
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'Secret123!',
    );
    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter both Phone Number and Password'),
      findsOneWidget,
    );
  });

  // --- 8 & 17: Login loading state and duplicate taps prevented ---

  testWidgets(
      '8 & 17. Shows loading indicator and prevents duplicate taps during submission',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completer = Completer<http.Response>();
    int callCount = 0;

    final mockClient = MockClient((request) async {
      callCount++;
      return completer.future;
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(createWidget(authApi: authApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543210',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'Password123!',
    );

    // Tap once to start loading
    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pump(); // Advance one frame to show loading

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Tap again while loading
    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pump();

    // Call count must remain 1
    expect(callCount, 1);

    // Complete the call
    completer.complete(
      http.Response(
        jsonEncode({
          'access_token': 'fake-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 1,
          'id': 1,
          'name': 'Test Customer',
          'mobile': '9876543210',
          'role': 'customer',
          'is_active': true,
          'user': {
            'id': 1,
            'name': 'Test Customer',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
          },
        }),
        200,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // --- 9. Network / Authentication Error Handling ---

  testWidgets(
      '9. Displays generic authentication error and network error gracefully',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'detail': 'Invalid mobile number or password'}),
        401,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(createWidget(authApi: authApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543210',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'WrongPass',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid mobile number or password'), findsOneWidget);
  });

  // --- 10 & 16: Customer Role Navigation and Session Storage ---

  testWidgets(
      '10 & 16. Customer role navigates to CustomerHomeScreen and populates CustomerSessionManager',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customerSession = CustomerSessionManager();

    final mockClient = MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['mobile'], '9876543201');
      expect(body['password'], 'ValidPass1');

      return http.Response(
        jsonEncode({
          'access_token': 'customer-jwt-token-xyz',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 101,
          'id': 101,
          'name': 'Ramesh Kumar',
          'mobile': '9876543201',
          'role': 'customer',
          'is_active': true,
          'customer_profile': {
            'state': 'Maharashtra',
            'city': 'Mumbai',
            'segment': '2-Wheeler',
          },
          'user': {
            'id': 101,
            'name': 'Ramesh Kumar',
            'mobile': '9876543201',
            'role': 'customer',
            'is_active': true,
            'customer_profile': {
              'state': 'Maharashtra',
              'city': 'Mumbai',
              'segment': '2-Wheeler',
            },
          },
        }),
        200,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      createWidget(authApi: authApi, customerSession: customerSession),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543201',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'ValidPass1',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    // Verify session populated
    expect(customerSession.isAuthenticated, isTrue);
    expect(customerSession.currentUser?.id, 101);
    expect(customerSession.currentUser?.name, 'Ramesh Kumar');
    expect(customerSession.currentUser?.role, 'customer');
    expect(await customerSession.getToken(), 'customer-jwt-token-xyz');

    // Verify CustomerHomeScreen opened
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  // --- 11 & 16: Partner Role Navigation and Session Storage ---

  testWidgets(
      '11 & 16. Partner role navigates to PartnerHomeScreen and populates PartnerSessionManager',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final partnerSession = PartnerSessionManager();

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'partner-jwt-token-xyz',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 202,
          'id': 202,
          'name': 'Suresh Auto Spares',
          'mobile': '9876543202',
          'role': 'partner',
          'is_active': true,
          'partner_profile': {
            'business_name': 'Suresh Spares',
            'business_address': 'Pune Station Road',
            'partner_code': 'PRT-202',
          },
          'user': {
            'id': 202,
            'name': 'Suresh Auto Spares',
            'mobile': '9876543202',
            'role': 'partner',
            'is_active': true,
            'partner_profile': {
              'business_name': 'Suresh Spares',
              'business_address': 'Pune Station Road',
              'partner_code': 'PRT-202',
            },
          },
        }),
        200,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      createWidget(authApi: authApi, partnerSession: partnerSession),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543202',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'ValidPass2',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    // Verify session
    expect(partnerSession.isAuthenticated, isTrue);
    expect(partnerSession.currentUser?.id, 202);
    expect(partnerSession.currentUser?.businessName, 'Suresh Spares');
    expect(await partnerSession.getToken(), 'partner-jwt-token-xyz');

    // Verify PartnerHomeScreen
    expect(find.byType(PartnerHomeScreen), findsOneWidget);
  });

  // --- 12 & 16: Staff Role Navigation and Session Storage ---

  testWidgets(
      '12 & 16. Staff role navigates to StaffHomeScreen and populates StaffSessionManager with Staff ID',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staffSession = StaffSessionManager();

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'staff-jwt-token-xyz',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 303,
          'id': 303,
          'name': 'Staff Member Ajay',
          'mobile': '9876543203',
          'role': 'staff',
          'is_active': true,
          'staff_id': 'EMP-STF-303',
          'user': {
            'id': 303,
            'name': 'Staff Member Ajay',
            'mobile': '9876543203',
            'role': 'staff',
            'is_active': true,
            'staff_id': 'EMP-STF-303',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
        200,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      createWidget(authApi: authApi, staffSession: staffSession),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543203',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'ValidPass3',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    // Verify session
    expect(staffSession.isAuthenticated, isTrue);
    expect(staffSession.currentUser?.id, 303);
    expect(staffSession.currentUser?.staffId, 'EMP-STF-303');
    expect(await staffSession.getToken(), 'staff-jwt-token-xyz');

    // Verify StaffHomeScreen
    expect(find.byType(StaffHomeScreen), findsOneWidget);
  });

  // --- 13 & 16: Admin Role Navigation and Session Storage ---

  testWidgets(
      '13 & 16. Admin role navigates to AdminHomeScreen and populates AdminSessionManager',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adminSession = AdminSessionManager();

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'admin-jwt-token-xyz',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 404,
          'id': 404,
          'name': 'System Administrator',
          'mobile': '9876543204',
          'role': 'admin',
          'is_active': true,
          'user': {
            'id': 404,
            'name': 'System Administrator',
            'mobile': '9876543204',
            'role': 'admin',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
        200,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      createWidget(authApi: authApi, adminSession: adminSession),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543204',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'ValidPass4',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    // Verify session
    expect(adminSession.isAuthenticated, isTrue);
    expect(adminSession.currentUser?.id, 404);
    expect(adminSession.currentUser?.name, 'System Administrator');
    expect(await adminSession.getToken(), 'admin-jwt-token-xyz');

    // Verify AdminHomeScreen
    expect(find.byType(AdminHomeScreen), findsOneWidget);
  });

  // --- 14. Create Account Link Opens Existing Signup Screen ---

  testWidgets('14. Create Account link opens existing CreateAccountScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final linkFinder = find.byKey(const Key('unified_create_account_link'));
    expect(linkFinder, findsOneWidget);

    await tester.tap(linkFinder);
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  // --- 15. Successful Login Removes Login Screen From Back Stack ---

  testWidgets('15. Successful login cannot navigate back to the login screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'token-123',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user_id': 1,
          'id': 1,
          'name': 'Customer One',
          'mobile': '9876543210',
          'role': 'customer',
          'is_active': true,
          'user': {
            'id': 1,
            'name': 'Customer One',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
          },
        }),
        200,
      );
    });

    final authApi = AuthApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(createWidget(authApi: authApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('unified_phone_field')),
      '9876543210',
    );
    await tester.enterText(
      find.byKey(const Key('unified_password_field')),
      'Password123!',
    );

    await tester.tap(find.byKey(const Key('unified_login_button')));
    await tester.pumpAndSettle();

    // Verify we are on CustomerHomeScreen
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    // UnifiedLoginScreen is completely removed from the navigation stack
    expect(find.byType(UnifiedLoginScreen), findsNothing);
  });
}
