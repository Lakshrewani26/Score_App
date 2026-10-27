import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/models/admin_order_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_orders_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  group('AdminOrderModels Unit Tests', () {
    test('AdminOrderSummary parses JSON correctly with nullable price', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-999',
        'partner_id': 5,
        'partner_name': 'Test Partner',
        'business_name': 'Test Enterprises',
        'partner_mobile': '9876543210',
        'status': 'approved_processing',
        'notes': 'Urgent requirement',
        'created_at': '2026-10-25T14:30:00Z',
        'approved_by': 2,
        'approved_by_name': 'Staff John',
        'approved_at': '2026-10-25T15:00:00Z',
        'item_count': 3,
        'total_quantity': 15,
        'order_total': '12500.50',
      };

      final order = AdminOrderSummary.fromJson(json);
      expect(order.id, 101);
      expect(order.orderNumber, 'ORD-999');
      expect(order.partnerName, 'Test Partner');
      expect(order.businessName, 'Test Enterprises');
      expect(order.displayStatus, 'Processing');
      expect(order.canDispatch, isTrue);
      expect(order.canDeliver, isFalse);
      expect(order.itemCount, 3);
      expect(order.totalQuantity, 15);
      expect(order.displayOrderTotal, '₹12,500.50');
    });

    test('AdminOrderSummary handles null order_total without converting to 0', () {
      final json = {
        'id': 102,
        'order_number': 'ORD-1000',
        'partner_id': 6,
        'partner_name': 'Sample Partner',
        'partner_mobile': '9876543211',
        'status': 'pending_approval',
        'created_at': '2026-10-25T14:30:00Z',
        'item_count': 1,
        'total_quantity': 5,
        'order_total': null,
      };

      final order = AdminOrderSummary.fromJson(json);
      expect(order.orderTotal, isNull);
      expect(order.displayOrderTotal, 'Price not set');
      expect(order.displayStatus, 'Pending Approval');
      expect(order.canDispatch, isFalse);
      expect(order.canDeliver, isFalse);
    });

    test('AdminOrderDetail parses items and status history', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-999',
        'partner_id': 5,
        'partner_name': 'Test Partner',
        'partner_mobile': '9876543210',
        'status': 'dispatched',
        'created_at': '2026-10-25T14:30:00Z',
        'item_count': 1,
        'total_quantity': 10,
        'order_total': '4500.00',
        'items': [
          {
            'id': 1,
            'product_id': 20,
            'product_code': 'BRK-001',
            'product_name': 'Brake Pad',
            'vehicle_type': '2-Wheeler',
            'quantity': 10,
            'unit_price': '450.00',
            'subtotal': '4500.00',
          }
        ],
        'status_history': [
          {
            'id': 1,
            'old_status': 'approved_processing',
            'new_status': 'dispatched',
            'changed_by': 1,
            'changed_by_name': 'Admin User',
            'changed_at': '2026-10-25T16:00:00Z',
            'remarks': 'Shipped via courier',
          }
        ],
      };

      final detail = AdminOrderDetail.fromJson(json);
      expect(detail.canDispatch, isFalse);
      expect(detail.canDeliver, isTrue);
      expect(detail.items.length, 1);
      expect(detail.items.first.productCode, 'BRK-001');
      expect(detail.items.first.displayUnitPrice, '₹450.00');
      expect(detail.items.first.displaySubtotal, '₹4,500.00');
      expect(detail.statusHistory.length, 1);
      expect(detail.statusHistory.first.displayNewStatus, 'Dispatched');
      expect(detail.statusHistory.first.changedByName, 'Admin User');
    });

    test('AdminStockRequestSummary and Detail parse correctly', () {
      final json = {
        'id': 201,
        'request_number': 'REQ-101',
        'partner_id': 5,
        'partner_name': 'Test Partner',
        'business_name': 'Test Enterprises',
        'partner_mobile': '9876543210',
        'status': 'pending_approval',
        'notes': 'Buffer stock',
        'created_at': '2026-10-25T10:00:00Z',
        'item_count': 1,
        'total_quantity': 25,
        'items': [
          {
            'id': 1,
            'product_id': 30,
            'product_code': 'ENG-001',
            'product_name': 'Engine Oil',
            'vehicle_type': 'Both',
            'quantity': 25,
          }
        ],
        'status_history': [],
      };

      final detail = AdminStockRequestDetail.fromJson(json);
      expect(detail.requestNumber, 'REQ-101');
      expect(detail.displayStatus, 'Pending Approval');
      expect(detail.items.length, 1);
      expect(detail.items.first.productCode, 'ENG-001');
      expect(detail.items.first.quantity, 25);
    });
  });

  group('AdminOrdersApi HTTP Tests', () {
    late AdminSessionManager sessionManager;

    setUp(() async {
      sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
        token: 'test-admin-jwt-token',
        user: const AdminUser(
          id: 1,
          name: 'Super Admin',
          mobile: '9876543210',
          role: 'admin',
          isActive: true,
        ),
      );
    });

    test('getOrders serializes query parameters and parses PaginatedOrdersResponse', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/orders');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['page_size'], '15');
        expect(request.url.queryParameters['search'], 'Delhi');
        expect(request.url.queryParameters['status'], 'approved_processing');
        expect(request.url.queryParameters['vehicle_type'], '2-Wheeler');
        expect(request.headers['Authorization'], 'Bearer test-admin-jwt-token');

        final responseBody = {
          'items': [
            {
              'id': 1,
              'order_number': 'ORD-001',
              'partner_id': 2,
              'partner_name': 'Delhi Spares',
              'business_name': 'Delhi Spares Pvt Ltd',
              'partner_mobile': '9876543211',
              'status': 'approved_processing',
              'created_at': '2026-10-25T12:00:00Z',
              'item_count': 2,
              'total_quantity': 10,
              'order_total': '5000.00',
            }
          ],
          'total': 1,
          'page': 2,
          'page_size': 15,
          'total_pages': 1,
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {'content-type': 'application/json'});
      });

      final api = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      final res = await api.getOrders(
        page: 2,
        pageSize: 15,
        search: 'Delhi',
        status: 'approved_processing',
        vehicleType: '2-Wheeler',
      );

      expect(res.total, 1);
      expect(res.items.length, 1);
      expect(res.items.first.orderNumber, 'ORD-001');
    });

    test('getOrderDetail fetches single order details', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/orders/42');
        expect(request.headers['Authorization'], 'Bearer test-admin-jwt-token');

        final responseBody = {
          'id': 42,
          'order_number': 'ORD-042',
          'partner_id': 3,
          'partner_name': 'Partner X',
          'partner_mobile': '9876543212',
          'status': 'approved_processing',
          'created_at': '2026-10-25T12:00:00Z',
          'item_count': 1,
          'total_quantity': 4,
          'order_total': '1600.00',
          'items': [],
          'status_history': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {'content-type': 'application/json'});
      });

      final api = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      final detail = await api.getOrderDetail(42);
      expect(detail.id, 42);
      expect(detail.orderNumber, 'ORD-042');
    });

    test('updateOrderStatus sends PATCH with status and remarks', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/admin/orders/42/status');
        expect(request.headers['Authorization'], 'Bearer test-admin-jwt-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'dispatched');
        expect(body['remarks'], 'Dispatched via DTDC');

        final responseBody = {
          'id': 42,
          'order_number': 'ORD-042',
          'partner_id': 3,
          'partner_name': 'Partner X',
          'partner_mobile': '9876543212',
          'status': 'dispatched',
          'created_at': '2026-10-25T12:00:00Z',
          'item_count': 1,
          'total_quantity': 4,
          'order_total': '1600.00',
          'items': [],
          'status_history': [],
        };
        return http.Response(jsonEncode(responseBody), 200, headers: {'content-type': 'application/json'});
      });

      final api = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      final updated = await api.updateOrderStatus(
        42,
        status: 'dispatched',
        remarks: 'Dispatched via DTDC',
      );
      expect(updated.status, 'dispatched');
    });

    test('updateOrderStatus converts 400 error to AdminApiException with backend detail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Order is pending Staff approval. Admin cannot bypass initial approval.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      expect(
        () => api.updateOrderStatus(1, status: 'dispatched'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', contains('pending Staff approval')),
        ),
      );
    });

    test('getStockRequests and getStockRequestDetail work properly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/stock-requests') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 50,
                  'request_number': 'REQ-050',
                  'partner_id': 4,
                  'partner_name': 'Partner Y',
                  'partner_mobile': '9876543213',
                  'status': 'pending_approval',
                  'created_at': '2026-10-25T11:00:00Z',
                  'item_count': 1,
                  'total_quantity': 30,
                }
              ],
              'total': 1,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/v1/admin/stock-requests/50') {
          return http.Response(
            jsonEncode({
              'id': 50,
              'request_number': 'REQ-050',
              'partner_id': 4,
              'partner_name': 'Partner Y',
              'partner_mobile': '9876543213',
              'status': 'pending_approval',
              'created_at': '2026-10-25T11:00:00Z',
              'item_count': 1,
              'total_quantity': 30,
              'items': [],
              'status_history': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = AdminOrdersApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      final list = await api.getStockRequests();
      expect(list.total, 1);
      expect(list.items.first.requestNumber, 'REQ-050');

      final detail = await api.getStockRequestDetail(50);
      expect(detail.id, 50);
    });

    test('Missing session token throws AdminApiException 401', () async {
      final emptySession = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      final api = AdminOrdersApi(
        baseUrl: 'http://test.local',
        sessionManager: emptySession,
      );

      expect(
        () => api.getOrders(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('No authentication token provided')),
        ),
      );
    });
  });
}
