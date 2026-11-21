import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'navigates from Welcome screen to Unified Login screen and then to Create Account screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ScoreApp());
    await tester.pumpAndSettle();

    // 1. Welcome Screen -> Tap Login
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // 2. Unified Login Screen appears
    expect(find.text('Phone Number'), findsWidgets);
    expect(find.text('Password'), findsWidgets);

    // 3. Unified Login Screen -> Tap "Create Account"
    final createAccountLink = find.byWidgetPredicate(
      (widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains('Create Account'),
    );
    await tester.tap(createAccountLink);
    await tester.pumpAndSettle();

    // 4. Create Account Screen appears
    expect(find.text('Create Account'), findsNWidgets(2));
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Segment'), findsOneWidget);

    // 5. Verify Back Navigation: Create Account -> Unified Login -> Welcome
    final dynamic widgetsState = tester.state(find.byType(Navigator));
    final NavigatorState navigator = widgetsState as NavigatorState;

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Phone Number'), findsWidgets);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Welcome!'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
