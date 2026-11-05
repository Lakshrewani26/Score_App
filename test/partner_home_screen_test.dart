import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/balance/partner_balance_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_three_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/home/services/partner_new_arrivals_service.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/partner/orders/partner_my_orders_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_history_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_points_screen.dart';

void main() {
  group('PartnerHomeScreen Redesign UI Tests', () {
    testWidgets(
        '1. Displays redesigned PartnerHomeScreen with header, New Arrivals, and 6 action buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Partner Header elements
      expect(find.text('Welcome, Partner'), findsOneWidget);
      expect(find.text('Thanks for being our valuable partner!'), findsOneWidget);

      // 2. New Arrivals section
      expect(find.text('New Arrivals'), findsOneWidget);
      expect(find.text('Newly Added'), findsOneWidget);
      expect(find.text('Sample Starter Motor Pro'), findsOneWidget);
      expect(find.text('Sample Disc Brake Assembly'), findsOneWidget);

      // 3. Six Action Buttons in 2-column layout
      expect(find.text('2 Wheeler'), findsOneWidget);
      expect(find.text('3 Wheeler'), findsOneWidget);
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('Transfer Points'), findsOneWidget);
      expect(find.text('Points History'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);

      // 4. Bottom Navigation Bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // 5. Notification bell and badge must be ABSENT from Partner Home
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications), findsNothing);

      // 6. Old quick action card labels and direct summary on home must be ABSENT
      expect(find.text('Product\nCatalogue'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '2. Displays authenticated partner name in header when session is active',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      await session.saveSession(
        token: 'token-partner-test',
        user: const PartnerUser(
          id: 99,
          name: 'Rajesh Motors',
          mobile: '9876543210',
          role: 'partner',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(sessionManager: session),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Rajesh Motors'), findsOneWidget);
      expect(find.text('Welcome, Partner'), findsNothing);
    });

    testWidgets(
        '3. New Arrivals displays empty state when no products are available',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(
            newArrivalsDataSource: PlaceholderPartnerNewArrivalsDataSource(
              customProducts: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Arrivals'), findsOneWidget);
      expect(
        find.text('No new arrivals available at this time.'),
        findsOneWidget,
      );
    });

    testWidgets(
        '4. New Arrivals displays loading indicator while fetching items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(
            newArrivalsDataSource: PlaceholderPartnerNewArrivalsDataSource(
              delay: Duration(seconds: 1),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Sample Starter Motor Pro'), findsOneWidget);
    });

    testWidgets(
        '5. Tapping a New Arrival card opens the Product Details modal sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final firstProduct = find.text('Sample Starter Motor Pro');
      expect(firstProduct, findsOneWidget);
      await tester.tap(firstProduct);
      await tester.pumpAndSettle();

      expect(find.text('Product Details'), findsOneWidget);
      expect(find.text('Code: SAMPLE-PARTNER-NA-01'), findsOneWidget);
      expect(find.text('Vehicle Type: 2-Wheeler'), findsOneWidget);
      expect(find.text('₹ 1,550.00 MRP'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Product Details'), findsNothing);
    });

    testWidgets('6. Tapping 2 Wheeler opens PartnerTwoWheelerCatalogueScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Wheeler'), findsOneWidget);
      await tester.ensureVisible(find.text('2 Wheeler'));
      await tester.tap(find.text('2 Wheeler'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTwoWheelerCatalogueScreen), findsOneWidget);
      expect(find.text('2-Wheeler'), findsOneWidget);
    });

    testWidgets('7. Tapping 3 Wheeler opens PartnerThreeWheelerCatalogueScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 Wheeler'), findsOneWidget);
      await tester.ensureVisible(find.text('3 Wheeler'));
      await tester.tap(find.text('3 Wheeler'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerThreeWheelerCatalogueScreen), findsOneWidget);
      expect(find.text('3-Wheeler'), findsOneWidget);
    });

    testWidgets('8. Tapping My Orders opens PartnerMyOrdersScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Orders'), findsOneWidget);
      await tester.ensureVisible(find.text('My Orders'));
      await tester.tap(find.text('My Orders'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerMyOrdersScreen), findsOneWidget);
    });

    testWidgets(
        '9. Tapping Transfer Points opens PartnerTransferPointsScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transfer Points'), findsOneWidget);
      await tester.ensureVisible(find.text('Transfer Points'));
      await tester.tap(find.text('Transfer Points'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);
      expect(find.text('Transfer points to staff securely'), findsOneWidget);
    });

    testWidgets(
        '10. Tapping Points History opens PartnerTransferHistoryScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Points History'), findsOneWidget);
      await tester.ensureVisible(find.text('Points History'));
      await tester.tap(find.text('Points History'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);
      expect(
        find.text('View your recent transfer transactions'),
        findsOneWidget,
      );
    });

    testWidgets('11. Tapping Balance opens PartnerBalanceScreen with values',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Balance'), findsOneWidget);
      await tester.ensureVisible(find.text('Balance'));
      await tester.tap(find.text('Balance'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerBalanceScreen), findsOneWidget);
      expect(find.text('Balance'), findsWidgets);
      expect(find.text('Points Earned'), findsWidgets);
      expect(find.text('Points Spent'), findsWidgets);
      expect(find.text('Remaining Balance'), findsWidgets);
    });

    testWidgets(
        '12. PartnerBalanceScreen displays configured balance values correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerBalanceScreen(
            pointsEarned: '12000',
            pointsSpent: '4500',
            remainingBalance: '7500',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12000'), findsWidgets);
      expect(find.text('4500'), findsWidgets);
      expect(find.text('7500'), findsWidgets);
      expect(find.text('Points Earned'), findsWidgets);
      expect(find.text('Points Spent'), findsWidgets);
      expect(find.text('Remaining Balance'), findsWidgets);
      expect(find.text('Points Earned / Total Points'), findsOneWidget);
      expect(find.text('Points Spent / Points Used'), findsOneWidget);
    });

    testWidgets(
        '13. Bottom navigation Profile button navigates to PartnerProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerProfileScreen), findsOneWidget);
    });

    testWidgets('14. Partner login rejects empty credentials',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerLoginScreen), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsNothing);
      expect(
        find.text('Please enter both Mobile Number and Password'),
        findsOneWidget,
      );
    });
  });
}
