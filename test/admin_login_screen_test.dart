import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/app/app.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/admin/login/admin_login_screen.dart';
import 'package:score_app/features/admin/settings/admin_settings_screen.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/staff/login/staff_login_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  const mockLoginJson = {
    'access_token': 'test_admin_jwt_token',
    'token_type': 'bearer',
    'expires_in': 86400,
    'user': {
      'id': 1,
      'name': 'Super Admin',
      'mobile': '9876543210',
      'role': 'admin',
      'is_active': true,
      'created_at': '2026-10-25T18:50:00',
    },
  };

  const mockMeJson = {
    'id': 1,
    'name': 'Super Admin',
    'mobile': '9876543210',
    'role': 'admin',
    'is_active': true,
    'created_at': '2026-10-25T18:50:00',
  };

  group('WelcomeScreen Admin Login Navigation Tests', () {
    testWidgets('Welcome screen displays the Admin Login option',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Please select your login type'), findsOneWidget);
      expect(find.text('Customer Login'), findsOneWidget);
      expect(find.text('Partner Login'), findsOneWidget);
      expect(find.text('Staff Login'), findsOneWidget);
      expect(find.text('Admin Login'), findsOneWidget);
    });

    testWidgets(
        'Selecting Admin Login on Welcome screen opens AdminLoginScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Admin Login'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets(
        'Existing Customer, Partner, and Staff navigation remain unaffected',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      // 1. Customer Login navigation
      await tester.tap(find.text('Customer Login'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerLoginScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(CustomerLoginScreen))).pop();
      await tester.pumpAndSettle();

      // 2. Partner Login navigation
      await tester.tap(find.text('Partner Login'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerLoginScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(PartnerLoginScreen))).pop();
      await tester.pumpAndSettle();

      // 3. Staff Login navigation
      await tester.tap(find.text('Staff Login'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffLoginScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(StaffLoginScreen))).pop();
      await tester.pumpAndSettle();

      // Confirm back on Welcome
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('AdminLoginScreen UI and Validation Tests', () {
    testWidgets(
        'renders all required elements and NO signup or registration links',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('Admin Login'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verify NO registration or forgot password UI
      expect(find.textContaining('Sign Up', findRichText: true), findsNothing);
      expect(find.textContaining('Create Account', findRichText: true),
          findsNothing);
      expect(find.textContaining('Create an account', findRichText: true),
          findsNothing);
      expect(find.textContaining('Forgot Password', findRichText: true),
          findsNothing);
      expect(find.textContaining('Register', findRichText: true), findsNothing);
    });

    testWidgets('password field toggles visibility via show/hide icon button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Password starts obscured
      final obscuredFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.obscureText == true,
      );
      expect(obscuredFinder, findsOneWidget);

      // Tap visibility icon
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pumpAndSettle();

      // Now unobscured
      final unobscuredFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Password' &&
            widget.obscureText == false,
      );
      expect(unobscuredFinder, findsOneWidget);

      // Tap again to obscure
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pumpAndSettle();

      expect(obscuredFinder, findsOneWidget);
    });

    testWidgets('empty mobile or password inputs trigger validation snackbar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Both empty
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter both Mobile Number and Password'),
          findsOneWidget);

      // 2. Only mobile entered
      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      await tester.enterText(mobileFinder, '9876543210');
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter both Mobile Number and Password'),
          findsOneWidget);
    });

    testWidgets('back button pops or navigates back to Welcome',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ScoreApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Admin Login'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('AdminLoginScreen Backend Authentication & Dashboard Integration Tests',
      () {
    testWidgets(
        'successful login and profile verification navigates to AdminHomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/admin/login') {
          return http.Response(jsonEncode(mockLoginJson), 200);
        }
        if (request.url.path == '/api/v1/admin/me') {
          expect(
              request.headers['Authorization'], 'Bearer test_admin_jwt_token');
          return http.Response(jsonEncode(mockMeJson), 200);
        }
        return http.Response('Not Found', 404);
      });

      final api = AdminApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(
            adminApi: api,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Navigated to AdminHomeScreen
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(find.text('Welcome, Super Admin'), findsOneWidget);
      expect(find.text('Score Admin Dashboard'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Catalogue Management'), findsOneWidget);
      expect(find.text('Orders & Requests'), findsNothing);
      expect(find.text('Reports & Analytics'), findsNothing);

      // Session saved in memory
      expect(sessionManager.isAuthenticated, isTrue);
      expect(sessionManager.currentUser?.name, 'Super Admin');
      expect(await sessionManager.getToken(), 'test_admin_jwt_token');
    });

    testWidgets('verification failure via /admin/me prevents opening dashboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/admin/login') {
          return http.Response(jsonEncode(mockLoginJson), 200);
        }
        if (request.url.path == '/api/v1/admin/me') {
          // Profile verification fails (e.g., token invalid or account deactivated)
          return http.Response(
              jsonEncode({'detail': 'Token has expired'}), 401);
        }
        return http.Response('Not Found', 404);
      });

      final api = AdminApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(
            adminApi: api,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Dashboard NOT opened
      expect(find.byType(AdminHomeScreen), findsNothing);
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('Token has expired'), findsOneWidget);
      expect(sessionManager.isAuthenticated, isFalse);
    });

    testWidgets('invalid credentials 401 displays error snackbar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid mobile number or password'}),
          401,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'WrongPass');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid mobile number or password'), findsOneWidget);
      expect(find.byType(AdminHomeScreen), findsNothing);
    });

    testWidgets('inactive account 403 displays deactivated message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Account is deactivated'}),
          403,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Account is deactivated'), findsOneWidget);
      expect(find.byType(AdminHomeScreen), findsNothing);
    });

    testWidgets('non-admin access denial 403 displays privilege error',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Access denied: Admin privileges required'}),
          403,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Access denied: Admin privileges required'),
          findsOneWidget);
      expect(find.byType(AdminHomeScreen), findsNothing);
    });

    testWidgets('network failure displays friendly network error message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Network error'), findsOneWidget);
      expect(find.byType(AdminHomeScreen), findsNothing);
    });

    testWidgets('server error 500 displays friendly server error message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(
          find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.byType(AdminHomeScreen), findsNothing);
    });

    testWidgets(
        'loading state prevents duplicate submission while request in progress',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<http.Response>();
      int requestCount = 0;

      final client = MockClient((request) {
        requestCount++;
        return completer.future;
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: AdminLoginScreen(adminApi: api),
        ),
      );
      await tester.pumpAndSettle();

      final mobileFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Mobile Number',
      );
      final passwordFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );

      await tester.enterText(mobileFinder, '9876543210');
      await tester.enterText(passwordFinder, 'Admin@123');
      await tester.pump();

      // First tap begins async request
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Progress indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(requestCount, 1);

      // Second tap while loading should NOT increase request count
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(requestCount, 1);

      // Complete request
      completer.complete(
        http.Response(
            jsonEncode({'detail': 'Invalid mobile number or password'}), 401),
      );
      await tester.pumpAndSettle();

      // Spinner dismissed, error shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Invalid mobile number or password'), findsOneWidget);
    });
  });

  group('AdminHomeScreen and Logout Tests', () {
    testWidgets(
        'Dashboard displays authenticated Admin details and placeholder module tiles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminHomeScreen(adminUser: mockAdminUser),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Super Admin'), findsOneWidget);
      expect(find.text('Score Admin Dashboard'), findsOneWidget);
      expect(find.text('Mobile: 9876543210'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Module placeholders
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Catalogue Management'), findsOneWidget);
      expect(find.text('System Settings'), findsOneWidget);
      expect(find.text('Orders & Requests'), findsNothing);
      expect(find.text('Partner orders & stock requests'), findsNothing);
      expect(find.text('Reports & Analytics'), findsNothing);
      expect(find.text('Transaction logs & points history'), findsNothing);

      // Tapping System Settings navigates to AdminSettingsScreen
      await tester.scrollUntilVisible(find.text('System Settings'), 100);
      await tester.tap(find.text('System Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSettingsScreen), findsOneWidget);
    });

    testWidgets(
        'Profile menu Logout confirms, clears authentication state, and returns to WelcomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'active_token', user: mockAdminUser);
      expect(sessionManager.isAuthenticated, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open profile popup menu via avatar button
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Tap Logout option from popup menu
      expect(find.byKey(const Key('profile_menu_logout')), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile_menu_logout')));
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(
          find.text('Are you sure you want to log out of your Admin session?'),
          findsOneWidget);

      // Confirm logout
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      // Navigated to WelcomeScreen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Logged out of Admin session'), findsOneWidget);

      // Session cleared
      expect(sessionManager.isAuthenticated, isFalse);
      expect(sessionManager.currentUser, isNull);
      expect(await sessionManager.getToken(), isNull);
    });

    testWidgets('Profile menu Logout can be cancelled without clearing session',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'active_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open profile popup menu
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Select Logout
      await tester.tap(find.byKey(const Key('profile_menu_logout')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Logout'), findsOneWidget);

      // Cancel logout
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still on AdminHomeScreen and session intact
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(sessionManager.isAuthenticated, isTrue);
    });

    testWidgets(
        'Direct unauthenticated access to AdminHomeScreen displays access denial',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptySession =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: null,
            sessionManager: emptySession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Return to Welcome'), findsOneWidget);

      await tester.tap(find.text('Return to Welcome'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });
}
