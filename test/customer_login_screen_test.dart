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
  testWidgets(
      'displays the Customer Login screen with all required UI elements and navigates to CreateAccountScreen',
      (WidgetTester tester) async {
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

    // Verify Title & Logo
    expect(find.text('Customer Login'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Verify Fields
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify Submit button
    expect(find.text('Submit'), findsOneWidget);

    // Verify Footer text
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('New user?') &&
            widget.text.toPlainText().contains('Create an account'),
      ),
      findsOneWidget,
    );

    // Verify no layout exception occurred
    expect(tester.takeException(), isNull);

    // Tap "Create an account" link to verify navigation
    final createAccountLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Create an account'),
    );

    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    // Verify we navigated to CreateAccountScreen
    expect(find.byType(CreateAccountScreen), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
  });

  testWidgets('shows validation snackbar when submitting empty fields',
      (WidgetTester tester) async {
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

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Number and password are required'), findsNothing);
    expect(find.text('Mobile number and password are required'), findsOneWidget);
  });

  testWidgets('shows error snackbar when API rejects credentials',
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
    final api = CustomerApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerLoginScreen(customerApi: api),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '9876543210');
    await tester.enterText(textFields.at(1), 'wrongpass');

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid mobile number or password'), findsOneWidget);
  });

  testWidgets('logs in successfully and navigates to CustomerHomeScreen',
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
          'access_token': 'jwt-test-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 101,
            'name': 'Pooja Patel',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'customer_profile': {
              'state': 'Gujarat',
              'city': 'Ahmedabad',
              'segment': '2-Wheeler',
            },
          },
        }),
        200,
      );
    });
    final api = CustomerApi(client: mockClient, baseUrl: 'http://localhost');

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerLoginScreen(
          customerApi: api,
          sessionManager: sessionManager,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '9876543210');
    await tester.enterText(textFields.at(1), 'CorrectPass123');

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(sessionManager.isAuthenticated, isTrue);
    expect(sessionManager.currentUser?.name, 'Pooja Patel');
    expect(find.text('Welcome, Pooja Patel'), findsOneWidget);
  });
}
