import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/models/admin_qr_models.dart';
import 'package:score_app/core/services/admin_qr_api.dart';
import 'package:score_app/core/services/admin_qr_excel_exporter.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  group('AdminQrExcelExporter Unit Tests', () {
    late AdminQrBatch sampleBatch;
    const mockAdmin = AdminUser(
      id: 1,
      name: 'Super Admin',
      mobile: '9876543210',
      role: 'admin',
      isActive: true,
    );
    final validXlsxBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]);

    setUp(() {
      sampleBatch = AdminQrBatch.fromJson({
        'id': 42,
        'batch_number': 'BATCH-20261117-001',
        'qr_type': 'product',
        'description': 'Product Run #1',
        'quantity': 100,
        'status': 'completed',
        'active_count': 100,
        'redeemed_count': 0,
        'voided_count': 0,
        'created_at': '2026-11-17T10:00:00Z',
      });
    });

    test('throws FormatException if downloaded bytes do not have XLSX signature', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html>Error</html>', 200);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'test_token', user: mockAdmin);
      final qrApi = AdminQrApi(baseUrl: 'https://test.api', client: mockClient, sessionManager: session);

      final exporter = AdminQrExcelExporter(
        saver: ({required bytes, required fileName, required mimeType}) async {
          return fileName;
        },
      );

      expect(
        () => exporter.exportBatch(qrApi: qrApi, batch: sampleBatch),
        throwsA(isA<FormatException>()),
      );
    });

    test('calls saver with exact fileName, mimeType, and bytes when signature is valid', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/qr/batches/42/export/excel');
        return http.Response.bytes(validXlsxBytes, 200);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'test_token', user: mockAdmin);
      final qrApi = AdminQrApi(baseUrl: 'https://test.api', client: mockClient, sessionManager: session);

      Uint8List? capturedBytes;
      String? capturedFileName;
      String? capturedMimeType;

      final exporter = AdminQrExcelExporter(
        saver: ({required bytes, required fileName, required mimeType}) async {
          capturedBytes = bytes;
          capturedFileName = fileName;
          capturedMimeType = mimeType;
          return fileName;
        },
      );

      final result = await exporter.exportBatch(qrApi: qrApi, batch: sampleBatch);

      expect(result, 'BATCH-20261117-001_qr_codes.xlsx');
      expect(capturedBytes, validXlsxBytes);
      expect(capturedFileName, 'BATCH-20261117-001_qr_codes.xlsx');
      expect(
        capturedMimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    });

    test('propagates cancellation (null result) when user cancels save', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(validXlsxBytes, 200);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'test_token', user: mockAdmin);
      final qrApi = AdminQrApi(baseUrl: 'https://test.api', client: mockClient, sessionManager: session);

      final exporter = AdminQrExcelExporter(
        saver: ({required bytes, required fileName, required mimeType}) async {
          return null;
        },
      );

      final result = await exporter.exportBatch(qrApi: qrApi, batch: sampleBatch);
      expect(result, isNull);
    });

    test('propagates saver exception when save fails', () async {
      final mockClient = MockClient((request) async {
        return http.Response.bytes(validXlsxBytes, 200);
      });

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'test_token', user: mockAdmin);
      final qrApi = AdminQrApi(baseUrl: 'https://test.api', client: mockClient, sessionManager: session);

      final exporter = AdminQrExcelExporter(
        saver: ({required bytes, required fileName, required mimeType}) async {
          throw Exception('Browser download denied');
        },
      );

      expect(
        () => exporter.exportBatch(qrApi: qrApi, batch: sampleBatch),
        throwsA(isA<Exception>()),
      );
    });
  });
}
