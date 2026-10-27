import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/catalogue_models.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/partner_order_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';

import 'catalogue_test_support.dart';

void main() {
  setUp(() {
    PartnerSessionManager.instance.saveSession(
      token: 'fake-jwt-token-partner',
      user: const PartnerUser(
        id: 42,
        name: 'Rahul Partner',
        mobile: '+919876543220',
        role: 'partner',
        businessName: 'Rahul Auto Spares',
        businessAddress: 'Shop 12, Sunrise Complex, CG Road, Ahmedabad',
        partnerCode: 'RP-0042',
      ),
    );
  });

  group('Partner Order Flow Widget Tests', () {
    testWidgets('Continue opens Order Summary and preserves quantities on back',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTwoWheelerCatalogueScreen(
            api: buildTestCatalogueApi(requests),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initially 0 units selected
      expect(find.text('Selected units: 0'), findsOneWidget);

      final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
      expect(continueButton, findsOneWidget);

      // 2. Tapping Continue with empty cart shows validation message and remains on screen
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Please select at least one product with quantity greater than zero.'),
        findsOneWidget,
      );
      expect(find.text('Order Summary'), findsNothing);

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 3. Add quantity: 2 of Part 1
      await tester.tap(find.byKey(const Key('quantity-plus-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quantity-plus-1')));
      await tester.pumpAndSettle();
      expect(find.text('Selected units: 2'), findsOneWidget);

      // 4. Tap Continue -> Navigates to Order Summary screen
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // On Order Summary Screen
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('2-Wheeler Part 1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // quantity
      expect(find.text('Place Order'), findsOneWidget);

      // 5. Navigate back to catalogue -> selection preserved!
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Selected units: 2'), findsOneWidget);
    });

    testWidgets('Place Order submits authenticated order, generates PDF, and sends WhatsApp',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = CatalogueProduct(
        id: 101,
        categoryId: 1,
        productCode: 'TYRE-2W-101',
        name: 'Radial Tubeless Tyre',
        vehicleType: '2-Wheeler',
        price: 2500.0,
      );

      final cartItems = [
        CartItem(product: product, quantity: 2),
      ];

      int createOrderCallCount = 0;
      int sendWhatsAppCallCount = 0;
      int downloadPdfCallCount = 0;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path == '/api/v1/orders' && request.method == 'POST') {
          createOrderCallCount++;
          final body = jsonDecode(request.body);
          expect(body['items'], isNotEmpty);
          expect(request.headers['authorization'], contains('fake-jwt-token-partner'));
          return http.Response(
            jsonEncode({
              'id': 501,
              'order_number': 'ORD-20261026-0001-TEST',
              'partner_id': 42,
              'partner_name': 'Rahul Partner',
              'business_name': 'Rahul Auto Spares',
              'business_address': 'Shop 12, Sunrise Complex, CG Road, Ahmedabad',
              'partner_mobile': '+919876543220',
              'status': 'pending_approval',
              'notes': 'Test notes',
              'created_at': DateTime.now().toIso8601String(),
              'item_count': 1,
              'total_quantity': 2,
              'order_total': 5000.0,
              'items': [
                {
                  'id': 1,
                  'product_id': 101,
                  'product_code': 'TYRE-2W-101',
                  'product_name': 'Radial Tubeless Tyre',
                  'vehicle_type': '2-Wheeler',
                  'quantity': 2,
                  'unit_price': 2500.0,
                  'subtotal': 5000.0,
                }
              ],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/v1/orders/501/send-whatsapp' &&
            request.method == 'POST') {
          sendWhatsAppCallCount++;
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'delivered',
              'message': 'PDF sent via WhatsApp Cloud API to +919876543220',
              'recipient': '+919876543220',
              'provider': 'cloud_api',
              'message_id': 'wamid.HBgLM...=',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/v1/orders/501/pdf' && request.method == 'GET') {
          downloadPdfCallCount++;
          return http.Response.bytes(
            Uint8List.fromList([0x25, 0x50, 0x44, 0x46]), // %PDF
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition': 'inline; filename="Score_Order_ORD-20261026-0001-TEST.pdf"',
            },
          );
        }

        return http.Response('{"detail":"Not found"}', 404);
      });

      final testApi = PartnerOrderApi(client: mockClient, baseUrl: 'http://test.local');
      bool cartCleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            cartItems: cartItems,
            api: testApi,
            onOrderSuccess: () {
              cartCleared = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check displayed items and grand total
      expect(find.text('Radial Tubeless Tyre'), findsOneWidget);
      expect(find.text('TYRE-2W-101 · ₹ 2,500.00'), findsOneWidget);
      expect(find.byKey(const Key('order-item-qty-0')), findsOneWidget);
      expect(find.text('₹ 5,000.00'), findsNWidgets(2)); // line total & grand total

      // Tap Place Order
      final placeOrderButton = find.byKey(const Key('place-order-button'));
      await tester.ensureVisible(placeOrderButton);
      await tester.tap(placeOrderButton);
      await tester.pumpAndSettle();

      // Verify order creation called exactly once
      expect(createOrderCallCount, 1);
      expect(cartCleared, isTrue);

      // Verify success modal appeared
      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(find.text('Order #: ORD-20261026-0001-TEST'), findsOneWidget);
      expect(find.text('Status: Pending Approval'), findsOneWidget);
      expect(find.text('Total: ₹ 5,000.00'), findsOneWidget);

      // Verify WhatsApp delivery succeeded
      expect(sendWhatsAppCallCount, 1);
      expect(
        find.text('PDF sent via WhatsApp Cloud API to +919876543220'),
        findsOneWidget,
      );

      // Test Download PDF button
      final downloadPdfButton = find.byKey(const Key('download-pdf-button'));
      await tester.ensureVisible(downloadPdfButton);
      await tester.tap(downloadPdfButton);
      await tester.pumpAndSettle();
      expect(downloadPdfCallCount, 1);

      // Tap Done and Return to Catalogue
      final returnButton = find.byKey(const Key('return-to-catalogue-button'));
      await tester.ensureVisible(returnButton);
      await tester.tap(returnButton);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'WhatsApp unconfigured state allows retrying delivery without creating duplicate order',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = CatalogueProduct(
        id: 102,
        categoryId: 1,
        productCode: 'BRAKE-002',
        name: 'Brake Shoe Set',
        vehicleType: '2-Wheeler',
        price: 450.0,
      );

      final cartItems = [
        CartItem(product: product, quantity: 1),
      ];

      int createOrderCallCount = 0;
      int sendWhatsAppCallCount = 0;

      final mockClient = MockClient((http.Request request) async {
        if (request.url.path == '/api/v1/orders' && request.method == 'POST') {
          createOrderCallCount++;
          return http.Response(
            jsonEncode({
              'id': 601,
              'order_number': 'ORD-20261026-0002-RETRY',
              'partner_id': 42,
              'partner_name': 'Rahul Partner',
              'partner_mobile': '+919876543220',
              'status': 'pending_approval',
              'created_at': DateTime.now().toIso8601String(),
              'item_count': 1,
              'total_quantity': 1,
              'order_total': 450.0,
              'items': [],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/v1/orders/601/send-whatsapp' &&
            request.method == 'POST') {
          sendWhatsAppCallCount++;
          if (sendWhatsAppCallCount == 1) {
            // First attempt: missing credentials
            return http.Response(
              jsonEncode({
                'success': false,
                'status': 'missing_credentials',
                'message': 'WhatsApp provider is not configured. Set WHATSAPP_API_TOKEN in environment.',
                'recipient': '+919876543220',
                'provider': 'cloud_api',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            // Retry attempt: succeeds
            return http.Response(
              jsonEncode({
                'success': true,
                'status': 'delivered',
                'message': 'PDF sent via WhatsApp Cloud API on retry',
                'recipient': '+919876543220',
                'provider': 'cloud_api',
                'message_id': 'wamid.RETRY123',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }

        return http.Response('{"detail":"Not found"}', 404);
      });

      final testApi = PartnerOrderApi(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            cartItems: cartItems,
            api: testApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit order
      final placeOrderButton = find.byKey(const Key('place-order-button'));
      await tester.ensureVisible(placeOrderButton);
      await tester.tap(placeOrderButton);
      await tester.pumpAndSettle();

      // 1 order created
      expect(createOrderCallCount, 1);
      expect(sendWhatsAppCallCount, 1);

      // Unconfigured message displayed
      expect(
        find.text('WhatsApp provider is not configured. Set WHATSAPP_API_TOKEN in environment.'),
        findsOneWidget,
      );

      // Retry WhatsApp
      final retryButton = find.byKey(const Key('retry-whatsapp-button'));
      expect(retryButton, findsOneWidget);
      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      // WhatsApp was re-attempted, but NO second order was created!
      expect(sendWhatsAppCallCount, 2);
      expect(createOrderCallCount, 1); // Still exactly 1!
      expect(
        find.text('PDF sent via WhatsApp Cloud API on retry'),
        findsOneWidget,
      );
    });
  });
}
