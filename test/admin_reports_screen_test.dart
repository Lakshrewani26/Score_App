import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_reports_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/admin/reports/admin_reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Report Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  final sampleReportJson = {
    'generated_at': '2026-10-26T06:00:00Z',
    'filter': {
      'preset': '30d',
      'date_from': '2026-09-26T00:00:00Z',
      'date_to': '2026-10-26T23:59:59Z',
      'interval': 'daily',
    },
    'overview': {
      'total_orders': 42,
      'orders_pending_approval': 12,
      'orders_processing': 10,
      'orders_dispatched': 8,
      'orders_delivered': 10,
      'orders_rejected': 2,
      'total_stock_requests': 15,
      'stock_requests_pending_approval': 5,
      'stock_requests_approved': 8,
      'stock_requests_rejected': 2,
      'total_order_value': '154200.00',
    },
    'catalogue_summary': {
      'total_products': 120,
      'active_products': 115,
      'inactive_products': 5,
      'total_categories': 12,
      'active_categories': 10,
      'inactive_categories': 2,
      'products_with_null_price': 3,
    },
    'order_status_distribution': [
      {'status': 'pending_approval', 'label': 'Pending Approval', 'count': 12},
      {'status': 'approved_processing', 'label': 'Processing', 'count': 10},
      {'status': 'dispatched', 'label': 'Dispatched', 'count': 8},
      {'status': 'delivered', 'label': 'Delivered', 'count': 10},
      {'status': 'rejected', 'label': 'Rejected', 'count': 2},
    ],
    'stock_request_status_distribution': [
      {'status': 'pending_approval', 'label': 'Pending Approval', 'count': 5},
      {'status': 'approved', 'label': 'Approved', 'count': 8},
      {'status': 'rejected', 'label': 'Rejected', 'count': 2},
    ],
    'order_trends': [
      {
        'period': '2026-10-24',
        'label': '24 Oct',
        'count': 4,
        'total_value': '16000.00'
      },
      {
        'period': '2026-10-25',
        'label': '25 Oct',
        'count': 6,
        'total_value': '24000.00'
      },
      {
        'period': '2026-10-26',
        'label': '26 Oct',
        'count': 2,
        'total_value': '8000.00'
      },
    ],
    'unsupported_metrics': [
      'points_balances_and_history',
      'qr_scans_and_batches',
      'payment_gateway_transactions',
      'inventory_stock_quantities',
    ],
  };

  Widget buildTestWidget({
    AdminReportsApi? reportsApi,
    AdminSessionManager? sessionManager,
  }) {
    return MaterialApp(
      home: AdminReportsScreen(
        reportsApi: reportsApi,
        sessionManager: sessionManager,
      ),
    );
  }

  group('Admin Reports Screen Widget Tests', () {
    testWidgets('1. Dashboard does not display the Reports & Analytics tile',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager.instance;
      await sessionManager.saveSession(
          token: 'valid-token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reports & Analytics'), findsNothing);
      expect(find.text('Transaction logs & points history'), findsNothing);
    });

    testWidgets('2. Displays loading indicator while fetching reports',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        // Return response without immediate completion
        await Future.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode(sampleReportJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pump(); // Frame before response completes

      expect(find.byKey(const Key('admin_reports_loading')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_reports_loading')), findsNothing);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets(
        '3. Renders mock API response overview values, catalogue, and distribution',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        return http.Response(jsonEncode(sampleReportJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pumpAndSettle();

      // Overview metrics
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Total Value'), findsOneWidget);
      expect(find.text('Pending Staff'), findsOneWidget);
      expect(find.text('12'), findsWidgets); // Order pending (12)
      expect(find.text('Processing'), findsWidgets);
      expect(
          find.text('10'), findsWidgets); // Processing (10) or Delivered (10)
      expect(find.text('Dispatched'), findsWidgets);
      expect(find.text('8'), findsWidgets); // Dispatched (8)
      expect(find.text('Delivered'), findsWidgets);
      expect(find.text('Rejected'), findsWidgets);

      // Stock requests
      expect(find.text('Total Stock Requests'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);

      // Catalogue
      expect(find.text('115 active / 120 total'), findsOneWidget);
      expect(find.text('10 active / 12 total'), findsOneWidget);
      expect(find.text('3 product(s) have no price configured (null price).'),
          findsOneWidget);

      // Trends
      expect(find.text('24 Oct'), findsOneWidget);
      expect(find.text('25 Oct'), findsOneWidget);
      expect(find.text('26 Oct'), findsOneWidget);

      // Notice banner
      expect(
        find.textContaining(
            'Notice: Points balances/transactions, QR code scan logs'),
        findsOneWidget,
      );
    });

    testWidgets('4. Error state renders friendly message with retry button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
              jsonEncode({'detail': 'Database connection error'}), 500);
        }
        return http.Response(jsonEncode(sampleReportJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pumpAndSettle();

      expect(find.text('Database connection error'), findsOneWidget);
      expect(
          find.byKey(const Key('admin_reports_retry_button')), findsOneWidget);

      // Tap retry
      await tester.tap(find.byKey(const Key('admin_reports_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
      expect(find.byKey(const Key('admin_reports_retry_button')), findsNothing);
    });

    testWidgets('5. Switching date presets triggers request with preset param',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.queryParameters['preset'] ?? '');
        return http.Response(jsonEncode(sampleReportJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pumpAndSettle();

      expect(requests.last, equals('30d'));

      // Switch to 7d
      await tester.ensureVisible(find.byKey(const Key('preset_chip_7d')));
      await tester.tap(find.byKey(const Key('preset_chip_7d')));
      await tester.pumpAndSettle();
      expect(requests.last, equals('7d'));

      // Switch to 90d
      await tester.ensureVisible(find.byKey(const Key('preset_chip_90d')));
      await tester.tap(find.byKey(const Key('preset_chip_90d')));
      await tester.pumpAndSettle();
      expect(requests.last, equals('90d'));

      // Switch to all_time
      await tester.ensureVisible(find.byKey(const Key('preset_chip_all_time')));
      await tester.tap(find.byKey(const Key('preset_chip_all_time')));
      await tester.pumpAndSettle();
      expect(requests.last, equals('all_time'));
    });

    testWidgets('6. Refresh button reloads current report data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response(jsonEncode(sampleReportJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pumpAndSettle();

      expect(callCount, equals(1));

      await tester.tap(find.byKey(const Key('admin_reports_refresh_button')));
      await tester.pumpAndSettle();

      expect(callCount, equals(2));
    });

    testWidgets('7. Handles empty data states gracefully without crashing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyJson = {
        'generated_at': '2026-10-26T06:00:00Z',
        'filter': {'preset': '7d', 'interval': 'daily'},
        'overview': {
          'total_orders': 0,
          'orders_pending_approval': 0,
          'orders_processing': 0,
          'orders_dispatched': 0,
          'orders_delivered': 0,
          'orders_rejected': 0,
          'total_stock_requests': 0,
          'stock_requests_pending_approval': 0,
          'stock_requests_approved': 0,
          'stock_requests_rejected': 0,
          'total_order_value': '0.00',
        },
        'catalogue_summary': {
          'total_products': 0,
          'active_products': 0,
          'inactive_products': 0,
          'total_categories': 0,
          'active_categories': 0,
          'inactive_categories': 0,
          'products_with_null_price': 0,
        },
        'order_status_distribution': [],
        'stock_request_status_distribution': [],
        'order_trends': [],
        'unsupported_metrics': [],
      };

      final client = MockClient((request) async {
        return http.Response(jsonEncode(emptyJson), 200);
      });
      final reportsApi =
          AdminReportsApi(client: client, baseUrl: 'http://test-server');

      await tester.pumpWidget(buildTestWidget(reportsApi: reportsApi));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(find.text('No orders recorded in this period.'), findsOneWidget);
      expect(
          find.text('No trend data available for this range.'), findsOneWidget);
      expect(find.text('All catalogue products have valid prices configured.'),
          findsOneWidget);
    });
  });
}
