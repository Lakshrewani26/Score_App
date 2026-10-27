import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/customer/catalogue/customer_catalogue_screen.dart';
import 'package:score_app/features/customer/catalogue/two_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/catalogue/three_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/profile/customer_profile_screen.dart';

void main() {
  testWidgets('displays CustomerCatalogueScreen with all required UI elements', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerCatalogueScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header elements
    expect(find.text('Product Catalogue'), findsOneWidget);
    expect(find.text('Explore our wide range of quality parts'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // 2. Catalogue Cards
    expect(find.text('2-Wheeler\nParts'), findsOneWidget);
    expect(find.text('3-Wheeler\nParts'), findsOneWidget);

    // 3. Bottom Navigation Bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // 4. Verify no layout exceptions
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigates from CustomerHomeScreen to CustomerCatalogueScreen when Product Catalogue is tapped', (WidgetTester tester) async {
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

    expect(find.text('Product Catalogue'), findsOneWidget);
    await tester.ensureVisible(find.text('Product Catalogue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product Catalogue'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerCatalogueScreen), findsOneWidget);
    expect(find.text('Explore our wide range of quality parts'), findsOneWidget);
    expect(find.text('2-Wheeler\nParts'), findsOneWidget);
    expect(find.text('3-Wheeler\nParts'), findsOneWidget);
  });

  testWidgets('navigates from CustomerCatalogueScreen to CustomerHomeScreen via top back button', (WidgetTester tester) async {
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

    await tester.ensureVisible(find.text('Product Catalogue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product Catalogue'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerCatalogueScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('navigates from CustomerCatalogueScreen to CustomerHomeScreen via bottom nav Home button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerCatalogueScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
  });

  testWidgets('navigates from CustomerCatalogueScreen to CustomerProfileScreen via bottom nav Profile button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerCatalogueScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerProfileScreen), findsOneWidget);
  });

  testWidgets('tapping 2-Wheeler and 3-Wheeler cards navigates to respective parts screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerCatalogueScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('2-Wheeler\nParts'));
    await tester.pumpAndSettle();
    expect(find.byType(TwoWheelerPartsScreen), findsOneWidget);

    // Pop back to catalogue screen
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerCatalogueScreen), findsOneWidget);

    await tester.tap(find.text('3-Wheeler\nParts'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreeWheelerPartsScreen), findsOneWidget);
  });
}
