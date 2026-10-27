import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_reports_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockAdminUser = const AdminUser(
    id: 1,
    name: 'Report Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  group('AdminReportsApi Tests', () {
    test('1. Successful JSON response parses completely into AdminReportOverview', () async {
      final mockPayload = {
        'generated_at': '2026-10-26T06:00:00Z',
        'filter': {
          'preset': '30d',
          'date_from': '2026-09-26T00:00:00Z',
          'date_to': '2026-10-26T23:59:59Z',
          'interval': 'daily',
        },
        'overview': {
          'total_orders': 25,
          'orders_pending_approval': 5,
          'orders_processing': 4,
          'orders_dispatched': 6,
          'orders_delivered': 8,
          'orders_rejected': 2,
          'total_stock_requests': 10,
          'stock_requests_pending_approval': 3,
          'stock_requests_approved': 6,
          'stock_requests_rejected': 1,
          'total_order_value': '125400.50',
        },
        'catalogue_summary': {
          'total_products': 50,
          'active_products': 45,
          'inactive_products': 5,
          'total_categories': 8,
          'active_categories': 7,
          'inactive_categories': 1,
          'products_with_null_price': 3,
        },
        'order_status_distribution': [
          {'status': 'pending_approval', 'label': 'Pending Approval', 'count': 5},
          {'status': 'approved_processing', 'label': 'Processing', 'count': 4},
          {'status': 'dispatched', 'label': 'Dispatched', 'count': 6},
          {'status': 'delivered', 'label': 'Delivered', 'count': 8},
          {'status': 'rejected', 'label': 'Rejected', 'count': 2},
        ],
        'stock_request_status_distribution': [
          {'status': 'pending_approval', 'label': 'Pending Approval', 'count': 3},
          {'status': 'approved', 'label': 'Approved', 'count': 6},
          {'status': 'rejected', 'label': 'Rejected', 'count': 1},
        ],
        'order_trends': [
          {
            'period': '2026-10-25',
            'label': '25 Oct',
            'count': 3,
            'total_value': '15000.00',
          },
          {
            'period': '2026-10-26',
            'label': '26 Oct',
            'count': 0,
            'total_value': '0.00',
          },
        ],
        'unsupported_metrics': [
          'points_balances_and_history',
          'qr_scans_and_batches',
          'payment_gateway_transactions',
          'inventory_stock_quantities',
        ],
      };

      final client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/admin/reports/overview'));
        expect(request.headers['Authorization'], equals('Bearer test-jwt-token'));
        expect(request.url.queryParameters['preset'], equals('30d'));
        return http.Response(jsonEncode(mockPayload), 200);
      });

      final api = AdminReportsApi(
        client: client,
        baseUrl: 'http://test-server',
      );

      final report = await api.getReportOverview(
        preset: '30d',
        token: 'test-jwt-token',
      );

      expect(report.overview.totalOrders, equals(25));
      expect(report.overview.ordersPendingApproval, equals(5));
      expect(report.overview.ordersProcessing, equals(4));
      expect(report.overview.ordersDispatched, equals(6));
      expect(report.overview.ordersDelivered, equals(8));
      expect(report.overview.ordersRejected, equals(2));
      expect(report.overview.totalStockRequests, equals(10));
      expect(report.overview.totalOrderValue, equals(125400.50));

      expect(report.catalogueSummary.totalProducts, equals(50));
      expect(report.catalogueSummary.activeProducts, equals(45));
      expect(report.catalogueSummary.inactiveProducts, equals(5));
      expect(report.catalogueSummary.productsWithNullPrice, equals(3));

      expect(report.orderStatusDistribution.length, equals(5));
      expect(report.stockRequestStatusDistribution.length, equals(3));
      expect(report.orderTrends.length, equals(2));
      expect(report.orderTrends[0].label, equals('25 Oct'));
      expect(report.orderTrends[0].count, equals(3));
      expect(report.orderTrends[1].count, equals(0));

      expect(report.unsupportedMetrics, contains('points_balances_and_history'));
      expect(report.unsupportedMetrics, contains('qr_scans_and_batches'));
    });

    test('2. Query parameters for date range and interval are correctly formatted and sent', () async {
      final client = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/admin/reports/overview'));
        expect(request.url.queryParameters['preset'], equals('custom'));
        expect(request.url.queryParameters['date_from'], equals('2026-10-01'));
        expect(request.url.queryParameters['date_to'], equals('2026-10-15'));
        expect(request.url.queryParameters['interval'], equals('weekly'));
        return http.Response(jsonEncode({
          'generated_at': '2026-10-26T06:00:00Z',
          'filter': {
            'preset': 'custom',
            'date_from': '2026-10-01T00:00:00Z',
            'date_to': '2026-10-15T23:59:59Z',
            'interval': 'weekly',
          },
          'overview': {},
          'catalogue_summary': {},
          'order_status_distribution': [],
          'stock_request_status_distribution': [],
          'order_trends': [],
          'unsupported_metrics': [],
        }), 200);
      });

      final api = AdminReportsApi(
        client: client,
        baseUrl: 'http://test-server',
      );

      final report = await api.getReportOverview(
        preset: 'custom',
        dateFrom: DateTime(2026, 10, 1),
        dateTo: DateTime(2026, 10, 15),
        interval: 'weekly',
        token: 'test-token',
      );

      expect(report.filter.preset, equals('custom'));
      expect(report.filter.interval, equals('weekly'));
    });

    test('3. Missing or empty token throws AdminApiException(401)', () async {
      final sessionManager = AdminSessionManager.instance;
      await sessionManager.clearSession();

      final api = AdminReportsApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'http://test-server',
        sessionManager: sessionManager,
      );

      expect(
        () => api.getReportOverview(),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('4. Backend 400 Bad Request parses detail message without token leakage', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid date range: date_from must be earlier than date_to.'}),
          400,
        );
      });

      final api = AdminReportsApi(
        client: client,
        baseUrl: 'http://test-server',
      );

      try {
        await api.getReportOverview(token: 'super-secret-token-12345');
        fail('Should have thrown AdminApiException');
      } on AdminApiException catch (e) {
        expect(e.statusCode, equals(400));
        expect(e.message, contains('Invalid date range'));
        expect(e.message, isNot(contains('super-secret-token-12345')));
      }
    });

    test('5. Backend 403 Forbidden throws AdminApiException(403)', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Admin privileges required'}),
          403,
        );
      });

      final api = AdminReportsApi(
        client: client,
        baseUrl: 'http://test-server',
      );

      expect(
        () => api.getReportOverview(token: 'staff-token'),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('6. Empty results and zero counts parse cleanly without crash', () async {
      final emptyPayload = {
        'generated_at': '2026-10-26T06:00:00Z',
        'filter': {'preset': 'all_time', 'interval': 'monthly'},
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

      final client = MockClient((_) async => http.Response(jsonEncode(emptyPayload), 200));
      final api = AdminReportsApi(client: client, baseUrl: 'http://test-server');

      final report = await api.getReportOverview(token: 'token');
      expect(report.overview.totalOrders, equals(0));
      expect(report.catalogueSummary.totalProducts, equals(0));
      expect(report.orderTrends, isEmpty);
      expect(report.orderStatusDistribution, isEmpty);
    });

    test('7. Uses AdminSessionManager token when token argument is omitted', () async {
      final sessionManager = AdminSessionManager.instance;
      await sessionManager.saveSession(
        token: 'persisted-admin-session-token',
        user: mockAdminUser,
      );

      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(jsonEncode({
          'generated_at': '2026-10-26T06:00:00Z',
          'filter': {},
          'overview': {},
          'catalogue_summary': {},
          'order_status_distribution': [],
          'stock_request_status_distribution': [],
          'order_trends': [],
          'unsupported_metrics': [],
        }), 200);
      });

      final api = AdminReportsApi(
        client: client,
        baseUrl: 'http://test-server',
        sessionManager: sessionManager,
      );

      await api.getReportOverview();
      expect(capturedAuth, equals('Bearer persisted-admin-session-token'));
    });
  });
}
