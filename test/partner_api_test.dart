import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/partner_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';

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

    group('resolveStaffQr', () {
      test('successfully resolves valid Staff QR token', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt-token',
          user: const PartnerUser(
            id: 1,
            name: 'Apex Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/staff/qr/resolve');
          expect(request.headers['Authorization'], 'Bearer partner-jwt-token');
          final body = jsonDecode(request.body);
          expect(body['token'], 'STAFF_TRF_TOKEN_001');

          return http.Response(
            jsonEncode({
              'staff_user_id': 10,
              'staff_name': 'Rajesh Kumar Staff',
              'staff_id': 'STF-001',
              'qr_code_id': 50,
              'qr_type': 'staff',
            }),
            200,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        final recipient =
            await api.resolveStaffQr(codeData: 'STAFF_TRF_TOKEN_001');

        expect(recipient.staffUserId, 10);
        expect(recipient.staffName, 'Rajesh Kumar Staff');
        expect(recipient.staffId, 'STF-001');
        expect(recipient.qrCodeId, 50);
        expect(recipient.qrType, 'staff');
      });

      test('handles 400 for inappropriate QR code type (product QR)', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'detail':
                  "Inappropriate QR code type: 'product' QR codes cannot be resolved as Staff recipients."
            }),
            400,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        await expectLater(
          api.resolveStaffQr(codeData: 'PRODUCT_TOKEN_123'),
          throwsA(
            isA<PartnerApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Inappropriate QR code type'),
                ),
          ),
        );
      });

      test('handles 404 for unassigned or invalid Staff QR token', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Staff QR code token not found.'}),
            404,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        await expectLater(
          api.resolveStaffQr(codeData: 'NON_EXISTENT_QR'),
          throwsA(
            isA<PartnerApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.message,
                  'message',
                  'Staff QR code token not found.',
                ),
          ),
        );
      });

      test('rejects empty QR payload before sending HTTP request', () async {
        final api = PartnerApi(baseUrl: 'http://localhost');
        await expectLater(
          api.resolveStaffQr(codeData: '   '),
          throwsA(
            isA<PartnerApiException>()
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });
    });

    group('transferPoints', () {
      test('successfully executes point transfer and returns updated balances',
          () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Apex Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/partner/transfers');
          expect(request.headers['Authorization'], 'Bearer partner-jwt');
          expect(request.headers['Idempotency-Key'], 'idemp-12345');

          final body = jsonDecode(request.body);
          expect(body['amount'], 250);
          expect(body['token'], 'STAFF_TRF_TOKEN_001');
          expect(body['idempotency_key'], 'idemp-12345');

          return http.Response(
            jsonEncode({
              'transfer_id': 99,
              'amount': 250,
              'sender_id': 1,
              'recipient_id': 10,
              'recipient_name': 'Rajesh Kumar Staff',
              'recipient_staff_id': 'STF-001',
              'created_at': '2026-11-10T01:30:00Z',
              'sender_balance': 750,
              'recipient_balance': 250,
              'is_idempotent_replay': false,
            }),
            200,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        final response = await api.transferPoints(
          codeData: 'STAFF_TRF_TOKEN_001',
          amount: 250,
          idempotencyKey: 'idemp-12345',
        );

        expect(response.transferId, 99);
        expect(response.amount, 250);
        expect(response.senderId, 1);
        expect(response.recipientId, 10);
        expect(response.recipientName, 'Rajesh Kumar Staff');
        expect(response.recipientStaffId, 'STF-001');
        expect(response.senderBalance, 750);
        expect(response.recipientBalance, 250);
        expect(response.isIdempotentReplay, isFalse);
      });

      test('handles insufficient balance error (400)', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'detail':
                  'Insufficient points balance. Current available balance is 100, but transfer requires 500 points.'
            }),
            400,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        await expectLater(
          api.transferPoints(
            codeData: 'STAFF_TRF_TOKEN_001',
            amount: 500,
            idempotencyKey: 'idemp-999',
          ),
          throwsA(
            isA<PartnerApiException>()
                .having((e) => e.statusCode, 'statusCode', 400)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Insufficient points balance'),
                ),
          ),
        );
      });

      test('handles idempotency replay response (200 with replay flag)',
          () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'transfer_id': 99,
              'amount': 250,
              'sender_id': 1,
              'recipient_id': 10,
              'recipient_name': 'Rajesh Kumar Staff',
              'recipient_staff_id': 'STF-001',
              'created_at': '2026-11-10T01:30:00Z',
              'sender_balance': 750,
              'recipient_balance': 250,
              'is_idempotent_replay': true,
            }),
            200,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        final res = await api.transferPoints(
          codeData: 'STAFF_TRF_TOKEN_001',
          amount: 250,
          idempotencyKey: 'idemp-12345',
        );

        expect(res.isIdempotentReplay, isTrue);
        expect(res.senderBalance, 750);
      });
    });

    group('getAvailableBalance', () {
      test('fetches available balance from dashboard stats', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt',
          user: const PartnerUser(
            id: 1,
            name: 'Partner',
            mobile: '9811111111',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/orders/dashboard/stats');
          return http.Response(
            jsonEncode({
              'total_points': 1500,
              'points_used': 500,
              'remaining_balance': 1000,
              'total_orders': 10,
              'pending_orders': 2,
              'processing_orders': 1,
              'dispatched_orders': 2,
              'delivered_orders': 5,
              'cancelled_orders': 0,
            }),
            200,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        final balance = await api.getAvailableBalance();
        expect(balance, 1000);
      });
    });

    group('getPointsHistory', () {
      test('throws PartnerApiException with 401 when unauthenticated', () async {
        final session = PartnerSessionManager();
        await session.clearSession();
        final api = PartnerApi(sessionManager: session);

        expect(
          () => api.getPointsHistory(),
          throwsA(
            isA<PartnerApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });

      test('fetches paginated partner points history and parses items correctly', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt-token',
          user: const PartnerUser(
            id: 10,
            name: 'Apex Partner',
            mobile: '9800000010',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/partner/points-history');
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['page_size'], '10');
          expect(request.headers['Authorization'], 'Bearer partner-jwt-token');

          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'tr-1',
                  'transaction_type': 'transfer_sent',
                  'direction': 'debit',
                  'points': -40,
                  'amount': 40,
                  'title': 'Points Transferred to Vikram Staff',
                  'description': 'Transferred 40 points to Vikram Staff (STF-001)',
                  'reference_id': 'idem-tr-40',
                  'recipient_name': 'Vikram Staff',
                  'recipient_staff_id': 'STF-001',
                  'created_at': '2026-11-10T10:30:00Z',
                },
                {
                  'id': 'pt-2',
                  'transaction_type': 'qr_scan',
                  'direction': 'credit',
                  'points': 50,
                  'amount': 50,
                  'title': 'Points Earned (Product QR)',
                  'description': 'Product QR scan: PRD-QR-50',
                  'reference_id': 'PRD-QR-50',
                  'created_at': '2026-11-10T09:00:00Z',
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

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        final res = await api.getPointsHistory(page: 2, pageSize: 10);
        expect(res.total, 15);
        expect(res.page, 2);
        expect(res.pageSize, 10);
        expect(res.totalPages, 2);
        expect(res.hasNext, isFalse);
        expect(res.hasPrev, isTrue);
        expect(res.items.length, 2);

        final debitItem = res.items[0];
        expect(debitItem.id, 'tr-1');
        expect(debitItem.isDebit, isTrue);
        expect(debitItem.isCredit, isFalse);
        expect(debitItem.points, -40);
        expect(debitItem.amount, 40);
        expect(debitItem.recipientName, 'Vikram Staff');
        expect(debitItem.recipientStaffId, 'STF-001');

        final creditItem = res.items[1];
        expect(creditItem.id, 'pt-2');
        expect(creditItem.isCredit, isTrue);
        expect(creditItem.isDebit, isFalse);
        expect(creditItem.points, 50);
        expect(creditItem.amount, 50);
        expect(creditItem.referenceId, 'PRD-QR-50');
      });

      test('handles server error response cleanly', () async {
        final session = PartnerSessionManager();
        await session.saveSession(
          token: 'partner-jwt-token',
          user: const PartnerUser(
            id: 10,
            name: 'Apex Partner',
            mobile: '9800000010',
            role: 'partner',
          ),
        );

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Database connection error'}),
            500,
          );
        });

        final api = PartnerApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: session,
        );

        expect(
          () => api.getPointsHistory(),
          throwsA(
            isA<PartnerApiException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.message, 'message', 'Database connection error'),
          ),
        );
      });
    });
  });
}
