import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/login/partner_login_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_catalogue_screen.dart';
import 'package:score_app/features/partner/orders/partner_my_orders_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_points_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_history_screen.dart';

void main() {
  group('PartnerHomeScreen Tests', () {
    testWidgets('renders PartnerHomeScreen with available live session data only', (WidgetTester tester) async {
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

      // 1. Partner Home renders
      expect(find.byType(PartnerHomeScreen), findsOneWidget);

      // 2. Unauthenticated preview does not invent an identity.
      expect(find.text('Welcome, Partner'), findsOneWidget);

      // 3. "Thanks for being our valuable partner!" is visible
      expect(find.text('Thanks for being our valuable partner!'), findsOneWidget);

      // 4. "Total Points" is visible
      expect(find.text('Total Points'), findsOneWidget);

      // Points are not supplied by the backend yet.
      expect(find.text('—'), findsNWidgets(3));

      // 6. "Points Used" is visible
      expect(find.text('Points Used'), findsOneWidget);


      // 8. "Remaining Balance" is visible
      expect(find.text('Remaining Balance'), findsOneWidget);


      // 10. "Product Catalogue" is visible
      expect(find.textContaining('Product'), findsWidgets);
      expect(find.textContaining('Catalogue'), findsWidgets);

      // 11. "My Orders" is visible
      expect(find.text('My Orders'), findsOneWidget);

      // 12. "Transfer Points" is visible
      expect(find.text('Transfer Points'), findsOneWidget);

      // 13. "Transfer History" is visible
      expect(find.text('Transfer History'), findsOneWidget);

      // 14. Home navigation is visible
      expect(find.text('Home'), findsOneWidget);

      // 15. Profile navigation is visible
      expect(find.text('Profile'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping quick action cards displays correct placeholder SnackBars', (WidgetTester tester) async {
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

      // Test Product Catalogue card tap
      await tester.ensureVisible(find.textContaining('Catalogue').first);
      await tester.tap(find.textContaining('Catalogue').first);
      await tester.pumpAndSettle();
      expect(find.byType(PartnerProductCatalogueScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test My Orders card tap
      await tester.ensureVisible(find.text('My Orders'));
      await tester.tap(find.text('My Orders'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerMyOrdersScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Transfer Points card tap
      await tester.ensureVisible(find.text('Transfer Points'));
      await tester.tap(find.text('Transfer Points'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Transfer History card tap
      await tester.ensureVisible(find.text('Transfer History'));
      await tester.tap(find.text('Transfer History'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Test Profile bottom tab tap
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerProfileScreen), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('partner login rejects empty credentials', (WidgetTester tester) async {
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

      expect(tester.takeException(), isNull);
    });
  });
}
