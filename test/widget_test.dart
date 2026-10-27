import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:score_app/app/app.dart';

void main() {
  testWidgets('displays the Welcome screen on an Android phone viewport',
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
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'navigates from Welcome screen to Customer Login screen and then to Create Account screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ScoreApp());
    await tester.pumpAndSettle();

    // 1. Welcome Screen -> Tap Customer Login
    await tester.tap(find.text('Customer Login'));
    await tester.pumpAndSettle();

    // 2. Customer Login Screen appears
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);

    // 3. Customer Login Screen -> Tap "Create an account"
    final createAccountLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Create an account'),
    );
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    // 4. Create Account Screen appears
    expect(find.text('Create Account'), findsNWidgets(2));
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Segment'), findsOneWidget);

    // 5. Verify Back Navigation: Create Account -> Customer Login -> Welcome
    final dynamic widgetsState = tester.state(find.byType(Navigator));
    final NavigatorState navigator = widgetsState as NavigatorState;

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Mobile Number'), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
