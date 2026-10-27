import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/partner_order_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/orders/partner_my_orders_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';

Future<PartnerOrderApi> _createOrderApi(
    {List<Map<String, dynamic>>? orders}) async {
  final session = PartnerSessionManager();
  await session.saveSession(
    token: 'test-token',
    user: const PartnerUser(
      id: 7,
      name: 'Test Partner',
      mobile: '9876543210',
      role: 'partner',
    ),
  );
  final client = MockClient((request) async {
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/orders');
    expect(request.headers['Authorization'], 'Bearer test-token');
    return http.Response(jsonEncode(orders ?? _orderFixtures), 200);
  });
  return PartnerOrderApi(client: client, sessionManager: session);
}

final List<Map<String, dynamic>> _orderFixtures = [
  ['INV-000123', 5, '2025-09-26T10:00:00', 'delivered'],
  ['INV-000124', 3, '2025-09-24T10:00:00', 'approved_processing'],
  ['INV-000125', 8, '2025-09-20T10:00:00', 'delivered'],
  ['INV-000126', 2, '2025-09-18T10:00:00', 'pending_approval'],
  ['INV-000127', 6, '2025-09-15T10:00:00', 'approved_processing'],
].map((order) {
  return {
    'id': 1,
    'order_number': order[0],
    'partner_id': 7,
    'partner_name': 'Test Partner',
    'partner_mobile': '9876543210',
    'status': order[3],
    'created_at': order[2],
    'item_count': order[1],
    'total_quantity': order[1],
    'order_total': '100.00',
    'items': [],
  };
}).toList();

void main() {
  group('PartnerMyOrdersScreen Tests', () {
    testWidgets('renders order history returned by the authenticated API',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerMyOrdersScreen(api: await _createOrderApi()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. My Orders screen renders
      expect(find.byType(PartnerMyOrdersScreen), findsOneWidget);

      // 2. "My Orders" title exists
      expect(find.text('My Orders'), findsWidgets);

      // 3. Subtitle exists
      expect(find.text('View and manage your past and current orders.'),
          findsOneWidget);

      // 4. API orders render their invoice numbers.
      expect(find.textContaining('INV-000123'), findsOneWidget);
      expect(find.textContaining('INV-000124'), findsOneWidget);
      expect(find.textContaining('INV-000125'), findsOneWidget);
      expect(find.textContaining('INV-000126'), findsOneWidget);
      expect(find.textContaining('INV-000127'), findsOneWidget);

      // 5. All 5 order dates exist
      expect(find.textContaining('26 Sep 2025'), findsOneWidget);
      expect(find.textContaining('24 Sep 2025'), findsOneWidget);
      expect(find.textContaining('20 Sep 2025'), findsOneWidget);
      expect(find.textContaining('18 Sep 2025'), findsOneWidget);
      expect(find.textContaining('15 Sep 2025'), findsOneWidget);

      // 6. All 5 item counts exist
      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('8'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('6'), findsWidgets);

      // 7. Statuses exist
      expect(find.text('Delivered'), findsNWidgets(2));
      expect(find.text('Processing'), findsNWidgets(2));
      expect(find.text('Pending'), findsOneWidget);

      // 8. View and Cancel buttons exist
      expect(find.text('View'), findsNWidgets(5));
      expect(find.text('Cancel'), findsNWidgets(5));

      // 9. Bottom navigation options
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping View shows placeholder SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerMyOrdersScreen(api: await _createOrderApi()),
        ),
      );
      await tester.pumpAndSettle();

      final viewButton = find.text('View').first;
      await tester.ensureVisible(viewButton);
      await tester.tap(viewButton);
      await tester.pump();

      expect(
          find.text('Order details are not implemented yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Cancel shows placeholder SnackBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerMyOrdersScreen(api: await _createOrderApi()),
        ),
      );
      await tester.pumpAndSettle();

      final cancelButton = find.text('Cancel').first;
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pump();

      expect(find.text('Order cancellation is not implemented yet'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('screen is scrollable to reveal all 5 order cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createOrderApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerMyOrdersScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);

      // Scroll to bottom card (INV-000127)
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('INV-000127'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back button returns to Partner Home screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createOrderApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(orderApi: api),
          routes: {
            '/my_orders': (context) => PartnerMyOrdersScreen(api: api),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to My Orders
      await tester.tap(find.text('My Orders'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerMyOrdersScreen), findsOneWidget);

      // Tap upper-left back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Profile navigation still works from bottom navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createOrderApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerMyOrdersScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Partner Home My Orders card navigates to PartnerMyOrdersScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createOrderApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(orderApi: api),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('My Orders'));
      await tester.tap(find.text('My Orders'));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerMyOrdersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
