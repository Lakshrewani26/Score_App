import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  group('AdminSessionManager and InMemoryAdminTokenStorage Tests', () {
    test('starts unauthenticated with null token and user', () async {
      final storage = InMemoryAdminTokenStorage();
      final session = AdminSessionManager(tokenStorage: storage);

      expect(session.isAuthenticated, isFalse);
      expect(session.currentUser, isNull);
      expect(await session.getToken(), isNull);
    });

    test('saves and clears session correctly in memory', () async {
      final storage = InMemoryAdminTokenStorage();
      final session = AdminSessionManager(tokenStorage: storage);

      const user = AdminUser(
        id: 1,
        name: 'Super Admin',
        mobile: '9876543210',
        role: 'admin',
        isActive: true,
      );

      await session.saveSession(token: 'jwt_test_token_123', user: user);

      expect(session.isAuthenticated, isTrue);
      expect(session.currentUser?.name, 'Super Admin');
      expect(session.currentUser?.id, 1);
      expect(await session.getToken(), 'jwt_test_token_123');

      await session.clearSession();

      expect(session.isAuthenticated, isFalse);
      expect(session.currentUser, isNull);
      expect(await session.getToken(), isNull);
    });
  });

  group('AdminApi Tests', () {
    const validLoginResponseJson = {
      'access_token': 'test_admin_jwt_token',
      'token_type': 'bearer',
      'expires_in': 86400,
      'user': {
        'id': 1,
        'name': 'Score Admin',
        'mobile': '9876543210',
        'role': 'admin',
        'is_active': true,
        'created_at': '2026-10-25T18:50:00',
      },
    };

    const validMeResponseJson = {
      'id': 1,
      'name': 'Score Admin',
      'mobile': '9876543210',
      'role': 'admin',
      'is_active': true,
      'created_at': '2026-10-25T18:50:00',
    };

    test('login successfully sends mobile/password and parses TokenResponse', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/admin/login');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['mobile'], '9876543210');
        expect(body['password'], 'Admin@123');

        return http.Response(jsonEncode(validLoginResponseJson), 200);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');
      final result = await api.login(mobile: ' 9876543210 ', password: 'Admin@123');

      expect(result.accessToken, 'test_admin_jwt_token');
      expect(result.tokenType, 'bearer');
      expect(result.expiresIn, 86400);
      expect(result.user.id, 1);
      expect(result.user.name, 'Score Admin');
      expect(result.user.role, 'admin');
      expect(result.user.isActive, isTrue);
    });

    test('login throws validation error on empty fields before making request', () async {
      final client = MockClient((request) async {
        fail('Should not make HTTP request with empty fields');
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '', password: '123'),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );

      expect(
        () => api.login(mobile: '9876543210', password: ''),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('login throws AdminApiException on 401 Unauthorized invalid credentials', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid mobile number or password'}),
          401,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'WrongPassword'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Invalid mobile number or password'),
        ),
      );
    });

    test('login throws AdminApiException on 403 Forbidden deactivated account', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Account is deactivated'}),
          403,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Account is deactivated'),
        ),
      );
    });

    test('login throws AdminApiException on 403 Forbidden non-admin account', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Access denied: Admin privileges required'}),
          403,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Access denied: Admin privileges required'),
        ),
      );
    });

    test('login throws AdminApiException on 500 server error', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'Server error. Please try again later.'),
        ),
      );
    });

    test('login throws AdminApiException on malformed response body', () async {
      final client = MockClient((request) async {
        return http.Response('not valid json', 200);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having((e) => e.message, 'message', 'Invalid response received from server'),
        ),
      );
    });

    test('login throws AdminApiException on network failure', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Failed host lookup');
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.message, 'message', contains('Network error')),
        ),
      );
    });

    test('login throws AdminApiException on timeout', () async {
      final client = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.login(mobile: '9876543210', password: 'Password123'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 0)
              .having((e) => e.message, 'message', contains('timed out')),
        ),
      );
    });

    test('getMe verifies profile using Authorization Bearer header', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/me');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test_token_xyz');

        return http.Response(jsonEncode(validMeResponseJson), 200);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');
      final user = await api.getMe(token: 'test_token_xyz');

      expect(user.id, 1);
      expect(user.name, 'Score Admin');
      expect(user.mobile, '9876543210');
      expect(user.role, 'admin');
      expect(user.isActive, isTrue);
    });

    test('getMe uses token from session manager if not passed explicitly', () async {
      final storage = InMemoryAdminTokenStorage();
      await storage.saveToken('token_from_session');
      final session = AdminSessionManager(tokenStorage: storage);

      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token_from_session');
        return http.Response(jsonEncode(validMeResponseJson), 200);
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: session);
      final user = await api.getMe();

      expect(user.name, 'Score Admin');
    });

    test('getMe throws AdminApiException 401 when no token is present', () async {
      final storage = InMemoryAdminTokenStorage();
      final session = AdminSessionManager(tokenStorage: storage);

      final client = MockClient((request) async {
        fail('Should not send request when no token');
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: session);

      expect(
        () => api.getMe(),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('getMe throws AdminApiException 401 on expired or invalid token', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Token has expired'}),
          401,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.getMe(token: 'expired_token'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Token has expired'),
        ),
      );
    });

    test('getMe throws AdminApiException 403 when user is not admin or inactive', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Admin privileges required'}),
          403,
        );
      });

      final api = AdminApi(client: client, baseUrl: 'http://localhost');

      expect(
        () => api.getMe(token: 'non_admin_token'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message', 'Admin privileges required'),
        ),
      );
    });

    group('getUsers Tests', () {
      final validUsersPageJson = {
        'items': [
          {
            'id': 1,
            'name': 'Partner One',
            'mobile': '9800000001',
            'role': 'partner',
            'is_active': true,
            'created_at': '2026-10-25T12:00:00',
            'business_name': 'Score Motors',
            'partner_code': 'P001',
            'staff_id': null,
          },
          {
            'id': 2,
            'name': 'Staff Two',
            'mobile': '9800000002',
            'role': 'staff',
            'is_active': false,
            'created_at': '2026-10-25T13:00:00',
            'business_name': null,
            'partner_code': null,
            'staff_id': 'STF001',
          },
        ],
        'total': 2,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };

      test('fetches paginated users and serializes query parameters correctly', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/users');
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer valid_token');
          expect(request.url.queryParameters['role'], 'partner');
          expect(request.url.queryParameters['search'], 'Score');
          expect(request.url.queryParameters['is_active'], 'true');
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['page_size'], '10');

          return http.Response(jsonEncode(validUsersPageJson), 200);
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        final page = await api.getUsers(
          role: 'partner',
          search: 'Score',
          isActive: true,
          page: 2,
          pageSize: 10,
          token: 'valid_token',
        );

        expect(page.total, 2);
        expect(page.page, 1);
        expect(page.totalPages, 1);
        expect(page.items.length, 2);

        final p1 = page.items[0];
        expect(p1.id, 1);
        expect(p1.name, 'Partner One');
        expect(p1.mobile, '9800000001');
        expect(p1.role, 'partner');
        expect(p1.isActive, isTrue);
        expect(p1.businessName, 'Score Motors');
        expect(p1.partnerCode, 'P001');

        final s1 = page.items[1];
        expect(s1.id, 2);
        expect(s1.name, 'Staff Two');
        expect(s1.role, 'staff');
        expect(s1.isActive, isFalse);
        expect(s1.staffId, 'STF001');
      });

      test('throws AdminApiException 401 when no token is present', () async {
        final storage = InMemoryAdminTokenStorage();
        final session = AdminSessionManager(tokenStorage: storage);
        final api = AdminApi(baseUrl: 'http://localhost', sessionManager: session);

        expect(
          () => api.getUsers(),
          throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 401)),
        );
      });

      test('throws AdminApiException 403 on non-admin token', () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'detail': 'Admin privileges required'}), 403);
        });
        final api = AdminApi(client: client, baseUrl: 'http://localhost');

        expect(
          () => api.getUsers(token: 'non_admin_token'),
          throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 403)),
        );
      });
    });

    group('getUserDetail Tests', () {
      test('fetches full user detail with role-specific profile', () async {
        final detailJson = {
          'id': 10,
          'name': 'Partner Alpha',
          'mobile': '9877777777',
          'role': 'partner',
          'is_active': true,
          'created_at': '2026-10-25T10:00:00',
          'business_name': 'Alpha Auto',
          'partner_code': 'ALPH01',
          'customer_profile': null,
          'partner_profile': {
            'business_name': 'Alpha Auto',
            'business_address': '123 Tech Park, Bangalore',
            'partner_code': 'ALPH01',
          },
          'staff_profile': null,
        };

        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/users/10');
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer admin_token');
          return http.Response(jsonEncode(detailJson), 200);
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        final detail = await api.getUserDetail(userId: 10, token: 'admin_token');

        expect(detail.id, 10);
        expect(detail.name, 'Partner Alpha');
        expect(detail.partnerProfile?.businessName, 'Alpha Auto');
        expect(detail.partnerProfile?.businessAddress, '123 Tech Park, Bangalore');
        expect(detail.partnerProfile?.partnerCode, 'ALPH01');
      });

      test('throws AdminApiException 404 when user not found', () async {
        final client = MockClient((request) async {
          return http.Response(jsonEncode({'detail': 'User not found'}), 404);
        });
        final api = AdminApi(client: client, baseUrl: 'http://localhost');

        expect(
          () => api.getUserDetail(userId: 999, token: 'admin_token'),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.message, 'message', 'User not found'),
          ),
        );
      });
    });

    group('createPartner Tests', () {
      test('successfully creates a partner user and profile', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/users/partners');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'New Partner');
          expect(body['mobile'], '9800000010');
          expect(body['password'], 'SecurePass@123');
          expect(body['business_name'], 'Partner Corp');
          expect(body['business_address'], '456 MG Road');
          expect(body['partner_code'], 'PC123');

          return http.Response(
            jsonEncode({
              'id': 15,
              'name': 'New Partner',
              'mobile': '9800000010',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-10-25T14:00:00',
              'business_name': 'Partner Corp',
              'partner_code': 'PC123',
              'partner_profile': {
                'business_name': 'Partner Corp',
                'business_address': '456 MG Road',
                'partner_code': 'PC123',
              },
            }),
            201,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        final created = await api.createPartner(
          payload: const CreatePartnerPayload(
            name: 'New Partner',
            mobile: '9800000010',
            password: 'SecurePass@123',
            businessName: 'Partner Corp',
            businessAddress: '456 MG Road',
            partnerCode: 'PC123',
          ),
          token: 'admin_token',
        );

        expect(created.id, 15);
        expect(created.name, 'New Partner');
        expect(created.role, 'partner');
        expect(created.partnerProfile?.partnerCode, 'PC123');
      });

      test('throws AdminApiException 409 on duplicate mobile number', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'A user with this mobile number already exists'}),
            409,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.createPartner(
            payload: const CreatePartnerPayload(
              name: 'Duplicate',
              mobile: '9800000010',
              password: 'pass',
              businessName: 'Biz',
              businessAddress: 'Addr',
            ),
            token: 'admin_token',
          ),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.message, 'message', 'A user with this mobile number already exists'),
          ),
        );
      });

      test('throws AdminApiException 409 on duplicate partner code', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'A partner with this partner code already exists'}),
            409,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.createPartner(
            payload: const CreatePartnerPayload(
              name: 'Duplicate Code',
              mobile: '9800000099',
              password: 'pass',
              businessName: 'Biz',
              businessAddress: 'Addr',
              partnerCode: 'EXISTING_CODE',
            ),
            token: 'admin_token',
          ),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.message, 'message', 'A partner with this partner code already exists'),
          ),
        );
      });
    });

    group('createStaff Tests', () {
      test('successfully creates a staff user and profile', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/users/staff');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'New Staff');
          expect(body['mobile'], '9800000020');
          expect(body['password'], 'StaffPass@123');
          expect(body['staff_id'], 'EMP999');

          return http.Response(
            jsonEncode({
              'id': 16,
              'name': 'New Staff',
              'mobile': '9800000020',
              'role': 'staff',
              'is_active': true,
              'created_at': '2026-10-25T14:30:00',
              'staff_id': 'EMP999',
              'staff_profile': {
                'staff_id': 'EMP999',
              },
            }),
            201,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        final created = await api.createStaff(
          payload: const CreateStaffPayload(
            name: 'New Staff',
            mobile: '9800000020',
            password: 'StaffPass@123',
            staffId: 'EMP999',
          ),
          token: 'admin_token',
        );

        expect(created.id, 16);
        expect(created.name, 'New Staff');
        expect(created.role, 'staff');
        expect(created.staffProfile?.staffId, 'EMP999');
      });

      test('throws AdminApiException 409 on duplicate staff ID', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'A staff member with this staff ID already exists'}),
            409,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.createStaff(
            payload: const CreateStaffPayload(
              name: 'Duplicate Staff',
              mobile: '9800000021',
              password: 'pass',
              staffId: 'EMP_EXISTS',
            ),
            token: 'admin_token',
          ),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.message, 'message', 'A staff member with this staff ID already exists'),
          ),
        );
      });
    });

    group('updateUserStatus Tests', () {
      test('successfully updates user status to active or inactive', () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/users/5/status');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['is_active'], false);

          return http.Response(
            jsonEncode({
              'id': 5,
              'name': 'Target User',
              'mobile': '9800000005',
              'role': 'partner',
              'is_active': false,
              'created_at': '2026-10-25T11:00:00',
              'business_name': 'Target Auto',
            }),
            200,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        final updated = await api.updateUserStatus(userId: 5, isActive: false, token: 'admin_token');

        expect(updated.id, 5);
        expect(updated.isActive, isFalse);
      });

      test('throws AdminApiException 400 on self-deactivation safeguard', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Cannot deactivate your own admin account'}),
            400,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.updateUserStatus(userId: 1, isActive: false, token: 'admin_token'),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.message, 'message', 'Cannot deactivate your own admin account'),
          ),
        );
      });

      test('throws AdminApiException 400 on last-active-admin safeguard', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Cannot deactivate the last active admin account'}),
            400,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.updateUserStatus(userId: 2, isActive: false, token: 'admin_token'),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having((e) => e.message, 'message', 'Cannot deactivate the last active admin account'),
          ),
        );
      });

      test('throws AdminApiException 404 when target user is not found', () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'User not found'}),
            404,
          );
        });

        final api = AdminApi(client: client, baseUrl: 'http://localhost');
        expect(
          () => api.updateUserStatus(userId: 999, isActive: true, token: 'admin_token'),
          throwsA(
            isA<AdminApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.message, 'message', 'User not found'),
          ),
        );
      });
    });
  });
}
