import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_qr_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_qr_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  const dummyToken = 'valid-test-admin-jwt-token';

  Future<AdminSessionManager> createSessionWithToken([String token = dummyToken]) async {
    final storage = InMemoryAdminTokenStorage();
    await storage.saveToken(token);
    return AdminSessionManager(tokenStorage: storage);
  }

  Map<String, dynamic> mockBatchJson({
    int id = 1,
    String batchNumber = 'BATCH-20261026-A1B2',
    String qrType = 'product',
    int quantity = 25,
    int activeCount = 25,
  }) {
    return {
      'id': id,
      'batch_number': batchNumber,
      'qr_type': qrType,
      'description': 'Test Batch Description',
      'points_rule_id': 10,
      'points_rule_name': 'Product Scan Reward',
      'product_id': 5,
      'product_name': 'Clutch Plate',
      'target_user_id': null,
      'target_user_name': null,
      'quantity': quantity,
      'status': 'completed',
      'active_count': activeCount,
      'redeemed_count': 0,
      'voided_count': 0,
      'created_by': 1,
      'created_by_name': 'Super Admin',
      'created_at': '2026-10-26T10:00:00Z',
    };
  }

  Map<String, dynamic> mockCodeJson({
    int id = 101,
    int batchId = 1,
    String token = 'ABCDEF1234567890ABCDEF1234567890',
  }) {
    return {
      'id': id,
      'batch_id': batchId,
      'qr_type': 'product',
      'token': token,
      'code_data': 'score://qr/v1?token=$token&type=product',
      'points_awarded': 50,
      'product_id': 5,
      'product_name': 'Clutch Plate',
      'target_user_id': null,
      'target_user_name': null,
      'status': 'active',
      'redeemed_by': null,
      'redeemed_at': null,
      'expires_at': null,
      'created_at': '2026-10-26T10:00:00Z',
    };
  }

  group('AdminQrModels Unit Tests', () {
    test('AdminQrBatch parses all fields and computed properties correctly', () {
      final json = mockBatchJson();
      final batch = AdminQrBatch.fromJson(json);

      expect(batch.id, 1);
      expect(batch.batchNumber, 'BATCH-20261026-A1B2');
      expect(batch.typeLabel, 'Product QR');
      expect(batch.quantity, 25);
      expect(batch.activeCount, 25);
      expect(batch.productName, 'Clutch Plate');

      final serialized = batch.toJson();
      expect(serialized['batch_number'], 'BATCH-20261026-A1B2');
    });

    test('AdminQrCode parses all fields and status getters', () {
      final json = mockCodeJson();
      final code = AdminQrCode.fromJson(json);

      expect(code.id, 101);
      expect(code.token, 'ABCDEF1234567890ABCDEF1234567890');
      expect(code.isActive, isTrue);
      expect(code.isRedeemed, isFalse);
      expect(code.isVoided, isFalse);
    });

    test('AdminQrBatchPayload formats JSON correctly', () {
      const payload = AdminQrBatchPayload(
        qrType: 'product',
        quantity: 50,
        description: 'New run',
        productId: 7,
        pointsRuleId: 3,
      );

      final json = payload.toJson();
      expect(json['qr_type'], 'product');
      expect(json['quantity'], 50);
      expect(json['product_id'], 7);
      expect(json['points_rule_id'], 3);
      expect(json['description'], 'New run');
    });
  });

  group('AdminQrApi Operations Tests', () {
    test('getBatches sends filters and parses batch list', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/qr/batches');
        expect(request.url.queryParameters['qr_type'], 'product');
        expect(request.headers['Authorization'], 'Bearer $dummyToken');
        return http.Response(
          jsonEncode({
            'items': [mockBatchJson()],
            'total': 1,
          }),
          200,
        );
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final res = await api.getBatches(qrType: 'product');
      expect(res.total, 1);
      expect(res.items.first.batchNumber, 'BATCH-20261026-A1B2');
    });

    test('createBatch sends POST request and receives created batch', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/qr/batches');
        final body = jsonDecode(request.body);
        expect(body['qr_type'], 'invoice');
        expect(body['quantity'], 10);
        return http.Response(
          jsonEncode(mockBatchJson(qrType: 'invoice', quantity: 10)),
          201,
        );
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final batch = await api.createBatch(
        const AdminQrBatchPayload(qrType: 'invoice', quantity: 10),
      );
      expect(batch.qrType, 'invoice');
      expect(batch.quantity, 10);
    });

    test('getBatchCodes fetches paginated QR codes', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/qr/batches/1/codes');
        return http.Response(
          jsonEncode({
            'items': [mockCodeJson()],
            'total': 1,
          }),
          200,
        );
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final res = await api.getBatchCodes(1);
      expect(res.total, 1);
      expect(res.items.first.token, 'ABCDEF1234567890ABCDEF1234567890');
    });

    test('downloadBatchExcel requests excel file and returns bytes', () async {
      final session = await createSessionWithToken();
      final mockBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]); // PK zip header

      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/qr/batches/1/export/excel');
        expect(
          request.headers['Accept'],
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        return http.Response.bytes(
          mockBytes,
          200,
          headers: {
            'content-type':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'content-disposition':
                'attachment; filename="BATCH-20261026-A1B2_qr_codes.xlsx"',
          },
        );
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final bytes = await api.downloadBatchExcel(1);
      expect(bytes.length, mockBytes.length);
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('downloadBatchCsv requests csv and returns text', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/qr/batches/1/export/csv');
        return http.Response('S.No,Batch Number,QR Token\n1,BATCH-1,TOK1\n', 200);
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final csv = await api.downloadBatchCsv(1);
      expect(csv, contains('Batch Number,QR Token'));
    });

    test('updateCodeStatus patches code status', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/admin/qr/codes/101/status');
        final body = jsonDecode(request.body);
        expect(body['status'], 'voided');
        return http.Response(
          jsonEncode(mockCodeJson(id: 101)..['status'] = 'voided'),
          200,
        );
      });

      final api = AdminQrApi(client: client, sessionManager: session);
      final code = await api.updateCodeStatus(101, 'voided');
      expect(code.status, 'voided');
      expect(code.isVoided, isTrue);
    });

    test('AdminApi forwards qr calls seamlessly', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/batches') {
          return http.Response(jsonEncode({'items': [], 'total': 0}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, sessionManager: session);
      final res = await adminApi.qr.getBatches();
      expect(res.total, 0);
    });
  });
}
