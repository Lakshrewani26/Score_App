import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/models/catalogue_models.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/admin_catalogue_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/catalogue_api.dart';
import 'package:score_app/features/admin/catalogue/widgets/admin_product_card.dart';
import 'package:score_app/features/admin/catalogue/widgets/admin_product_detail_sheet.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/admin/catalogue/widgets/admin_product_form_dialog.dart';
import 'package:score_app/features/customer/catalogue/catalogue_product_list_screen.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/home/services/partner_new_arrivals_service.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';
import 'package:score_app/features/staff/home/services/staff_new_arrivals_service.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  final mockCategory = AdminCategory(
    id: 1,
    name: 'Brakes',
    description: null,
    isActive: true,
    productCount: 1,
  );

  group('MRP and List Price - Admin Form Widget Tests', () {
    testWidgets('Create form displays both MRP and List Price fields and validates required list price',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'token', user: mockAdminUser);
      final client = MockClient((req) async => http.Response('{}', 200));
      final api = AdminCatalogueApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProductFormDialog(
              catalogueApi: api,
              categories: [mockCategory],
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both fields exist
      expect(find.byKey(const Key('product_form_price_input')), findsOneWidget);
      expect(find.byKey(const Key('product_form_list_price_input')), findsOneWidget);
      expect(find.text('MRP (₹) (Optional)'), findsOneWidget);
      expect(find.text('List Price (₹) *'), findsOneWidget);

      // Enter code and name, but no list price
      await tester.enterText(find.byKey(const Key('product_form_code_input')), 'PRD-1');
      await tester.enterText(find.byKey(const Key('product_form_name_input')), 'Brake Disc');
      await tester.ensureVisible(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();

      // List Price required validation error
      expect(find.text('List Price is required for new products'), findsOneWidget);

      // Enter negative list price
      await tester.enterText(find.byKey(const Key('product_form_list_price_input')), '-50.00');
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cannot be negative'), findsOneWidget);

      // Enter more than 2 decimal places
      await tester.enterText(find.byKey(const Key('product_form_list_price_input')), '120.555');
      await tester.tap(find.byKey(const Key('product_form_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Max 2 decimal places'), findsOneWidget);
    });

    testWidgets('Edit form displays existing MRP and List Price, allows optional list price',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'token', user: mockAdminUser);
      final client = MockClient((req) async => http.Response('{}', 200));
      final api = AdminCatalogueApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      final existingProduct = AdminProduct(
        id: 10,
        productCode: 'PRD-10',
        name: 'Oil Filter',
        categoryId: 1,
        categoryName: 'Filters',
        categoryIsActive: true,
        vehicleType: '2-Wheeler',
        price: 500.0,
        listPrice: 420.0,
        description: null,
        imageUrl: null,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProductFormDialog(
              product: existingProduct,
              catalogueApi: api,
              categories: [mockCategory],
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mrpField = tester.widget<TextFormField>(find.byKey(const Key('product_form_price_input')));
      final listPriceField = tester.widget<TextFormField>(find.byKey(const Key('product_form_list_price_input')));

      expect(mrpField.controller?.text, '500.0');
      expect(listPriceField.controller?.text, '420.0');
      expect(find.text('List Price (₹) (Optional)'), findsOneWidget);
    });
  });

  group('MRP and List Price - Admin Product Card and Detail Sheet', () {
    testWidgets('AdminProductCard displays MRP and List Price when listPrice is present', (tester) async {
      final product = AdminProduct(
        id: 1,
        productCode: 'PRD-1',
        name: 'Clutch Assembly',
        categoryId: 1,
        categoryName: 'Transmission',
        categoryIsActive: true,
        vehicleType: '2-Wheeler',
        price: 1500.0,
        listPrice: 1200.0,
        description: null,
        imageUrl: null,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProductCard(product: product, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₹ 1,500.00'), findsOneWidget);
      expect(find.text('List: ₹ 1,200.00'), findsOneWidget);
    });

    testWidgets('AdminProductDetailSheet displays both MRP and List Price', (tester) async {
      final product = AdminProduct(
        id: 1,
        productCode: 'PRD-1',
        name: 'Clutch Assembly',
        categoryId: 1,
        categoryName: 'Transmission',
        categoryIsActive: true,
        vehicleType: '2-Wheeler',
        price: 1500.0,
        listPrice: 1200.0,
        description: null,
        imageUrl: null,
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProductDetailSheet(product: product),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MRP: '), findsOneWidget);
      expect(find.text('₹ 1,500.00'), findsOneWidget);
      expect(find.text('List Price: '), findsOneWidget);
      expect(find.text('₹ 1,200.00'), findsNWidgets(2)); // top summary and detail table
    });
  });

  group('MRP and List Price - Catalogue Product List Screen', () {
    testWidgets('displays List Price and MRP for products with list_price', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/categories') {
          return http.Response(jsonEncode([{'id': 1, 'name': 'Engine', 'description': null}]), 200);
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'category_id': 1,
                'category_name': 'Engine',
                'product_code': 'ENG-01',
                'name': 'Piston Kit',
                'description': 'Standard piston',
                'vehicle_type': '2-Wheeler',
                'price': 1500.0,
                'list_price': 1200.0,
                'image_url': null,
              }
            ],
            'pagination': {'total': 1, 'page': 1, 'page_size': 20, 'total_pages': 1}
          }),
          200,
        );
      });

      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogueProductListScreen(
              api: api,
              vehicleType: '2-Wheeler',
              title: '2-Wheeler Parts',
              heroCaption: 'Browse parts',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Piston Kit'), findsOneWidget);
      expect(find.text('₹ 1,200.00 List'), findsOneWidget); // List price
      expect(find.text('MRP: ₹ 1,500.00'), findsOneWidget);
    });

    testWidgets('displays MRP only when list_price is null (e.g. Customer view)', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/v1/categories') {
          return http.Response(jsonEncode([{'id': 1, 'name': 'Engine', 'description': null}]), 200);
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 2,
                'category_id': 1,
                'category_name': 'Engine',
                'product_code': 'ENG-02',
                'name': 'Spark Plug',
                'description': 'Spark plug',
                'vehicle_type': '2-Wheeler',
                'price': 250.0,
                'list_price': null,
                'image_url': null,
              }
            ],
            'pagination': {'total': 1, 'page': 1, 'page_size': 20, 'total_pages': 1}
          }),
          200,
        );
      });

      final api = CatalogueApi(client: client, baseUrl: 'http://localhost');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogueProductListScreen(
              api: api,
              vehicleType: '2-Wheeler',
              title: '2-Wheeler Parts',
              heroCaption: 'Browse parts',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spark Plug'), findsOneWidget);
      expect(find.text('₹ 250.00'), findsOneWidget);
      expect(find.text('MRP'), findsOneWidget);
      expect(find.text('List Price'), findsNothing);
    });
  });

  group('CartItem Calculation Price Rules', () {
    test('uses listPrice as calculationPrice when present', () {
      const product = CatalogueProduct(
        id: 1,
        categoryId: 1,
        productCode: 'P-1',
        name: 'Item 1',
        vehicleType: '2-Wheeler',
        price: 1500.0,
        listPrice: 1200.0,
      );

      expect(product.calculationPrice, 1200.0);
      expect(product.displayCalculationPrice, '₹ 1,200.00');

      final cartItem = CartItem(product: product, quantity: 2);
      expect(cartItem.unitPrice, 1200.0);
      expect(cartItem.lineTotal, 2400.0);
      expect(cartItem.displayUnitPrice, '₹ 1,200.00');
      expect(cartItem.displayLineTotal, '₹ 2,400.00');
    });

    test('falls back to price (MRP) when listPrice is null', () {
      const product = CatalogueProduct(
        id: 2,
        categoryId: 1,
        productCode: 'P-2',
        name: 'Item 2',
        vehicleType: '2-Wheeler',
        price: 1500.0,
        listPrice: null,
      );

      expect(product.calculationPrice, 1500.0);
      expect(product.displayCalculationPrice, '₹ 1,500.00');

      final cartItem = CartItem(product: product, quantity: 3);
      expect(cartItem.unitPrice, 1500.0);
      expect(cartItem.lineTotal, 4500.0);
      expect(cartItem.displayUnitPrice, '₹ 1,500.00');
      expect(cartItem.displayLineTotal, '₹ 4,500.00');
    });
  });

  group('Partner and Staff Home Fallback Price Display Tests', () {
    const p1 = CatalogueProduct(
      id: 101,
      categoryId: 1,
      productCode: 'PRD-LP-01',
      name: 'Disc Brake Pad',
      vehicleType: '2-Wheeler',
      price: 1500.0,
      listPrice: 1200.0,
    );

    const p2 = CatalogueProduct(
      id: 102,
      categoryId: 1,
      productCode: 'PRD-FALLBACK-02',
      name: 'Clutch Cable Wire',
      vehicleType: '2-Wheeler',
      price: 800.0,
      listPrice: null,
    );

    testWidgets('PartnerHomeScreen displays explicit List Price and temporary MRP fallback for null List Price',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final arrivalsSource = PlaceholderPartnerNewArrivalsDataSource(
        customProducts: const [p1, p2],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PartnerHomeScreen(
              newArrivalsDataSource: arrivalsSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product 1 has explicit listPrice (1,200.00) and MRP (1,500.00)
      expect(find.text('₹ 1,200.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 1,500.00'), findsOneWidget);

      // Product 2 has null listPrice, displays temporary MRP fallback
      expect(find.text('MRP (fallback): ₹ 800.00'), findsOneWidget);

      // Tap on Product 2 card to open details sheet
      await tester.tap(find.text('Clutch Cable Wire'));
      await tester.pumpAndSettle();

      // Details sheet shows fallback presentation
      expect(find.text('List Price: ₹ 800.00 (temporary MRP fallback)'), findsOneWidget);
      expect(find.text('MRP: ₹ 800.00'), findsOneWidget);
    });

    testWidgets('StaffHomeScreen displays explicit List Price and temporary MRP fallback for null List Price',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final arrivalsSource = PlaceholderStaffNewArrivalsDataSource(
        customProducts: const [p1, p2],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffHomeScreen(
              newArrivalsDataSource: arrivalsSource,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product 1 has explicit listPrice (1,200.00) and MRP (1,500.00)
      expect(find.text('₹ 1,200.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 1,500.00'), findsOneWidget);

      // Product 2 has null listPrice, displays temporary MRP fallback
      expect(find.text('MRP (fallback): ₹ 800.00'), findsOneWidget);

      // Tap on Product 2 card to open details sheet
      await tester.tap(find.text('Clutch Cable Wire'));
      await tester.pumpAndSettle();

      // Details sheet shows fallback presentation
      expect(find.text('List Price (temporary MRP fallback)'), findsOneWidget);
      expect(find.text('₹ 800.00'), findsWidgets);
    });
  });

  group('Partner Order Summary Fallback Price Labels Tests', () {
    const partnerUser = PartnerUser(
      id: 5,
      name: 'Ramesh',
      mobile: '9876543210',
      role: 'partner',
      businessName: 'Ramesh Auto Parts',
    );

    testWidgets('1. Partner order summary with both MRP and List Price displays normally and separately',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(token: 'token', user: partnerUser);

      final existingOrder = PartnerOrderResponse(
        id: 301,
        orderNumber: 'ORD-VIEW-01',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2026, 1, 1),
        itemCount: 1,
        totalQuantity: 2,
        orderTotal: 2160.0,
        items: const [
          PartnerOrderItemResponse(
            id: 1,
            productId: 101,
            productCode: 'PRD-LP-01',
            productName: 'Disc Brake Pad',
            vehicleType: '2-Wheeler',
            quantity: 2,
            unitPrice: 1080.0,
            originalPrice: 1200.0,
            listPrice: 1200.0,
            mrp: 1500.0,
            discountPercentage: 10.0,
            discountAmount: 120.0,
            discountedPrice: 1080.0,
            subtotal: 2160.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays List Price normally and MRP separately
      expect(
        find.text('List Price: ₹ 1200.00 (-10.0%) · MRP: ₹ 1500.00'),
        findsOneWidget,
      );
      expect(find.text('PRD-LP-01 · ₹ 1080.00'), findsOneWidget);
    });

    testWidgets('2. Partner order summary with MRP fallback explicitly marks temporary MRP fallback and preserves actual MRP',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(token: 'token', user: partnerUser);

      final existingOrder = PartnerOrderResponse(
        id: 302,
        orderNumber: 'ORD-FALLBACK-01',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2026, 1, 1),
        itemCount: 1,
        totalQuantity: 1,
        orderTotal: 1350.0,
        items: const [
          PartnerOrderItemResponse(
            id: 2,
            productId: 102,
            productCode: 'PRD-FALLBACK-02',
            productName: 'Clutch Cable Wire',
            vehicleType: '2-Wheeler',
            quantity: 1,
            unitPrice: 1350.0,
            originalPrice: 1500.0,
            listPrice: null, // Null List Price triggers fallback
            mrp: 1500.0,
            discountPercentage: 10.0,
            discountAmount: 150.0,
            discountedPrice: 1350.0,
            subtotal: 1350.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly displays temporary MRP fallback and preserves actual MRP snapshot
      expect(
        find.text('List Price: ₹ 1500.00 (temporary MRP fallback) (-10.0%) · MRP: ₹ 1500.00'),
        findsOneWidget,
      );
      expect(find.text('PRD-FALLBACK-02 · ₹ 1350.00'), findsOneWidget);
    });

    testWidgets('3. Partner order summary with MRP NULL displays MRP: Not set and does not display empty MRP',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(token: 'token', user: partnerUser);

      final existingOrder = PartnerOrderResponse(
        id: 303,
        orderNumber: 'ORD-NULL-MRP-01',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2026, 1, 1),
        itemCount: 1,
        totalQuantity: 1,
        orderTotal: 1080.0,
        items: const [
          PartnerOrderItemResponse(
            id: 3,
            productId: 103,
            productCode: 'PRD-NULL-MRP-03',
            productName: 'Fork Oil Seal',
            vehicleType: '2-Wheeler',
            quantity: 1,
            unitPrice: 1080.0,
            originalPrice: 1200.0,
            listPrice: 1200.0,
            mrp: null, // MRP NULL
            discountPercentage: 10.0,
            discountAmount: 120.0,
            discountedPrice: 1080.0,
            subtotal: 1080.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays List Price normally and MRP: Not set
      expect(
        find.text('List Price: ₹ 1200.00 (-10.0%) · MRP: Not set'),
        findsOneWidget,
      );
      // Ensures empty MRP value (e.g. "MRP: ₹ ") is never displayed
      expect(find.textContaining('MRP: ₹ '), findsNothing);
    });

    testWidgets('4. Partner order summary with both NULL does not invent fallback or misleading price labels',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(token: 'token', user: partnerUser);

      final existingOrder = PartnerOrderResponse(
        id: 304,
        orderNumber: 'ORD-BOTH-NULL-01',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2026, 1, 1),
        itemCount: 1,
        totalQuantity: 1,
        orderTotal: 250.0,
        items: const [
          PartnerOrderItemResponse(
            id: 4,
            productId: 104,
            productCode: 'PRD-LEGACY-TUBE',
            productName: 'Inner Tube 90/90-12',
            vehicleType: '2-Wheeler',
            quantity: 1,
            unitPrice: 250.0,
            originalPrice: null,
            listPrice: null,
            mrp: null,
            discountPercentage: null,
            discountAmount: null,
            discountedPrice: null,
            subtotal: 250.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: existingOrder,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PRD-LEGACY-TUBE · ₹ 250.00'), findsOneWidget);
      // Does not invent a fallback price or misleading price labels
      expect(find.textContaining('temporary MRP fallback'), findsNothing);
      expect(find.textContaining('MRP: ₹ '), findsNothing);
    });

    testWidgets('5. Dynamic cart item row displays List Price, MRP and MRP fallback correctly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(token: 'token', user: partnerUser);

      const prodWithBoth = CatalogueProduct(
        id: 201,
        categoryId: 1,
        productCode: 'PRD-BOTH-01',
        name: 'Spark Plug',
        vehicleType: '2-Wheeler',
        listPrice: 120.0,
        price: 150.0,
      );

      const prodFallback = CatalogueProduct(
        id: 202,
        categoryId: 1,
        productCode: 'PRD-FALL-02',
        name: 'Brake Cable',
        vehicleType: '2-Wheeler',
        listPrice: null,
        price: 300.0,
      );

      const prodNullMrp = CatalogueProduct(
        id: 203,
        categoryId: 1,
        productCode: 'PRD-NMRP-03',
        name: 'Engine Oil 1L',
        vehicleType: '2-Wheeler',
        listPrice: 500.0,
        price: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            cartItems: const [
              CartItem(product: prodWithBoth, quantity: 1),
              CartItem(product: prodFallback, quantity: 1),
              CartItem(product: prodNullMrp, quantity: 1),
            ],
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product 1: List Price and MRP
      expect(find.text('List Price: ₹ 120.00 · MRP: ₹ 150.00'), findsOneWidget);
      // Product 2: MRP fallback
      expect(find.text('List Price: ₹ 300.00 (temporary MRP fallback) · MRP: ₹ 300.00'), findsOneWidget);
      // Product 3: List Price with MRP Not set
      expect(find.text('List Price: ₹ 500.00 · MRP: Not set'), findsOneWidget);
    });
  });
}
