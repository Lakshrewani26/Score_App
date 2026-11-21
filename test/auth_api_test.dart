import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/auth_api.dart';

void main() {
  group('AuthApi Unit Tests', () {
    test('Throws AuthApiException when mobile or password is empty', () async {
      final api = AuthApi(baseUrl: 'http://localhost:8000');
      expect(
        () => api.login(mobile: '', password: 'password'),
        throwsA(isA<AuthApiException>()),
      );
      expect(
        () => api.login(mobile: '9876543210', password: ''),
        throwsA(isA<AuthApiException>()),
      );
    });

    test('Successful login sends POST request and parses UnifiedAuthResponse',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['mobile'], '9876543210');
        expect(body['password'], 'secret123');

        return http.Response(
          jsonEncode({
            'access_token': 'jwt.token.here',
            'token_type': 'bearer',
            'expires_in': 1800,
            'user_id': 42,
            'id': 42,
            'name': 'Score Customer',
            'mobile': '9876543210',
            'role': 'customer',
            'is_active': true,
            'customer_profile': {
              'state': 'Maharashtra',
              'city': 'Mumbai',
              'segment': '2-Wheeler',
            },
            'user': {
              'id': 42,
              'name': 'Score Customer',
              'mobile': '9876543210',
              'role': 'customer',
              'is_active': true,
              'customer_profile': {
                'state': 'Maharashtra',
                'city': 'Mumbai',
                'segment': '2-Wheeler',
              },
            },
          }),
          200,
        );
      });

      final api = AuthApi(client: mockClient, baseUrl: 'http://localhost:8000');
      final res = await api.login(mobile: '9876543210', password: 'secret123');

      expect(res.accessToken, 'jwt.token.here');
      expect(res.tokenType, 'bearer');
      expect(res.expiresIn, 1800);
      expect(res.userId, 42);
      expect(res.name, 'Score Customer');
      expect(res.mobile, '9876543210');
      expect(res.role, 'customer');
      expect(res.isActive, isTrue);
      expect(res.customerProfile?['city'], 'Mumbai');
    });

    test('Parses backend error message on 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Invalid mobile number or password'}),
          401,
        );
      });

      final api = AuthApi(client: mockClient, baseUrl: 'http://localhost:8000');
      expect(
        () => api.login(mobile: '9876543210', password: 'wrong'),
        throwsA(
          predicate(
            (e) =>
                e is AuthApiException &&
                e.message == 'Invalid mobile number or password' &&
                e.statusCode == 401,
          ),
        ),
      );
    });

    test('Parses validation error list message on 422', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': [
              {'msg': 'Mobile number cannot be empty'}
            ]
          }),
          422,
        );
      });

      final api = AuthApi(client: mockClient, baseUrl: 'http://localhost:8000');
      expect(
        () => api.login(mobile: '9876543210', password: 'pass'),
        throwsA(
          predicate(
            (e) =>
                e is AuthApiException &&
                e.message == 'Mobile number cannot be empty' &&
                e.statusCode == 422,
          ),
        ),
      );
    });
  });
}
