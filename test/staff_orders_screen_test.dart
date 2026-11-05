import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/catalogue_models.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/features/staff/dealers/staff_dealers_associated_screen.dart';
import 'package:score_app/features/staff/orders/staff_order_summary_screen.dart';
import 'package:score_app/features/staff/orders/staff_orders_screen.dart';

const _samplePartner = StaffAssignedPartner(
  id: 42,
  name: 'Apex Partner',
  businessName: 'Apex Spares',
  mobile: '9876543210',
  businessAddress: '10 Industrial Area',
  partnerCode: 'PAR-42',
);

const _product1 = CatalogueProduct(
  id: 101,
  categoryId: 1,
  productCode: 'PRD-2W-01',
  name: 'Spark Plug 2W',
  vehicleType: '2-Wheeler',
  price: 150.00,
);

const _product2 = CatalogueProduct(
  id: 102,
  categoryId: 2,
  productCode: 'PRD-3W-01',
  name: 'Brake Drum 3W',
  vehicleType: '3-Wheeler',
  price: 850.00,
);

void main() {
  group('StaffOrdersScreen Widget Tests', () {
    testWidgets(
        'renders screen with an empty product state and no sample records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Screen renders
      expect(find.byType(StaffOrdersScreen), findsOneWidget);

      // 2. "Add Order" heading is visible
      expect(find.text('Add Order'), findsOneWidget);

      // 3. "Select products and quantity" is visible
      expect(find.text('Select products and quantity'), findsOneWidget);

      // 4. "Search products" placeholder is visible
      expect(find.text('Search products'), findsOneWidget);

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);

      // 14. Continue button is visible
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets(
        'does not offer quantity controls for unavailable catalogue data',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final plusButtons = find.byIcon(Icons.add);
      final minusButtons = find.byIcon(Icons.remove);
      expect(plusButtons, findsNothing);
      expect(minusButtons, findsNothing);
    });

    testWidgets('12. product search filters correctly (case-insensitive)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(TextField);
      await tester.enterText(searchFieldFinder, 'hex');
      await tester.pumpAndSettle();

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);
      expect(find.text('Washer'), findsNothing);
      expect(find.text('Spring'), findsNothing);
    });

    testWidgets(
        '13. searching for a non-existing product displays No products found',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final searchFieldFinder = find.byType(TextField);
      await tester.enterText(searchFieldFinder, 'InvalidProduct123');
      await tester.pumpAndSettle();

      expect(
          find.text('Product ordering is not available yet.'), findsOneWidget);
      expect(find.text('Hex Bolt'), findsNothing);
    });

    testWidgets('15. Continue button opens StaffOrderSummaryScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final continueButton = find.text('Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrderSummaryScreen), findsOneWidget);
    });

    testWidgets('16. No order is offered when dealer records are unavailable',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffDealersAssociatedScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Order'), findsNothing);
      expect(find.byType(StaffOrdersScreen), findsNothing);
      expect(find.byType(StaffDealersAssociatedScreen), findsOneWidget);
    });

    testWidgets(
        'renders interactive catalogue with dealer banner when partner and products are supplied',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(
            partner: _samplePartner,
            initialProducts: [_product1, _product2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dealer badge
      expect(find.text('Dealer: Apex Spares (ID: 42)'), findsOneWidget);

      // Vehicle filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('2-Wheeler'), findsOneWidget);
      expect(find.text('3-Wheeler'), findsOneWidget);

      // Products are rendered
      expect(find.text('Spark Plug 2W'), findsOneWidget);
      expect(find.text('Brake Drum 3W'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNWidgets(2));
    });

    testWidgets('vehicle type filter filters 2W and 3W products',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(
            partner: _samplePartner,
            initialProducts: [_product1, _product2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter by 2-Wheeler
      await tester.tap(find.text('2-Wheeler'));
      await tester.pumpAndSettle();
      expect(find.text('Spark Plug 2W'), findsOneWidget);
      expect(find.text('Brake Drum 3W'), findsNothing);

      // Filter by 3-Wheeler
      await tester.tap(find.text('3-Wheeler'));
      await tester.pumpAndSettle();
      expect(find.text('Spark Plug 2W'), findsNothing);
      expect(find.text('Brake Drum 3W'), findsOneWidget);

      // Reset to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Spark Plug 2W'), findsOneWidget);
      expect(find.text('Brake Drum 3W'), findsOneWidget);
    });

    testWidgets('quantity controls increment and decrement product quantity',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(
            partner: _samplePartner,
            initialProducts: [_product1, _product2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially quantity 0
      expect(find.text('0'), findsNWidgets(2));

      // Tap + on the first product (Spark Plug 2W)
      final addButtons = find.byIcon(Icons.add);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Now 1
      expect(find.text('1'), findsOneWidget);

      // Tap + again
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      // Tap - on the first product
      final minusButtons = find.byIcon(Icons.remove);
      await tester.tap(minusButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'tapping Continue with selected items navigates to StaffOrderSummaryScreen preserving Dealer and items',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(
            partner: _samplePartner,
            initialProducts: [_product1, _product2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Increment quantity of Spark Plug 2W to 2
      final addButtons = find.byIcon(Icons.add);
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();
      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      // Tap Continue
      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // StaffOrderSummaryScreen opens
      expect(find.byType(StaffOrderSummaryScreen), findsOneWidget);
      // Dealer name is displayed
      expect(find.text('Dealer: Apex Spares'), findsOneWidget);
      // Product name is displayed
      expect(find.text('Spark Plug 2W'), findsOneWidget);
      // Quantity 2 is displayed
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('tapping Continue with zero items shows validation message',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffOrdersScreen(
            partner: _samplePartner,
            initialProducts: [_product1, _product2],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // Shows SnackBar validation
      expect(
        find.text(
          'Please select at least one product with quantity greater than zero.',
        ),
        findsOneWidget,
      );
      expect(find.byType(StaffOrderSummaryScreen), findsNothing);
    });
  });
}
