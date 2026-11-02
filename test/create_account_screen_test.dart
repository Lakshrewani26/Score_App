import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/customer_api.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/features/customer/create_account/create_account_screen.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';

void main() {
  testWidgets('displays the Create Account screen with all required fields and options', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateAccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Logo
    expect(find.text('Create Account'), findsNWidgets(2)); // Heading text + Button text
    expect(find.byType(Image), findsOneWidget);

    // Verify Fields
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Segment'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify Login link text in RichText
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Already have an account?') &&
            widget.text.toPlainText().contains('Login here'),
      ),
      findsOneWidget,
    );

    // Verify Segment Dropdown interaction and exact options
    final segmentDropdown = find.text('Segment');
    await tester.tap(segmentDropdown, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('2-Wheeler'), findsOneWidget);
    expect(find.text('3-Wheeler'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);

    // Tap '2-Wheeler' option
    await tester.tap(find.text('2-Wheeler').last);
    await tester.pumpAndSettle();

    expect(find.text('2-Wheeler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates from CustomerLoginScreen to CreateAccountScreen when Create an account is tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoginScreen), findsOneWidget);

    final createAccountLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('New user?') &&
          widget.text.toPlainText().contains('Create an account'),
    );
    expect(createAccountLink, findsOneWidget);

    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('navigates from CreateAccountScreen to CustomerLoginScreen when Login link is tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerLoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Go to CreateAccountScreen first
    final createAccountLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('New user?') &&
          widget.text.toPlainText().contains('Create an account'),
    );
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsOneWidget);

    // Now tap Login link on CreateAccountScreen
    final loginLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Already have an account?') &&
          widget.text.toPlainText().contains('Login here'),
    );
    expect(loginLink, findsOneWidget);

    await tester.tap(loginLink);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerLoginScreen), findsOneWidget);
  });

  testWidgets('navigates from CreateAccountScreen to CustomerHomeScreen when top back/home button is tapped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateAccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateAccountScreen), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('shows validation snackbar when full name is empty',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateAccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name is required'), findsOneWidget);
  });

  testWidgets('shows validation snackbar when phone number is empty or short',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateAccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Aditi Verma');
    await tester.enterText(textFields.at(1), '12345');
    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter a valid phone number (at least 10 digits)'),
      findsOneWidget,
    );
  });

  testWidgets('shows validation snackbar when password is empty or short',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateAccountScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Aditi Verma');
    await tester.enterText(textFields.at(1), '9876543210');
    await tester.enterText(textFields.at(2), '123');
    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must be at least 6 characters long'),
      findsOneWidget,
    );
  });

  testWidgets('shows error snackbar when registration fails with conflict',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({'detail': 'A user with this mobile number already exists'}),
        409,
      );
    });
    final api = CustomerApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      MaterialApp(
        home: CreateAccountScreen(customerApi: api),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Aditi Verma');
    await tester.enterText(textFields.at(1), '9876543210');
    await tester.enterText(textFields.at(2), 'Password123');

    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();

    expect(
      find.text('A user with this mobile number already exists'),
      findsOneWidget,
    );
  });

  testWidgets('registers successfully, saves session, and navigates to CustomerHomeScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionManager =
        CustomerSessionManager(tokenStorage: InMemoryCustomerTokenStorage());
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'access_token': 'new-jwt-token-xyz',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 202,
            'name': 'Aditi Verma',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'customer_profile': {
              'state': 'Maharashtra',
              'city': 'Pune',
              'segment': '2-Wheeler',
            },
          },
        }),
        201,
      );
    });
    final api = CustomerApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      MaterialApp(
        home: CreateAccountScreen(
          customerApi: api,
          sessionManager: sessionManager,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Aditi Verma');
    await tester.enterText(textFields.at(1), '9876543210');
    await tester.enterText(textFields.at(2), 'Password123');

    await tester.tap(find.widgetWithText(InkWell, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(sessionManager.isAuthenticated, isTrue);
    expect(sessionManager.currentUser?.name, 'Aditi Verma');
    expect(find.text('Welcome, Aditi Verma'), findsOneWidget);
  });
}
