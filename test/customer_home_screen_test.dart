import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';

void main() {
  testWidgets('displays CustomerHomeScreen with all required UI elements', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Top Section
    expect(find.text('Welcome, Customer'), findsOneWidget);
    expect(find.text('Thank you for being a valued customer!'), findsOneWidget);

    // 2. Points Summary Card
    expect(find.text('Points Earned'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('Points Spent'), findsOneWidget);
    expect(find.text('Point Rebate Status'), findsOneWidget);

    // 3. Rebate Status Banner
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains(
                  'Rewards details are not available yet.',
                ),
      ),
      findsOneWidget,
    );

    // 4. Quick Action Cards
    expect(find.text("Scan Partner's QR Code"), findsOneWidget);
    expect(find.text('Enter Code Manually'), findsNothing);
    expect(find.text('Product Catalogue'), findsOneWidget);

    // 5. Bottom Action Cards
    expect(find.text('Transfer History'), findsOneWidget);
    expect(find.text('Transfer Points'), findsOneWidget);

    // 6. Bottom Navigation Bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // 7. Verify no layout exceptions
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer login does not create a fake authenticated session', (WidgetTester tester) async {
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

    expect(find.text('Customer Login'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsNothing);
    expect(
      find.text('Customer login is not connected to the backend yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
