import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_qr_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/qr/admin_qr_generation_screen.dart';
import 'package:score_app/features/admin/qr/widgets/admin_create_qr_batch_dialog.dart';
import 'package:score_app/features/admin/qr/widgets/admin_view_qr_codes_dialog.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  Map<String, dynamic> mockBatchJson({
    int id = 1,
    String batchNumber = 'BATCH-20261026-TEST',
    String qrType = 'product',
    int quantity = 15,
  }) {
    return {
      'id': id,
      'batch_number': batchNumber,
      'qr_type': qrType,
      'description': 'Product Run #1',
      'points_rule_id': null,
      'points_rule_name': null,
      'product_id': 1,
      'product_name': 'Test Spark Plug',
      'target_user_id': null,
      'target_user_name': null,
      'quantity': quantity,
      'status': 'completed',
      'active_count': quantity,
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
    String token = 'TOK1234567890ABCDEF1234567890',
  }) {
    return {
      'id': id,
      'batch_id': batchId,
      'qr_type': 'product',
      'token': token,
      'code_data': 'score://qr/v1?token=$token&type=product',
      'points_awarded': 25,
      'product_id': 1,
      'product_name': 'Test Spark Plug',
      'target_user_id': null,
      'target_user_name': null,
      'status': 'active',
      'redeemed_by': null,
      'redeemed_at': null,
      'expires_at': null,
      'created_at': '2026-10-26T10:00:00Z',
    };
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
  }

  Widget buildTestScreen({
    required http.Client client,
    required AdminSessionManager sessionManager,
  }) {
    final adminApi = AdminApi(
      client: client,
      baseUrl: 'http://localhost:8000',
      sessionManager: sessionManager,
    );
    final qrApi = AdminQrApi(
      client: client,
      baseUrl: 'http://localhost:8000',
      sessionManager: sessionManager,
    );

    return MaterialApp(
      home: AdminQrGenerationScreen(
        adminApi: adminApi,
        qrApi: qrApi,
      ),
    );
  }

  group('AdminQrGenerationScreen Widget & Interaction Tests', () {
    testWidgets(
        '1. Renders screen, notice, 4 category cards, and recent batches',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/batches') {
          return http.Response(
            jsonEncode({
              'items': [mockBatchJson()],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester
          .pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      expect(find.text('QR Code Generation'), findsOneWidget);
      expect(find.text('Manage QR codes for Score'), findsOneWidget);

      // 4 Categories
      expect(find.text('Product QR'), findsWidgets);
      expect(find.text('Invoice QR'), findsWidgets);
      expect(find.text('Staff QR'), findsWidgets);
      expect(find.text('Partner QR'), findsWidgets);

      // Recent batches
      expect(find.text('BATCH-20261026-TEST'), findsOneWidget);
      expect(find.text('15/15 ACTIVE'), findsOneWidget);
      expect(find.byKey(const Key('export_excel_batch_1')), findsOneWidget);
      expect(find.byKey(const Key('view_codes_batch_1')), findsOneWidget);
    });

    testWidgets(
        '2. Export to Excel button calls excel endpoint and displays SnackBar',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      final mockExcelBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      const fileDialogChannel = MethodChannel('flutter_file_dialog');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileDialogChannel, (call) async {
        expect(call.method, 'saveFile');
        final arguments = call.arguments as Map<dynamic, dynamic>;
        expect(arguments['fileName'], 'BATCH-20261026-EXCEL_qr_codes.xlsx');
        expect(arguments['data'], mockExcelBytes);
        expect(
          arguments['mimeTypesFilter'],
          ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        );
        return 'content://downloads/document/qr-batch.xlsx';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileDialogChannel, null));
      bool excelExportCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/batches') {
          return http.Response(
            jsonEncode({
              'items': [
                mockBatchJson(id: 1, batchNumber: 'BATCH-20261026-EXCEL')
              ],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/qr/batches/1/export/excel') {
          excelExportCalled = true;
          return http.Response.bytes(
            mockExcelBytes,
            200,
            headers: {
              'content-type':
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              'content-disposition':
                  'attachment; filename="BATCH-20261026-EXCEL_qr_codes.xlsx"',
            },
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester
          .pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Tap Export Excel button on batch card
      await tester.ensureVisible(find.byKey(const Key('export_excel_batch_1')));
      await tester.tap(find.byKey(const Key('export_excel_batch_1')));
      await tester.pumpAndSettle();

      expect(excelExportCalled, isTrue);
      expect(
        find.text('Excel file saved: BATCH-20261026-EXCEL_qr_codes.xlsx'),
        findsOneWidget,
      );
    });

    testWidgets(
        '3. Tapping category card opens creation dialog and submits batch',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      bool createBatchCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/batches' &&
            request.method == 'GET') {
          return http.Response(
            jsonEncode({'items': [], 'total': 0}),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/qr/batches' &&
            request.method == 'POST') {
          createBatchCalled = true;
          final body = jsonDecode(request.body);
          expect(body['qr_type'], 'invoice');
          expect(body['quantity'], 20);
          return http.Response(
            jsonEncode(mockBatchJson(id: 2, qrType: 'invoice', quantity: 20)),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester
          .pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Tap Invoice QR Category card
      await tester
          .ensureVisible(find.byKey(const Key('category_card_invoice')));
      await tester.tap(find.byKey(const Key('category_card_invoice')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminCreateQrBatchDialog), findsOneWidget);

      // Modify quantity
      await tester.enterText(
          find.byKey(const Key('qr_batch_quantity_field')), '20');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('submit_create_qr_batch_button')));
      await tester.pumpAndSettle();

      expect(createBatchCalled, isTrue);
      expect(find.textContaining('Generated 20 QR codes'), findsOneWidget);
    });

    testWidgets('4. Tapping View Codes opens dialog and renders QR tokens',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      final mockExcelBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04]);
      const fileDialogChannel = MethodChannel('flutter_file_dialog');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileDialogChannel, (call) async {
        expect(call.method, 'saveFile');
        return 'content://downloads/document/qr-batch.xlsx';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fileDialogChannel, null));
      bool excelExportCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/qr/batches') {
          return http.Response(
            jsonEncode({
              'items': [mockBatchJson()],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/qr/batches/1/export/excel') {
          excelExportCalled = true;
          return http.Response.bytes(mockExcelBytes, 200);
        }
        if (request.url.path == '/api/v1/admin/qr/batches/1/codes') {
          return http.Response(
            jsonEncode({
              'items': [mockCodeJson(token: 'TOK1234567890ABCDEF1234567890')],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester
          .pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Tap View Codes
      await tester.ensureVisible(find.byKey(const Key('view_codes_batch_1')));
      await tester.tap(find.byKey(const Key('view_codes_batch_1')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminViewQrCodesDialog), findsOneWidget);
      expect(find.text('TOK1234567890ABCDEF1234567890'), findsOneWidget);
      expect(find.text('+25 pts'), findsOneWidget);
      expect(find.byKey(const Key('export_excel_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('export_excel_button')));
      await tester.pumpAndSettle();

      expect(excelExportCalled, isTrue);
      expect(find.text('Excel file saved: BATCH-20261026-TEST_qr_codes.xlsx'),
          findsOneWidget);
    });
  });
}
