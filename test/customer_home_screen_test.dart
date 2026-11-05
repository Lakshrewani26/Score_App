import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/features/customer/balance/customer_balance_screen.dart';
import 'package:score_app/features/customer/catalogue/three_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/catalogue/two_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/home/services/new_arrivals_service.dart';
import 'package:score_app/features/customer/login/customer_login_screen.dart';
import 'package:score_app/features/customer/profile/customer_profile_screen.dart';
import 'package:score_app/features/customer/qr_scanner/customer_qr_scanner.dart';
import 'package:score_app/features/customer/transfer_history/customer_transfer_history_screen.dart';

void main() {
  group('CustomerHomeScreen Redesign UI Tests', () {
    testWidgets('1. Displays redesigned CustomerHomeScreen with header, New Arrivals, and 6 action buttons', (WidgetTester tester) async {
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

      // 1. Header elements
      expect(find.text('Welcome, Customer'), findsOneWidget);
      expect(find.text('Thank you for being a valued customer!'), findsOneWidget);

      // 2. New Arrivals section
      expect(find.text('New Arrivals'), findsOneWidget);
      expect(find.text('Newly Added'), findsOneWidget);
      expect(find.text('Sample Starter Motor'), findsOneWidget);
      expect(find.text('Sample Disc Brake Pad'), findsOneWidget);

      // 3. Six Action Buttons
      expect(find.text('2 Wheeler'), findsOneWidget);
      expect(find.text('3 Wheeler'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      expect(find.text('Points History'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Transfer Points'), findsOneWidget);

      // 4. Bottom Navigation Bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // 5. Old cards and notification bell should NOT be present on redesigned home screen
      expect(find.text('Point Rebate Status'), findsNothing);
      expect(find.text('Rewards details are not available yet.'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Displays authenticated customer name in header when session is active', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = CustomerSessionManager();
      await session.saveSession(
        token: 'token-xyz',
        user: const CustomerUser(
          id: 42,
          name: 'Harshita Sharma',
          mobile: '9876543210',
          role: 'customer',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerHomeScreen(sessionManager: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Harshita Sharma'), findsOneWidget);
      expect(find.text('Welcome, Customer'), findsNothing);
    });

    testWidgets('3. New Arrivals displays empty state when no products are available', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerHomeScreen(
            newArrivalsDataSource: PlaceholderNewArrivalsDataSource(
              customProducts: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Arrivals'), findsOneWidget);
      expect(find.text('No new arrivals available at this time.'), findsOneWidget);
    });

    testWidgets('4. New Arrivals displays loading indicator while fetching items', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerHomeScreen(
            newArrivalsDataSource: PlaceholderNewArrivalsDataSource(
              delay: Duration(seconds: 1),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sample Starter Motor'), findsOneWidget);
    });

    testWidgets('5. Tapping a New Arrival card opens the Product Details modal sheet', (WidgetTester tester) async {
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

      final firstProduct = find.text('Sample Starter Motor');
      expect(firstProduct, findsOneWidget);
      await tester.tap(firstProduct);
      await tester.pumpAndSettle();

      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('Code: SAMPLE-NA-01'), findsOneWidget);
      expect(find.text('Vehicle Type: 2-Wheeler'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Product Details'), findsNothing);
    });

    testWidgets('6. Tapping 2 Wheeler opens TwoWheelerPartsScreen', (WidgetTester tester) async {
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

      final btn = find.text('2 Wheeler');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(TwoWheelerPartsScreen), findsOneWidget);
      expect(find.text('Genuine Parts for a Smoother Ride'), findsOneWidget);
    });

    testWidgets('7. Tapping 3 Wheeler opens ThreeWheelerPartsScreen', (WidgetTester tester) async {
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

      final btn = find.text('3 Wheeler');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(ThreeWheelerPartsScreen), findsOneWidget);
      expect(find.text('Genuine Parts for a Smoother Ride'), findsOneWidget);
    });

    testWidgets('8. Tapping Scan QR opens CustomerQrScannerSheet in scan mode', (WidgetTester tester) async {
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

      final btn = find.text('Scan QR');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
      expect(find.text('Enter Code Manually'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerQrScannerSheet), findsNothing);
    });

    testWidgets('9. Tapping Points History opens CustomerTransferHistoryScreen', (WidgetTester tester) async {
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

      final btn = find.text('Points History');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerTransferHistoryScreen), findsOneWidget);
      expect(find.text('View your recent transfer transactions'), findsOneWidget);
    });

    testWidgets('10. Tapping Balance opens CustomerBalanceScreen with values', (WidgetTester tester) async {
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

      final btn = find.text('Balance');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBalanceScreen), findsOneWidget);
      expect(find.text('Points Earned'), findsAtLeastNWidgets(1));
      expect(find.text('Points Spent'), findsAtLeastNWidgets(1));
      expect(find.text('Remaining Balance'), findsAtLeastNWidgets(1));
      // By default without backend points models, displays honest placeholder '—'
      expect(find.text('—'), findsAtLeastNWidgets(3));
    });

    testWidgets('11. CustomerBalanceScreen displays configured balance values correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerBalanceScreen(
            pointsEarned: '1200',
            pointsSpent: '450',
            remainingBalance: '750',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1200'), findsAtLeastNWidgets(1));
      expect(find.text('450'), findsAtLeastNWidgets(1));
      expect(find.text('750'), findsAtLeastNWidgets(1));
      expect(find.text('Points Breakdown'), findsOneWidget);

      // Back navigation returns to previous screen / home
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('12. Tapping Transfer Points opens scanner in transferPoints mode', (WidgetTester tester) async {
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

      final btn = find.text('Transfer Points');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
      // In transferPoints mode, manual code entry is omitted
      expect(find.text('Enter Code Manually'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerQrScannerSheet), findsNothing);
    });

    testWidgets('13. Bottom navigation Profile button navigates to CustomerProfileScreen', (WidgetTester tester) async {
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

      final profileBtn = find.text('Profile');
      expect(profileBtn, findsOneWidget);
      await tester.tap(profileBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerProfileScreen), findsOneWidget);
      expect(find.text('Your account details'), findsOneWidget);
    });

    testWidgets('14. Customer login does not create a fake authenticated session', (WidgetTester tester) async {
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
        find.text('Mobile number and password are required'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
