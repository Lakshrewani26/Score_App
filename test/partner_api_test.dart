import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/partner_api.dart';

void main() {
  group('PartnerApi', () {
    test('sends backend mobile/password and parses an active Partner session',
        () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/partner/login');
        expect(
          jsonDecode(request.body),
          {'mobile': '9876543210', 'password': 'correct-horse'},
        );
        return http.Response(
          jsonEncode({
            'access_token': 'test-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 7,
              'name': 'Test Partner',
              'mobile': '9876543210',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-01-01T00:00:00Z',
              'partner_profile': {
                'business_name': 'Test Store',
                'business_address': 'Test Address',
                'partner_code': 'P-007',
              },
            },
          }),
          200,
        );
      });

      final api = PartnerApi(client: client, baseUrl: 'http://localhost/');
      final response = await api.login(
        mobile: ' 9876543210 ',
        password: 'correct-horse',
      );

      expect(response.accessToken, 'test-token');
      expect(response.user.id, 7);
      expect(response.user.role, 'partner');
      expect(response.user.isActive, isTrue);
      expect(response.user.businessName, 'Test Store');
    });

    test('reports backend authentication failures without a fake session',
        () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'detail': 'Invalid mobile number or password'}),
          401,
        ),
      );
      final api = PartnerApi(client: client, baseUrl: 'http://localhost');

      await expectLater(
        api.login(mobile: '9876543210', password: 'wrong'),
        throwsA(
          isA<PartnerApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                'Invalid mobile number or password',
              ),
        ),
      );
    });
  });
}
