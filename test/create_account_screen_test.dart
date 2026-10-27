import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
