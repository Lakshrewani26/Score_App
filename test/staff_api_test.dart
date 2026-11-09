import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';

void main() {
  const userResponse = {
    'id': 7,
    'name': 'Staff Member',
    'mobile': '9000000007',
    'role': 'staff',
    'is_active': true,
    'staff_id': 'STF-007',
    'created_at': '2025-05-20T10:00:00',
  };

  test('Staff login sends Staff ID and parses token and profile', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/staff/login');
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(requestBody, {'staff_id': 'STF-007', 'password': 'password'});
      return http.Response(
        jsonEncode({
          'access_token': 'staff-jwt',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': userResponse,
        }),
        200,
      );
    });
    final api = StaffApi(client: client, baseUrl: 'http://localhost');

    final response = await api.login(
      staffId: ' STF-007 ',
      password: 'password',
    );

    expect(response.accessToken, 'staff-jwt');
    expect(response.user.staffId, 'STF-007');
    expect(response.user.role, 'staff');
  });

  test('Staff profile and assigned Partners use the bearer token and schemas',
      () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await session.saveSession(
      token: 'staff-jwt',
      user: const StaffUser(
        id: 7,
        name: 'Staff Member',
        mobile: '9000000007',
        role: 'staff',
        isActive: true,
        staffId: 'STF-007',
      ),
    );
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer staff-jwt');
      if (request.url.path == '/api/v1/staff/me') {
        return http.Response(jsonEncode(userResponse), 200);
      }
      expect(request.url.path, '/api/v1/staff/partners');
      return http.Response(
        jsonEncode([
          {
            'id': 21,
            'name': 'Partner User',
            'mobile': '9000000021',
            'business_name': 'Partner Business',
            'business_address': 'Market Road',
            'partner_code': 'PAR-21',
          },
        ]),
        200,
      );
    });
    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    final user = await api.getMe();
    final partners = await api.getAssignedPartners();

    expect(user.id, 7);
    expect(partners, hasLength(1));
    expect(partners.single.businessName, 'Partner Business');
  });

  test('Staff API errors preserve backend validation details', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({'detail': 'Account is deactivated'}),
          403,
        ));
    final api = StaffApi(client: client, baseUrl: 'http://localhost');

    await expectLater(
      api.login(staffId: 'STF-007', password: 'password'),
      throwsA(
        isA<StaffApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
                (error) => error.message, 'message', 'Account is deactivated'),
      ),
    );
  });

  test('updateOrderStatus sends PATCH with status and remarks and parses response with status_history',
      () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await session.saveSession(
      token: 'staff-jwt',
      user: const StaffUser(
        id: 7,
        name: 'Staff Member',
        mobile: '9000000007',
        role: 'staff',
        isActive: true,
        staffId: 'STF-007',
      ),
    );

    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/staff/orders/101/status');
      expect(request.headers['authorization'], 'Bearer staff-jwt');
      expect(request.headers['content-type'], startsWith('application/json'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['status'], 'dispatched');
      expect(body['remarks'], 'Dispatched via Express');

      return http.Response(
        jsonEncode({
          'id': 101,
          'order_number': 'ORD-101',
          'partner_id': 21,
          'partner_name': 'Partner User',
          'status': 'dispatched',
          'created_at': '2025-05-20T10:00:00',
          'item_count': 2,
          'total_quantity': 4,
          'order_total': '1500.00',
          'items': [],
          'status_history': [
            {
              'id': 1,
              'order_id': 101,
              'old_status': 'pending_approval',
              'new_status': 'approved_processing',
              'remarks': 'Approved by staff',
              'changed_by': 7,
              'changed_at': '2025-05-20T10:05:00',
            },
            {
              'id': 2,
              'order_id': 101,
              'old_status': 'approved_processing',
              'new_status': 'dispatched',
              'remarks': 'Dispatched via Express',
              'changed_by': 7,
              'changed_at': '2025-05-20T11:00:00',
            },
          ],
        }),
        200,
      );
    });

    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    final updatedOrder = await api.updateOrderStatus(
      101,
      status: 'dispatched',
      remarks: 'Dispatched via Express',
    );

    expect(updatedOrder.id, 101);
    expect(updatedOrder.status, 'dispatched');
    expect(updatedOrder.statusHistory, hasLength(2));
    expect(updatedOrder.statusHistory[0].oldStatus, 'pending_approval');
    expect(updatedOrder.statusHistory[0].newStatus, 'approved_processing');
    expect(updatedOrder.statusHistory[1].oldStatus, 'approved_processing');
    expect(updatedOrder.statusHistory[1].newStatus, 'dispatched');
    expect(updatedOrder.statusHistory[1].remarks, 'Dispatched via Express');
  });

  test('updateOrderStatus throws StaffApiException on backend rejection',
      () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await session.saveSession(
      token: 'staff-jwt',
      user: const StaffUser(
        id: 7,
        name: 'Staff Member',
        mobile: '9000000007',
        role: 'staff',
        isActive: true,
        staffId: 'STF-007',
      ),
    );

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'detail': 'Invalid transition: approved_processing cannot transition to delivered',
        }),
        400,
      );
    });

    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    await expectLater(
      api.updateOrderStatus(101, status: 'delivered'),
      throwsA(
        isA<StaffApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message',
                contains('Invalid transition')),
      ),
    );
  });
}
