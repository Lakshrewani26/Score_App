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
}
