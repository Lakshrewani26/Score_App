import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/partner/catalogue/partner_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_three_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';

void main() {
  group('PartnerProductCatalogueScreen Tests', () {
    testWidgets('renders PartnerProductCatalogueScreen with all required UI elements', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. "Product Catalogue" title exists
      expect(find.text('Product Catalogue'), findsOneWidget);

      // 2. Subtitle exists
      expect(find.text('Explore our wide range of quality parts'), findsOneWidget);

      // 3. "2-Wheeler Parts" exists
      expect(find.textContaining('2-Wheeler'), findsOneWidget);

      // 4. "3-Wheeler Parts" exists
      expect(find.textContaining('3-Wheeler'), findsOneWidget);

      // 5. Back button exists
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // 6. Home bottom navigation exists
      expect(find.text('Home'), findsOneWidget);

      // 7. Profile bottom navigation exists
      expect(find.text('Profile'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Tapping Back returns to PartnerHomeScreen', (WidgetTester tester) async {
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

      await tester.tap(find.textContaining('Catalogue').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.arrow_back_rounded));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
    });

    testWidgets('9. Tapping Home opens PartnerHomeScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
    });

    testWidgets('10. Tapping Profile opens PartnerProfileScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerProfileScreen), findsOneWidget);
    });

    testWidgets('11. Tapping 2-Wheeler Parts opens existing 2-Wheeler Parts screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('2-Wheeler'));
      await tester.tap(find.textContaining('2-Wheeler'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTwoWheelerCatalogueScreen), findsOneWidget);
    });

    testWidgets('12. Tapping 3-Wheeler Parts opens PartnerThreeWheelerCatalogueScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('3-Wheeler'));
      await tester.tap(find.textContaining('3-Wheeler'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerThreeWheelerCatalogueScreen), findsOneWidget);
    });

    testWidgets('13. Partner Home Product Catalogue card opens PartnerProductCatalogueScreen', (WidgetTester tester) async {
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

      await tester.ensureVisible(find.textContaining('Catalogue').first);
      await tester.tap(find.textContaining('Catalogue').first);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerProductCatalogueScreen), findsOneWidget);
      expect(find.text('Product Catalogue'), findsOneWidget);
    });
  });
}
