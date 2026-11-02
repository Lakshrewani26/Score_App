import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/customer_api.dart';
import 'package:score_app/core/services/customer_session_manager.dart';

void main() {
  group('CustomerUser & CustomerSessionManager', () {
    test('serializes and deserializes CustomerUser correctly', () {
      final json = {
        'id': 10,
        'name': 'Anita Roy',
        'mobile': '9876543210',
        'role': 'customer',
        'is_active': true,
        'customer_profile': {
          'state': 'Maharashtra',
          'city': 'Pune',
          'segment': '2-Wheeler',
        },
      };

      final user = CustomerUser.fromJson(json);
      expect(user.id, 10);
      expect(user.name, 'Anita Roy');
      expect(user.mobile, '9876543210');
      expect(user.role, 'customer');
      expect(user.isActive, isTrue);
      expect(user.state, 'Maharashtra');
      expect(user.city, 'Pune');
      expect(user.segment, '2-Wheeler');

      final serialized = user.toJson();
      expect(serialized['id'], 10);
      expect(serialized['name'], 'Anita Roy');
      expect(serialized['customer_profile']['city'], 'Pune');
    });

    test('CustomerSessionManager saves and clears customer session', () async {
      final storage = InMemoryCustomerTokenStorage();
      final manager = CustomerSessionManager(tokenStorage: storage);

      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentUser, isNull);
      expect(await manager.getToken(), isNull);

      const user = CustomerUser(
        id: 1,
        name: 'Test Customer',
        mobile: '9123456789',
        role: 'customer',
        city: 'Mumbai',
      );

      await manager.saveSession(token: 'token-abc', user: user);
      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentUser?.id, 1);
      expect(await manager.getToken(), 'token-abc');

      await manager.clearSession();
      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentUser, isNull);
      expect(await manager.getToken(), isNull);
    });
  });

  group('CustomerApi login', () {
    test('sends credentials and parses active customer auth response', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/customer/login');
        expect(
          jsonDecode(request.body),
          {'mobile': '9876543210', 'password': 'my-password'},
        );
        return http.Response(
          jsonEncode({
            'access_token': 'cust-token-123',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 5,
              'name': 'Ravi Kumar',
              'mobile': '9876543210',
              'role': 'customer',
              'is_active': true,
              'created_at': '2026-01-01T00:00:00Z',
              'customer_profile': {
                'state': 'Gujarat',
                'city': 'Surat',
                'segment': 'Both',
              },
            },
          }),
          200,
        );
      });

      final api = CustomerApi(client: client, baseUrl: 'http://localhost');
      final auth = await api.login(
        mobile: ' 9876543210 ',
        password: 'my-password',
      );

      expect(auth.accessToken, 'cust-token-123');
      expect(auth.user.id, 5);
      expect(auth.user.name, 'Ravi Kumar');
      expect(auth.user.state, 'Gujarat');
      expect(auth.user.city, 'Surat');
    });

    test('validates non-empty credentials before dispatching request', () async {
      final api = CustomerApi(baseUrl: 'http://localhost');
      await expectLater(
        api.login(mobile: '', password: 'pwd'),
        throwsA(isA<CustomerApiException>().having(
          (e) => e.message,
          'message',
          contains('required'),
        )),
      );
    });

    test('throws CustomerApiException on 401 unauthorized', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid mobile number or password'}),
          401,
        );
      });

      final api = CustomerApi(client: client, baseUrl: 'http://localhost');
      await expectLater(
        api.login(mobile: '9876543210', password: 'wrong'),
        throwsA(
          isA<CustomerApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Invalid mobile number or password'),
        ),
      );
    });
  });

  group('CustomerApi register', () {
    test('sends registration data and parses created customer auth response', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/customer/register');
        expect(
          jsonDecode(request.body),
          {
            'name': 'New Customer',
            'mobile': '9876543210',
            'password': 'secretPassword',
            'state': 'Maharashtra',
            'city': 'Pune',
            'segment': '2-Wheeler',
          },
        );
        return http.Response(
          jsonEncode({
            'access_token': 'new-cust-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 12,
              'name': 'New Customer',
              'mobile': '9876543210',
              'role': 'customer',
              'is_active': true,
              'created_at': '2026-01-01T00:00:00Z',
              'customer_profile': {
                'state': 'Maharashtra',
                'city': 'Pune',
                'segment': '2-Wheeler',
              },
            },
          }),
          201,
        );
      });

      final api = CustomerApi(client: client, baseUrl: 'http://localhost');
      final auth = await api.register(
        name: ' New Customer ',
        mobile: ' 9876543210 ',
        password: 'secretPassword',
        state: 'Maharashtra',
        city: 'Pune',
        segment: '2-Wheeler',
      );

      expect(auth.accessToken, 'new-cust-token');
      expect(auth.user.id, 12);
      expect(auth.user.name, 'New Customer');
    });

    test('validates password length before dispatching register request', () async {
      final api = CustomerApi(baseUrl: 'http://localhost');
      await expectLater(
        api.register(
          name: 'Name',
          mobile: '9876543210',
          password: '123',
        ),
        throwsA(isA<CustomerApiException>().having(
          (e) => e.message,
          'message',
          contains('at least 6 characters'),
        )),
      );
    });

    test('throws CustomerApiException on 409 conflict', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'A user with this mobile number already exists'}),
          409,
        );
      });

      final api = CustomerApi(client: client, baseUrl: 'http://localhost');
      await expectLater(
        api.register(
          name: 'Duplicate',
          mobile: '9876543210',
          password: 'password123',
        ),
        throwsA(
          isA<CustomerApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', contains('already exists')),
        ),
      );
    });
  });

  group('CustomerApi getMe', () {
    test('fetches profile with bearer token', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/auth/customer/me');
        expect(request.headers['Authorization'], 'Bearer my-token');
        return http.Response(
          jsonEncode({
            'id': 15,
            'name': 'Me Profile',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'customer_profile': {
              'state': 'Delhi',
              'city': 'New Delhi',
              'segment': '3-Wheeler',
            },
          }),
          200,
        );
      });

      final api = CustomerApi(client: client, baseUrl: 'http://localhost');
      final user = await api.getMe(token: 'my-token');

      expect(user.id, 15);
      expect(user.name, 'Me Profile');
      expect(user.city, 'New Delhi');
    });
  });
}
