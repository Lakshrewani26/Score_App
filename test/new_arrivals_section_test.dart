import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/catalogue_models.dart';
import 'package:score_app/core/services/new_arrivals_service.dart';
import 'package:score_app/core/widgets/new_arrivals_section.dart';

class MockNewArrivalsDataSource implements NewArrivalsDataSource {
  MockNewArrivalsDataSource({
    this.products = const [],
    this.shouldThrow = false,
    this.completer,
  });

  List<CatalogueProduct> products;
  bool shouldThrow;
  Completer<List<CatalogueProduct>>? completer;
  int callCount = 0;

  @override
  Future<List<CatalogueProduct>> getNewArrivals({int limit = 5}) async {
    callCount++;
    if (completer != null) {
      return completer!.future;
    }
    if (shouldThrow) {
      throw Exception('Network connection failed');
    }
    return products;
  }
}

List<CatalogueProduct> generateTestProducts(int count) {
  return List.generate(
    count,
    (index) => CatalogueProduct(
      id: index + 1,
      categoryId: 1,
      categoryName: 'Category ${index + 1}',
      productCode: 'PROD-00${index + 1}',
      name: 'Product Item ${index + 1}',
      description: 'Test description ${index + 1}',
      vehicleType: index.isEven ? '2-Wheeler' : '3-Wheeler',
      price: 100.0 * (index + 1),
      listPrice: 80.0 * (index + 1),
      imageUrl: index == 0 ? null : 'https://example.com/p${index + 1}.png',
    ),
  );
}

void main() {
  group('NewArrivalsSection Shared Widget Tests', () {
    testWidgets('1. Displays loading indicator while fetching items',
        (WidgetTester tester) async {
      final completer = Completer<List<CatalogueProduct>>();
      final mockSource = MockNewArrivalsDataSource(completer: completer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );

      // Loading state is visible before future completes
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('New Arrivals'), findsOneWidget);
      expect(find.text('Newly Added'), findsOneWidget);

      // Complete the future
      completer.complete(generateTestProducts(2));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Product Item 1'), findsOneWidget);
      expect(find.text('Product Item 2'), findsOneWidget);
    });

    testWidgets('2. Displays products correctly with proper details',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 10,
          categoryId: 1,
          categoryName: 'Electrical',
          productCode: 'SPARK-01',
          name: 'Spark Plug High Performance',
          vehicleType: '2-Wheeler',
          price: 250.00,
          listPrice: 200.00,
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spark Plug High Performance'), findsOneWidget);
      expect(find.text('₹ 250.00'), findsOneWidget);
      expect(mockSource.callCount, 1);
    });

    testWidgets('3. Enforces maximum of 5 products when source returns more',
        (WidgetTester tester) async {
      final sevenProducts = generateTestProducts(7);
      final mockSource = MockNewArrivalsDataSource(products: sevenProducts);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Products 1 to 5 should be present
      expect(find.text('Product Item 1'), findsOneWidget);
      expect(find.text('Product Item 2'), findsOneWidget);
      expect(find.text('Product Item 3'), findsOneWidget);
      expect(find.text('Product Item 4'), findsOneWidget);
      expect(find.text('Product Item 5'), findsOneWidget);

      // Products 6 and 7 should NOT be present (max 5 limit)
      expect(find.text('Product Item 6'), findsNothing);
      expect(find.text('Product Item 7'), findsNothing);
    });

    testWidgets('4. Displays proper empty state when no products exist',
        (WidgetTester tester) async {
      final mockSource = MockNewArrivalsDataSource(products: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No new arrivals available at this time.'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    testWidgets('5. Displays error state with Retry button on failure and recovers on retry',
        (WidgetTester tester) async {
      final mockSource = MockNewArrivalsDataSource(shouldThrow: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load new arrivals'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      // Fix source and tap Retry
      mockSource.shouldThrow = false;
      mockSource.products = generateTestProducts(2);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load new arrivals'), findsNothing);
      expect(find.text('Product Item 1'), findsOneWidget);
      expect(find.text('Product Item 2'), findsOneWidget);
      expect(mockSource.callCount, 2);
    });

    testWidgets('6. Displays fallback icon when product image is missing or null',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Electrical',
          productCode: 'BAT-01',
          name: 'Battery Sealed 12V',
          vehicleType: '2-Wheeler',
          price: 1800.00,
          imageUrl: null, // missing/null image
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Battery Sealed 12V'), findsOneWidget);
      // Fallback icon inside circle
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    testWidgets('7. Shared widget renders customer role with MRP only',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Engine',
          productCode: 'ENG-01',
          name: 'Engine Oil Filter',
          vehicleType: '2-Wheeler',
          price: 320.00,
          listPrice: 240.00,
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Customer only sees MRP
      expect(find.text('₹ 320.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 320.00'), findsNothing);
      expect(find.text('₹ 240.00'), findsNothing);
    });

    testWidgets('8. Shared widget renders partner role with List Price and MRP',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Engine',
          productCode: 'ENG-01',
          name: 'Engine Oil Filter',
          vehicleType: '2-Wheeler',
          price: 320.00,
          listPrice: 240.00,
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.partner,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Partner sees List Price in green badge and MRP
      expect(find.text('₹ 240.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 320.00'), findsOneWidget);
    });

    testWidgets('8b. Shared widget renders partner role with MRP fallback when listPrice is null',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Engine',
          productCode: 'ENG-01',
          name: 'Engine Oil Filter',
          vehicleType: '2-Wheeler',
          price: 320.00,
          listPrice: null,
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.partner,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹ 320.00'), findsOneWidget);
    });

    testWidgets('9. Shared widget renders staff role with List Price and MRP',
        (WidgetTester tester) async {
      final products = [
        const CatalogueProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Engine',
          productCode: 'ENG-01',
          name: 'Engine Oil Filter',
          vehicleType: '2-Wheeler',
          price: 320.00,
          listPrice: 240.00,
        ),
      ];
      final mockSource = MockNewArrivalsDataSource(products: products);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.staff,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Staff sees List Price in green badge and MRP
      expect(find.text('₹ 240.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 320.00'), findsOneWidget);
    });

    testWidgets('10. Calls onProductTap when a product card is tapped',
        (WidgetTester tester) async {
      final products = generateTestProducts(1);
      final mockSource = MockNewArrivalsDataSource(products: products);
      CatalogueProduct? tappedProduct;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
              onProductTap: (product) {
                tappedProduct = product;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Product Item 1'));
      await tester.pumpAndSettle();

      expect(tappedProduct, isNotNull);
      expect(tappedProduct!.name, 'Product Item 1');
      expect(tappedProduct!.id, 1);
    });

    testWidgets('11. GlobalKey reload() triggers a fresh fetch',
        (WidgetTester tester) async {
      final key = GlobalKey<NewArrivalsSectionState>();
      final mockSource = MockNewArrivalsDataSource(products: generateTestProducts(2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NewArrivalsSection(
              key: key,
              role: NewArrivalsRole.customer,
              dataSource: mockSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mockSource.callCount, 1);

      // Trigger reload
      await key.currentState?.reload();
      await tester.pumpAndSettle();

      expect(mockSource.callCount, 2);
    });
  });
}
