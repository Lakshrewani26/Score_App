import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/profile/customer_profile_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  testWidgets('displays CustomerProfileScreen with all required UI elements and no points summary', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Top Header
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Your account details'), findsOneWidget);

    // 2. Profile Name Card
    expect(find.text('Customer'), findsOneWidget);

    // 3. Account Details Card
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(5));
    expect(find.text('Segment'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);

    // 4. Points Summary Card is removed (available on dedicated Customer Balance screen)
    expect(find.text('Total Points\nAwarded'), findsNothing);
    expect(find.text('Total Points\nSpent'), findsNothing);
    expect(find.text('Remaining\nBalance'), findsNothing);

    // 5. Logout Card
    expect(find.text('Logout'), findsOneWidget);

    // 6. Bottom Navigation Bar
    expect(find.text('Home'), findsOneWidget);

    // 7. Verify Change Password is NOT present
    expect(find.text('Change Password'), findsNothing);

    // 8. Verify no layout overflow
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders populated CustomerUser details without points summary card', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionManager = CustomerSessionManager(
      tokenStorage: InMemoryCustomerTokenStorage(),
    );
    await sessionManager.saveSession(
      token: 'test_token',
      user: const CustomerUser(
        id: 42,
        name: 'Jane Doe',
        mobile: '9876543210',
        role: 'customer',
        segment: '2W',
        state: 'Maharashtra',
        city: 'Mumbai',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerProfileScreen(sessionManager: sessionManager),
      ),
    );
    await tester.pumpAndSettle();

    // Verify customer details
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('2W'), findsOneWidget);
    expect(find.text('Maharashtra'), findsOneWidget);
    expect(find.text('Mumbai'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget); // Address only

    // Verify points summary does not exist
    expect(find.text('Total Points\nAwarded'), findsNothing);
    expect(find.text('Total Points\nSpent'), findsNothing);
    expect(find.text('Remaining\nBalance'), findsNothing);

    // Verify Logout and bottom navigation still exist
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders cleanly on smaller mobile screen without overflow and logout accessible', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Your account details'), findsOneWidget);
    expect(find.text('Total Points\nAwarded'), findsNothing);
    expect(find.text('Total Points\nSpent'), findsNothing);
    expect(find.text('Remaining\nBalance'), findsNothing);

    final logoutFinder = find.text('Logout');
    await tester.ensureVisible(logoutFinder);
    await tester.pumpAndSettle();
    expect(logoutFinder, findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates Customer Home -> Profile -> Customer Home', (WidgetTester tester) async {
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

    // Verify Home screen loaded
    expect(find.byType(CustomerHomeScreen), findsOneWidget);

    // Tap Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // Verify Profile screen opened
    expect(find.byType(CustomerProfileScreen), findsOneWidget);
    expect(find.text('Your account details'), findsOneWidget);

    // Tap Home tab
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Verify returned to CustomerHomeScreen
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates Customer Profile -> Logout -> WelcomeScreen clearing navigation stack', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomerProfileScreen), findsOneWidget);

    // Ensure Logout is visible and tap button
    final logoutFinder = find.text('Logout');
    await tester.ensureVisible(logoutFinder);
    await tester.pumpAndSettle();
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    // Verify WelcomeScreen is displayed
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(CustomerProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
