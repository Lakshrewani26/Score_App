import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/customer/create_account/create_account_screen.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';

void main() {
  testWidgets('displays the Customer Login screen with all required UI elements and navigates to CreateAccountScreen', (WidgetTester tester) async {
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
}
