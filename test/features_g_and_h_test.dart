import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/models/partner_order_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_qr_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/admin_settings_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/admin/qr/widgets/admin_print_product_qr_dialog.dart';
import 'package:score_app/features/admin/settings/admin_settings_screen.dart';
import 'package:score_app/features/admin/settings/widgets/admin_points_rule_dialog.dart';
import 'package:score_app/features/admin/users/widgets/create_partner_dialog.dart';
import 'package:score_app/features/admin/users/widgets/edit_user_dialog.dart';
import 'package:score_app/features/partner/orders/partner_order_summary_screen.dart';

void main() {
  const mockAdmin = AdminUser(
    id: 1,
    name: 'Admin User',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  group('Feature G: Advanced Loyalty Point Rules Tests', () {
    testWidgets(
        'Points rule dialog supports separate customer_qr_scan and partner_qr_scan with point values & conversion rates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? submittedBody;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/points-rules' &&
            request.method == 'POST') {
          submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 101,
              'rule_name': 'Customer Scan Loyalty',
              'category': 'customer_qr_scan',
              'points_awarded': 25,
              'conversion_rate': 0.10,
              'point_value': 0.50,
              'version': 1,
              'is_active': true,
              'effective_from': '2026-01-01T00:00:00Z',
            }),
            201,
          );
        }
        return http.Response('Not found', 404);
      });

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'test_token', user: mockAdmin);
      final settingsApi = AdminSettingsApi(
        client: client,
        sessionManager: session,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPointsRuleDialog(
              settingsApi: settingsApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check fields exist
      expect(find.text('Create Points Rule'), findsOneWidget);
      expect(find.byKey(const Key('rule_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('point_value_field')), findsOneWidget);
      expect(find.byKey(const Key('conversion_rate_field')), findsOneWidget);

      // Select customer_qr_scan
      await tester.tap(find.byKey(const Key('rule_category_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer QR Scanning').last);
      await tester.pumpAndSettle();

      // Enter rule name and points
      await tester.enterText(
          find.byKey(const Key('rule_name_field')), 'Customer Scan Loyalty');
      await tester.enterText(
          find.byKey(const Key('points_awarded_field')), '25');
      await tester.enterText(
          find.byKey(const Key('point_value_field')), '0.50');
      await tester.enterText(
          find.byKey(const Key('conversion_rate_field')), '0.10');

      // Submit
      await tester.tap(find.byKey(const Key('save_rule_button')));
      await tester.pumpAndSettle();

      expect(submittedBody, isNotNull);
      expect(submittedBody!['category'], 'customer_qr_scan');
      expect(submittedBody!['points_awarded'], 25);
      expect(submittedBody!['point_value'], 0.50);
      expect(submittedBody!['conversion_rate'], 0.10);
    });

    testWidgets(
        'Admin Settings displays rule version badge and triggers history retrieval',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdmin);

      var historyRequested = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(
            jsonEncode({
              'app_name': 'Score API',
              'environment': 'test',
              'api_version': '1.0.0',
              'database_status': 'connected',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 10,
                  'rule_name': 'Partner Welcome Scan',
                  'category': 'partner_qr_scan',
                  'points_awarded': 100,
                  'conversion_rate': 0.25,
                  'point_value': 1.00,
                  'version': 2,
                  'is_active': true,
                  'effective_from': '2026-01-01T00:00:00Z',
                  'effective_to': null,
                  'parent_rule_id': 9,
                  'created_at': '2026-01-01T00:00:00Z',
                  'created_by': 1,
                  'created_by_name': 'Admin User',
                }
              ],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/points-rules/10/history') {
          historyRequested = true;
          return http.Response(
            jsonEncode({
              'current_rule': {
                'id': 10,
                'rule_name': 'Partner Welcome Scan',
                'category': 'partner_qr_scan',
                'points_awarded': 100,
                'conversion_rate': 0.25,
                'point_value': 1.00,
                'version': 2,
                'is_active': true,
                'effective_from': '2026-01-01T00:00:00Z',
              },
              'history': [
                {
                  'id': 9,
                  'rule_name': 'Partner Welcome Scan (Legacy)',
                  'category': 'partner_qr_scan',
                  'points_awarded': 50,
                  'conversion_rate': 0.20,
                  'point_value': 1.00,
                  'version': 1,
                  'is_active': false,
                  'effective_from': '2025-01-01T00:00:00Z',
                  'effective_to': '2025-12-31T23:59:59Z',
                }
              ],
              'total_versions': 2,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        sessionManager: session,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            adminApi: adminApi,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rule is displayed with version badge
      expect(find.text('Partner Welcome Scan'), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);
      expect(find.text('+100 pts'), findsOneWidget);
      expect(find.text('Point Value'), findsOneWidget);
      expect(find.text('₹1.00'), findsOneWidget);

      // Tap history action icon
      final historyButton = find.byKey(const Key('history_rule_10'));
      expect(historyButton, findsOneWidget);
      await tester.ensureVisible(historyButton);
      await tester.tap(historyButton);
      await tester.pumpAndSettle();

      expect(historyRequested, isTrue);
      expect(find.text('Rule Version History'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
      expect(find.text('LATEST'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'Admin Settings clearly distinguishes currently effective rule from future scheduled version',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdmin);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(
            jsonEncode({
              'app_name': 'Score API',
              'environment': 'test',
              'api_version': '1.0.0',
              'database_status': 'connected',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 21,
                  'rule_name': 'Future Monsoon Campaign',
                  'category': 'customer_qr_scan',
                  'points_awarded': 200,
                  'version': 2,
                  'is_active': true,
                  'is_current': true,
                  'effective_from': '2029-06-01T00:00:00Z',
                  'effective_status': 'future_scheduled',
                  'is_currently_effective': false,
                  'is_future_scheduled': true,
                  'created_at': '2026-01-01T00:00:00Z',
                },
                {
                  'id': 22,
                  'rule_name': 'Regular Customer Loyalty',
                  'category': 'customer_qr_scan',
                  'points_awarded': 50,
                  'version': 1,
                  'is_active': true,
                  'is_current': true,
                  'effective_from': '2020-01-01T00:00:00Z',
                  'effective_status': 'currently_effective',
                  'is_currently_effective': true,
                  'is_future_scheduled': false,
                  'created_at': '2026-01-01T00:00:00Z',
                },
              ],
              'total': 2,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        sessionManager: session,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            adminApi: adminApi,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Future scheduled version shows SCHEDULED badge and explanatory note
      expect(find.text('Future Monsoon Campaign'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);
      expect(
          find.textContaining('Scheduled version v2: Takes effect on'),
          findsOneWidget);
      expect(find.textContaining('Not currently effective.'), findsOneWidget);

      // Currently effective version shows EFFECTIVE badge
      expect(find.text('Regular Customer Loyalty'), findsOneWidget);
      expect(find.text('EFFECTIVE'), findsOneWidget);
    });
  });

  group('Feature H1: Product QR Number Printing Tests', () {
    testWidgets(
        'Product QR label dialog selects products, shows clean labels without QR images',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/products/labels') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'product_id': 10,
                  'product_name': 'Front Brake Disc',
                  'product_code': 'BD-001',
                  'qr_number': 'SCORE-PRD-99887766554433221100',
                  'batch_id': null,
                  'status': 'active',
                },
                {
                  'product_id': 11,
                  'product_name': 'Clutch Cable Pro',
                  'product_code': 'CC-002',
                  'qr_number': 'SCORE-PRD-11223344556677889900',
                  'batch_id': null,
                  'status': 'active',
                },
              ],
              'total': 2,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/catalogue/products') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 10,
                  'name': 'Front Brake Disc',
                  'product_code': 'BD-001',
                  'price': 1200.0,
                  'is_active': true,
                },
                {
                  'id': 11,
                  'name': 'Clutch Cable Pro',
                  'product_code': 'CC-002',
                  'price': 450.0,
                  'is_active': true,
                },
              ],
              'total': 2,
              'page': 1,
              'page_size': 100,
              'total_pages': 1,
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdmin);
      final adminApi = AdminApi(client: client, sessionManager: session);
      final qrApi = AdminQrApi(client: client, sessionManager: session);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminPrintProductQrDialog(
              qrApi: qrApi,
              adminApi: adminApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dialog loaded products
      expect(find.text('Product QR Number Printing'), findsOneWidget);
      expect(find.text('Front Brake Disc'), findsOneWidget);
      expect(find.text('Clutch Cable Pro'), findsOneWidget);

      // Select all products and preview labels
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview Labels'));
      await tester.pumpAndSettle();

      // Verify label cards show product name, product code, and unique QR ID
      expect(find.text('CODE: BD-001'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is SelectableText &&
            w.data == 'SCORE-PRD-99887766554433221100'),
        findsOneWidget,
      );
      expect(find.text('CODE: CC-002'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is SelectableText &&
            w.data == 'SCORE-PRD-11223344556677889900'),
        findsOneWidget,
      );

      // Verify NO barcode or scannable image widget exists in label preview
      expect(find.byType(Image), findsNothing);
    });
  });

  group('Feature H2: Partner-Specific Percentage Discounts Tests', () {
    testWidgets(
        'CreatePartnerDialog includes Partner Discount field with 0-100% validation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/partners') {
          return http.Response(
            jsonEncode({
              'id': 20,
              'name': 'PQR Auto',
              'mobile': '9876543210',
              'role': 'partner',
              'is_active': true,
              'partner_profile': {
                'business_name': 'PQR Spares',
                'business_address': '123 Market St',
                'discount_percentage': 15.5,
              },
            }),
            201,
          );
        }
        if (request.url.path == '/api/v1/admin/zones') {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        sessionManager:
            AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePartnerDialog(
              adminApi: adminApi,
              token: 'test_token',
              onSuccess: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('partner_discount_field')), findsOneWidget);

      // Test negative discount validation
      await tester.enterText(
          find.byKey(const Key('partner_discount_field')), '-5.0');
      final submitPartnerButton =
          find.byKey(const Key('submit_create_partner_button'));
      await tester.ensureVisible(submitPartnerButton);
      await tester.tap(submitPartnerButton);
      await tester.pumpAndSettle();
      expect(find.text('Discount must be between 0% and 100%'), findsOneWidget);

      // Test >100% validation
      await tester.enterText(
          find.byKey(const Key('partner_discount_field')), '105.0');
      await tester.ensureVisible(submitPartnerButton);
      await tester.tap(submitPartnerButton);
      await tester.pumpAndSettle();
      expect(find.text('Discount must be between 0% and 100%'), findsOneWidget);
    });

    testWidgets(
        'EditUserDialog allows updating Partner Discount for partner role',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final partnerSummary = const AdminUserSummary(
        id: 30,
        name: 'Auto Hub',
        mobile: '9876543210',
        role: 'partner',
        isActive: true,
        businessName: 'Auto Hub Spares',
        discountPercentage: 10.0,
      );

      Map<String, dynamic>? updatedBody;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/30' &&
            (request.method == 'PUT' || request.method == 'PATCH')) {
          updatedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 30,
              'name': 'Auto Hub',
              'mobile': '9876543210',
              'role': 'partner',
              'is_active': true,
              'partner_profile': {
                'business_name': 'Auto Hub Spares',
                'discount_percentage': 20.0,
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/zones') {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response('Not found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        sessionManager:
            AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditUserDialog(
              user: partnerSummary,
              adminApi: adminApi,
              token: 'test_token',
              onSuccess: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final discountField = find.byKey(const Key('edit_partner_discount_field'));
      expect(discountField, findsOneWidget);
      expect(find.text('10.00'), findsOneWidget);

      await tester.enterText(discountField, '20.0');
      final submitEditButton = find.byKey(const Key('submit_edit_user_button'));
      await tester.ensureVisible(submitEditButton);
      await tester.tap(submitEditButton);
      await tester.pumpAndSettle();

      expect(updatedBody, isNotNull);
      expect(updatedBody!['discount_percentage'], 20.0);
    });

    testWidgets(
        'PartnerOrderSummaryScreen renders discount breakdown in View Mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      session.saveSession(
        token: 'test-token',
        user: const PartnerUser(
          id: 5,
          name: 'Ramesh',
          mobile: '9876543210',
          role: 'partner',
          businessName: 'Ramesh Auto Parts',
        ),
      );

      final orderWithDiscount = PartnerOrderResponse(
        id: 501,
        orderNumber: 'INV-55001',
        partnerId: 5,
        partnerName: 'Ramesh',
        businessName: 'Ramesh Auto Parts',
        partnerMobile: '9876543210',
        status: 'pending_approval',
        createdAt: DateTime(2026, 11, 1, 10, 0),
        itemCount: 1,
        totalQuantity: 2,
        orderTotal: 1800.0,
        subtotalBeforeDiscount: 2000.0,
        discountPercentage: 10.0,
        totalDiscount: 200.0,
        finalTotal: 1800.0,
        items: const [
          PartnerOrderItemResponse(
            id: 1,
            productId: 101,
            productCode: 'TYRE-PRO',
            productName: 'Tubeless Tyre 90/90-12',
            vehicleType: '2-Wheeler',
            quantity: 2,
            unitPrice: 900.0,
            subtotal: 1800.0,
            originalPrice: 1000.0,
            discountPercentage: 10.0,
            discountAmount: 100.0,
            discountedPrice: 900.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerOrderSummaryScreen(
            existingOrder: orderWithDiscount,
            sessionManager: session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays item details with discount breakdown
      expect(find.text('Tubeless Tyre 90/90-12'), findsOneWidget);
      expect(find.text('TYRE-PRO · ₹ 900.00'), findsOneWidget);
      expect(find.text('MRP: ₹ 1000.00 (-10.0%)'), findsOneWidget);

      // Displays order summary totals
      expect(find.text('Subtotal Before Discount'), findsOneWidget);
      expect(find.text('₹ 2000.00'), findsOneWidget);
      expect(find.text('Partner Discount (10.0%)'), findsOneWidget);
      expect(find.text('-₹ 200.00'), findsOneWidget);
      expect(find.text('₹ 1,800.00'), findsOneWidget);
    });
  });
}
