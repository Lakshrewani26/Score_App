import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/catalogue_api.dart';
import 'package:score_app/features/customer/catalogue/catalogue_category_list_screen.dart';
import 'package:score_app/features/customer/catalogue/customer_catalogue_screen.dart';
import 'package:score_app/features/customer/catalogue/three_wheeler_parts_screen.dart';
import 'package:score_app/features/customer/catalogue/two_wheeler_parts_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_three_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/staff/catalogue/staff_three_wheeler_catalogue_screen.dart';
import 'package:score_app/features/staff/catalogue/staff_two_wheeler_catalogue_screen.dart';
import 'catalogue_test_support.dart';

void main() {
  final twoWheelerCategories = [
    {'id': 1, 'name': 'Brake Parts', 'description': 'Brake components'},
    {'id': 2, 'name': 'Clutch Parts', 'description': 'Clutch components'},
  ];

  final threeWheelerCategories = [
    {'id': 10, 'name': 'Steering System', 'description': '3W steering'},
    {'id': 11, 'name': 'Transmission', 'description': '3W transmission'},
  ];

  final brakeProducts = [
    {
      'id': 101,
      'category_id': 1,
      'category_name': 'Brake Parts',
      'product_code': 'BRK-001',
      'name': '2W Disc Brake Pad',
      'description': 'High performance brake pad',
      'vehicle_type': '2-Wheeler',
      'price': '450.00',
      'list_price': '380.00',
      'image_url': null,
    },
  ];

  final clutchProducts = [
    {
      'id': 102,
      'category_id': 2,
      'category_name': 'Clutch Parts',
      'product_code': 'CLT-001',
      'name': '2W Clutch Plate',
      'description': 'Durable clutch plate',
      'vehicle_type': '2-Wheeler',
      'price': '750.00',
      'list_price': '620.00',
      'image_url': null,
    },
  ];

  final threeWheelerProducts = [
    {
      'id': 201,
      'category_id': 10,
      'category_name': 'Steering System',
      'product_code': 'STR-301',
      'name': '3W Steering Column',
      'description': 'Heavy duty steering column',
      'vehicle_type': '3-Wheeler',
      'price': '1800.00',
      'list_price': '1500.00',
      'image_url': null,
    },
  ];

  CatalogueApi buildMockApi({
    bool includeListPrice = false,
    List<Map<String, dynamic>>? customCategories,
  }) {
    return CatalogueApi(
      client: MockClient((request) async {
        final uri = request.url;

        if (uri.path == '/api/v1/categories') {
          final vehicleType = uri.queryParameters['vehicle_type'];
          if (customCategories != null) {
            return http.Response(jsonEncode(customCategories), 200);
          }
          if (vehicleType == '2-Wheeler') {
            return http.Response(jsonEncode(twoWheelerCategories), 200);
          } else if (vehicleType == '3-Wheeler') {
            return http.Response(jsonEncode(threeWheelerCategories), 200);
          }
          return http.Response(jsonEncode(twoWheelerCategories), 200);
        }

        if (uri.path == '/api/v1/products') {
          final categoryId = uri.queryParameters['category_id'];
          final vehicleType = uri.queryParameters['vehicle_type'];

          List<Map<String, dynamic>> rawItems = [];
          if (categoryId == '1') {
            rawItems = brakeProducts;
          } else if (categoryId == '2') {
            rawItems = clutchProducts;
          } else if (categoryId == '10') {
            rawItems = threeWheelerProducts;
          } else if (vehicleType == '2-Wheeler') {
            rawItems = [...brakeProducts, ...clutchProducts];
          } else if (vehicleType == '3-Wheeler') {
            rawItems = threeWheelerProducts;
          }

          final items = rawItems.map((item) {
            final copy = Map<String, dynamic>.from(item);
            if (!includeListPrice) {
              copy.remove('list_price');
            }
            return copy;
          }).toList();

          return http.Response(
            jsonEncode({
              'items': items,
              'pagination': {
                'total': items.length,
                'page': 1,
                'page_size': 20,
                'total_pages': 1,
              },
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      }),
      baseUrl: 'http://localhost',
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Customer 2-Wheeler & 3-Wheeler Category Navigation', () {
    testWidgets('2W category listing displays categories with placeholders, selecting opens filtered products and back navigation works', (tester) async {
      configureViewport(tester);
      final api = buildMockApi();

      await tester.pumpWidget(
        MaterialApp(
          home: TwoWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Category Listing screen is shown
      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('2-Wheeler'), findsAtLeastNWidgets(1));
      expect(find.text('Genuine Parts for a Smoother Ride'), findsOneWidget);
      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsOneWidget);
      // Placeholders displayed
      expect(find.text('No Image'), findsNWidgets(2));
      expect(find.text('View parts'), findsNWidgets(2));

      // 2. Select "Brake Parts" category
      await tester.tap(find.text('Brake Parts'));
      await tester.pumpAndSettle();

      // 3. Verify Product List shows filtered products for Category 1
      expect(find.text('2W Disc Brake Pad'), findsOneWidget);
      expect(find.text('2W Clutch Plate'), findsNothing);
      expect(find.text('₹ 450.00'), findsOneWidget);
      // Customer view: MRP only, no List Price
      expect(find.text('MRP'), findsOneWidget);
      expect(find.text('List Price'), findsNothing);

      // 4. Verify back navigation returns to category listing
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsOneWidget);
    });

    testWidgets('3W category listing displays categories, selecting opens filtered products and back navigation works', (tester) async {
      configureViewport(tester);
      final api = buildMockApi();

      await tester.pumpWidget(
        MaterialApp(
          home: ThreeWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 3W Category Listing
      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('3-Wheeler'), findsAtLeastNWidgets(1));
      expect(find.text('Steering System'), findsOneWidget);
      expect(find.text('Transmission'), findsOneWidget);
      expect(find.text('No Image'), findsNWidgets(2));

      // 2. Select "Steering System"
      await tester.tap(find.text('Steering System'));
      await tester.pumpAndSettle();

      // 3. Verify Product List shows 3W products
      expect(find.text('3W Steering Column'), findsOneWidget);
      expect(find.text('₹ 1,800.00'), findsOneWidget);
      expect(find.text('MRP'), findsOneWidget);
      expect(find.text('List Price'), findsNothing);

      // 4. Back navigation
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Steering System'), findsOneWidget);
    });

    testWidgets('Both vehicle-type products appear when category is selected in 2-Wheeler catalogue', (tester) async {
      configureViewport(tester);
      final universalProduct = {
        'id': 105,
        'category_id': 1,
        'category_name': 'Brake Parts',
        'product_code': 'BRK-UNI',
        'name': 'Universal Brake Fluid',
        'description': 'Universal DOT4 fluid',
        'vehicle_type': 'Both',
        'price': '220.00',
        'image_url': null,
      };

      final api = CatalogueApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/categories') {
            return http.Response(jsonEncode(twoWheelerCategories), 200);
          }
          if (request.url.path == '/api/v1/products') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 101,
                    'category_id': 1,
                    'category_name': 'Brake Parts',
                    'product_code': 'BRK-001',
                    'name': '2W Disc Brake Pad',
                    'vehicle_type': '2-Wheeler',
                    'price': '450.00',
                  },
                  universalProduct,
                ],
                'pagination': {'total': 2, 'page': 1, 'page_size': 20, 'total_pages': 1},
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        }),
        baseUrl: 'http://localhost',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TwoWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Brake Parts'));
      await tester.pumpAndSettle();

      expect(find.text('2W Disc Brake Pad'), findsOneWidget);
      expect(find.text('Universal Brake Fluid'), findsOneWidget);
    });
  });

  group('Category Search, Empty State, and Deduplication', () {
    testWidgets('Category search filters list and shows empty state when no match, with clear button', (tester) async {
      configureViewport(tester);
      final api = buildMockApi();

      await tester.pumpWidget(
        MaterialApp(
          home: TwoWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both categories visible initially
      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsOneWidget);

      // Type "Brake"
      await tester.enterText(find.byType(TextField), 'Brake');
      await tester.pumpAndSettle();

      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsNothing);

      // Type non-matching query
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pumpAndSettle();

      expect(find.text('No categories match "NonExistent"'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);

      // Tap "Clear search"
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsOneWidget);
    });

    testWidgets('Gracefully handles empty category list from backend', (tester) async {
      configureViewport(tester);
      final api = buildMockApi(customCategories: []);

      await tester.pumpWidget(
        MaterialApp(
          home: TwoWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No categories found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Category names are not duplicated in listing', (tester) async {
      configureViewport(tester);
      final api = buildMockApi();

      await tester.pumpWidget(
        MaterialApp(
          home: TwoWheelerPartsScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly 1 instance of each category name widget in the category cards
      expect(find.text('Brake Parts'), findsOneWidget);
      expect(find.text('Clutch Parts'), findsOneWidget);
    });
  });

  group('Partner Catalogue Category Navigation & Pricing', () {
    testWidgets('Partner 2W navigates through category listing and shows MRP + List Price on products', (tester) async {
      configureViewport(tester);
      final api = buildMockApi(includeListPrice: true);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTwoWheelerCatalogueScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows Category Listing
      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Brake Parts'), findsOneWidget);

      // Tap category
      await tester.tap(find.text('Brake Parts'));
      await tester.pumpAndSettle();

      // Product List shows 2W Disc Brake Pad with partner pricing (both List Price and MRP)
      expect(find.text('2W Disc Brake Pad'), findsOneWidget);
      expect(find.text('₹ 380.00 List'), findsOneWidget); // List price
      expect(find.textContaining('MRP: ₹ 450.00'), findsOneWidget); // MRP

      // Back navigation
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
    });

    testWidgets('Partner 3W navigates through category listing and shows MRP + List Price on products', (tester) async {
      configureViewport(tester);
      final api = buildMockApi(includeListPrice: true);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerThreeWheelerCatalogueScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Steering System'), findsOneWidget);

      await tester.tap(find.text('Steering System'));
      await tester.pumpAndSettle();

      expect(find.text('3W Steering Column'), findsOneWidget);
      expect(find.text('₹ 1,500.00 List'), findsOneWidget); // List price
      expect(find.textContaining('MRP: ₹ 1,800.00'), findsOneWidget); // MRP
    });
  });

  group('Staff Catalogue Category Navigation & Pricing', () {
    testWidgets('Staff 2W navigates through category listing and shows MRP + List Price', (tester) async {
      configureViewport(tester);
      final api = buildMockApi(includeListPrice: true);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffTwoWheelerCatalogueScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Brake Parts'), findsOneWidget);

      await tester.tap(find.text('Brake Parts'));
      await tester.pumpAndSettle();

      expect(find.text('2W Disc Brake Pad'), findsOneWidget);
      expect(find.text('₹ 380.00 List'), findsOneWidget);
      expect(find.textContaining('MRP: ₹ 450.00'), findsOneWidget);
    });

    testWidgets('Staff 3W navigates through category listing and shows MRP + List Price', (tester) async {
      configureViewport(tester);
      final api = buildMockApi(includeListPrice: true);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffThreeWheelerCatalogueScreen(
            api: api,
            showCategoryList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueCategoryListScreen), findsOneWidget);
      expect(find.text('Steering System'), findsOneWidget);

      await tester.tap(find.text('Steering System'));
      await tester.pumpAndSettle();

      expect(find.text('3W Steering Column'), findsOneWidget);
      expect(find.text('₹ 1,500.00 List'), findsOneWidget);
      expect(find.textContaining('MRP: ₹ 1,800.00'), findsOneWidget);
    });
  });

  group('Home / Catalogue Screen Entry Point Integration', () {
    testWidgetsWithCatalogueResponses('CustomerCatalogueScreen 2-Wheeler tile navigates to Category List screen', (tester) async {
      configureViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 2-Wheeler Parts card
      await tester.tap(find.text('2-Wheeler\nParts'));
      await tester.pumpAndSettle();

      // TwoWheelerPartsScreen opened with showCategoryList: true
      final partsScreen = tester.widget<TwoWheelerPartsScreen>(
        find.byType(TwoWheelerPartsScreen),
      );
      expect(partsScreen.showCategoryList, isTrue);
    });

    testWidgetsWithCatalogueResponses('PartnerProductCatalogueScreen 2-Wheeler tile navigates to Partner Category List screen', (tester) async {
      configureViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: PartnerProductCatalogueScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2-Wheeler\nParts'));
      await tester.pumpAndSettle();

      final partsScreen = tester.widget<PartnerTwoWheelerCatalogueScreen>(
        find.byType(PartnerTwoWheelerCatalogueScreen),
      );
      expect(partsScreen.showCategoryList, isTrue);
    });
  });
}
