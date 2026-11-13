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

  test('getBalance sends GET /api/v1/staff/balance and parses StaffBalance',
      () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await session.saveSession(
      token: 'staff-jwt-token',
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
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/staff/balance');
      expect(request.headers['authorization'], 'Bearer staff-jwt-token');
      expect(request.headers['accept'], 'application/json');
      return http.Response(
        jsonEncode({
          'points_earned': 350,
          'points_spent': 0,
          'current_balance': 350,
          'total_earned_points': 350,
          'total_spent_points': 0,
          'remaining_balance': 350,
        }),
        200,
      );
    });

    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    final balance = await api.getBalance();

    expect(balance.pointsEarned, 350);
    expect(balance.pointsSpent, 0);
    expect(balance.currentBalance, 350);
  });

  test('getPointsHistory sends GET /api/v1/staff/points-history and parses response',
      () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await session.saveSession(
      token: 'staff-jwt-token',
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
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/staff/points-history');
      expect(request.url.queryParameters['page'], '2');
      expect(request.url.queryParameters['page_size'], '10');
      expect(request.headers['authorization'], 'Bearer staff-jwt-token');
      expect(request.headers['accept'], 'application/json');

      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'tr-42',
              'transaction_type': 'transfer_received',
              'direction': 'credit',
              'points': 100,
              'amount': 100,
              'title': 'Points Received from Apex Motors',
              'description': 'Loyalty transfer from partner',
              'reference_id': 'tx-idem-42',
              'sender_name': 'Apex Motors',
              'created_at': '2026-11-10T12:00:00Z',
            },
          ],
          'total': 15,
          'page': 2,
          'page_size': 10,
          'total_pages': 2,
          'has_next': false,
          'has_prev': true,
        }),
        200,
      );
    });

    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    final response = await api.getPointsHistory(page: 2, pageSize: 10);

    expect(response.total, 15);
    expect(response.page, 2);
    expect(response.pageSize, 10);
    expect(response.totalPages, 2);
    expect(response.hasNext, isFalse);
    expect(response.hasPrev, isTrue);
    expect(response.items, hasLength(1));

    final item = response.items.first;
    expect(item.id, 'tr-42');
    expect(item.isCredit, isTrue);
    expect(item.isDebit, isFalse);
    expect(item.points, 100);
    expect(item.amount, 100);
    expect(item.title, 'Points Received from Apex Motors');
    expect(item.description, 'Loyalty transfer from partner');
    expect(item.referenceId, 'tx-idem-42');
    expect(item.senderName, 'Apex Motors');
  });

  test('getBalance throws StaffApiException when unauthenticated', () async {
    final session = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    // No session saved
    final client = MockClient((_) async => http.Response('{}', 200));
    final api = StaffApi(
      client: client,
      baseUrl: 'http://localhost/',
      sessionManager: session,
    );

    await expectLater(
      api.getBalance(),
      throwsA(
        isA<StaffApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('token')),
      ),
    );
  });

  group('Staff Payments API Tests', () {
    const paymentJson = {
      'id': 101,
      'staff_id': 7,
      'partner_id': 21,
      'partner_name': 'Rahul Sharma',
      'business_name': 'Sharma Auto Parts',
      'partner_mobile': '+919876543210',
      'amount': '4500.00',
      'payment_method': 'upi',
      'reference_number': 'UPI-REF-9921',
      'status': 'recorded',
      'recorded_by': 7,
      'recorded_by_name': 'Staff Member',
      'recorded_at': '2026-11-13T10:00:00Z',
      'notes': 'Advance payment for order',
      'latest_review': null,
      'status_history': <dynamic>[],
    };

    test('getPayments sends auth headers, query params and parses list response',
        () async {
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-jwt-token',
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
        expect(request.method, 'GET');
        expect(request.headers['authorization'], 'Bearer staff-jwt-token');
        expect(request.url.path, '/api/v1/staff/payments');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['page_size'], '10');
        expect(request.url.queryParameters['status'], 'recorded');
        expect(request.url.queryParameters['search'], 'Sharma');

        return http.Response(
          jsonEncode({
            'items': [paymentJson],
            'total': 1,
            'page': 1,
            'page_size': 10,
            'total_pages': 1,
            'has_next': false,
            'has_prev': false,
          }),
          200,
        );
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      final response = await api.getPayments(
        page: 1,
        pageSize: 10,
        status: 'recorded',
        search: 'Sharma',
      );

      expect(response.total, 1);
      expect(response.items, hasLength(1));
      final item = response.items.first;
      expect(item.id, 101);
      expect(item.amount, 4500.00);
      expect(item.paymentMethod, 'upi');
      expect(item.displayDealerName, 'Sharma Auto Parts');
      expect(item.displayReference, 'UPI-REF-9921');
      expect(item.isRecorded, isTrue);
      expect(item.isApproved, isFalse);
    });

    test('getPayment parses single payment record detail', () async {
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-jwt-token',
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
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/staff/payments/101');
        return http.Response(jsonEncode(paymentJson), 200);
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      final item = await api.getPayment(101);
      expect(item.id, 101);
      expect(item.referenceNumber, 'UPI-REF-9921');
      expect(item.partnerMobile, '+919876543210');
    });

    test('approvePayment sends POST with optional remarks and parses approved payment',
        () async {
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-jwt-token',
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
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/staff/payments/101/approve');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['remarks'], 'Payment confirmed');

        final approved = Map<String, dynamic>.from(paymentJson);
        approved['status'] = 'approved';
        approved['latest_review'] = {
          'changed_by': 7,
          'changed_by_name': 'Staff Member',
          'changed_at': '2026-11-13T10:30:00Z',
          'old_status': 'recorded',
          'new_status': 'approved',
          'remarks': 'Payment confirmed',
        };
        return http.Response(jsonEncode(approved), 200);
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      final result = await api.approvePayment(101, remarks: 'Payment confirmed');
      expect(result.status, 'approved');
      expect(result.isApproved, isTrue);
      expect(result.latestReview?.remarks, 'Payment confirmed');
    });

    test('rejectPayment requires non-empty reason and sends POST', () async {
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-jwt-token',
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
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/staff/payments/101/reject');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['reason'], 'Invalid reference number');

        final rejected = Map<String, dynamic>.from(paymentJson);
        rejected['status'] = 'rejected';
        rejected['latest_review'] = {
          'changed_by': 7,
          'changed_by_name': 'Staff Member',
          'changed_at': '2026-11-13T10:35:00Z',
          'old_status': 'recorded',
          'new_status': 'rejected',
          'remarks': 'Invalid reference number',
        };
        return http.Response(jsonEncode(rejected), 200);
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      // Throws without network call if reason is empty
      await expectLater(
        api.rejectPayment(101, reason: '   '),
        throwsA(
          isA<StaffApiException>().having(
            (e) => e.message,
            'message',
            contains('required'),
          ),
        ),
      );

      // Successfully rejects with valid reason
      final result = await api.rejectPayment(101, reason: 'Invalid reference number');
      expect(result.status, 'rejected');
      expect(result.isRejected, isTrue);
      expect(result.latestReview?.remarks, 'Invalid reference number');
    });

    test('payment api handles error responses and formats StaffApiException',
        () async {
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'staff-jwt-token',
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
        if (request.url.path.contains('/approve')) {
          return http.Response(
            jsonEncode({'detail': 'Payment in approved status cannot be transitioned'}),
            400,
          );
        }
        return http.Response(
          jsonEncode({'detail': 'Access denied: You are not assigned to this payment'}),
          403,
        );
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      await expectLater(
        api.getPayment(999),
        throwsA(
          isA<StaffApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', contains('Access denied')),
        ),
      );

      await expectLater(
        api.approvePayment(999),
        throwsA(
          isA<StaffApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', contains('cannot be transitioned')),
        ),
      );
    });
  });
}
