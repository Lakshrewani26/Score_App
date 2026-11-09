import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/qr_scan_models.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/core/services/qr_api.dart';
import 'package:score_app/features/customer/qr_scanner/customer_qr_scanner.dart';
import 'package:score_app/features/partner/balance/partner_balance_screen.dart';

void main() {
  setUp(() async {
    await CustomerSessionManager.instance.clearSession();
    await PartnerSessionManager.instance.clearSession();
  });

  group('QrScanApi Unit Tests', () {
    test('1. scanQrCode succeeds and parses QrScanResult', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/qr/scan');
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code_data'], 'score://qr/v1?token=TEST_TOKEN_123&type=product');

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'QR code scanned successfully! Awarded 50 loyalty points.',
            'points_awarded': 50,
            'new_balance': 250,
            'qr_token': 'TEST_TOKEN_123',
            'qr_type': 'product',
            'rule_id': 12,
            'rule_name': 'Customer QR Rule',
            'rule_version': 2,
            'scanned_at': '2026-11-07T12:00:00Z',
            'is_idempotent_replay': false,
          }),
          200,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        baseUrl: 'http://localhost:8000',
        tokenProvider: () async => 'test-bearer-token',
      );

      final result = await api.scanQrCode(
        codeData: 'score://qr/v1?token=TEST_TOKEN_123&type=product',
      );

      expect(requestCount, 1);
      expect(result.success, isTrue);
      expect(result.pointsAwarded, 50);
      expect(result.newBalance, 250);
      expect(result.qrToken, 'TEST_TOKEN_123');
      expect(result.qrType, 'product');
      expect(result.ruleName, 'Customer QR Rule');
      expect(result.ruleVersion, 2);
      expect(result.isIdempotentReplay, isFalse);
    });

    test('2. scanQrCode handles duplicate 409 conflict and sets isDuplicate flag', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'This QR code has already been scanned and redeemed.',
          }),
          409,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'valid-token',
      );

      try {
        await api.scanQrCode(codeData: 'DUPLICATE_CODE_123');
        fail('Should throw QrScanException');
      } on QrScanException catch (e) {
        expect(e.statusCode, 409);
        expect(e.isDuplicate, isTrue);
        expect(e.message, contains('already been scanned and redeemed'));
      }
    });

    test('3. scanQrCode handles expired QR 400 and sets isExpired flag', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'This QR code has expired.',
          }),
          400,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'valid-token',
      );

      try {
        await api.scanQrCode(codeData: 'EXPIRED_CODE_123');
        fail('Should throw QrScanException');
      } on QrScanException catch (e) {
        expect(e.statusCode, 400);
        expect(e.isExpired, isTrue);
        expect(e.message, contains('expired'));
      }
    });

    test('4. scanQrCode handles inappropriate QR type 400 and sets isInvalidType flag', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': "Inappropriate QR code type: 'staff' QR codes cannot be scanned for loyalty points.",
          }),
          400,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'valid-token',
      );

      try {
        await api.scanQrCode(codeData: 'STAFF_CODE_123');
        fail('Should throw QrScanException');
      } on QrScanException catch (e) {
        expect(e.statusCode, 400);
        expect(e.isInvalidType, isTrue);
        expect(e.message, contains("Inappropriate QR code type"));
      }
    });

    test('5. scanQrCode handles 404 QR code not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'QR code token not found.',
          }),
          404,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'valid-token',
      );

      try {
        await api.scanQrCode(codeData: 'UNKNOWN_CODE_999');
        fail('Should throw QrScanException');
      } on QrScanException catch (e) {
        expect(e.statusCode, 404);
        expect(e.isNotFound, isTrue);
      }
    });

    test('6. scanQrCode handles unauthorized 401 and missing session token', () async {
      final api = QrScanApi(tokenProvider: () async => null);

      try {
        await api.scanQrCode(codeData: 'SOME_CODE');
        fail('Should throw QrScanException for unauthenticated caller');
      } on QrScanException catch (e) {
        expect(e.statusCode, 401);
        expect(e.isUnauthorized, isTrue);
      }
    });

    test('7. getTransactions parses transaction history', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/qr/transactions');
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'user_id': 10,
              'qr_code_id': 101,
              'qr_token': 'QR101',
              'points_rule_id': 5,
              'points_rule_name': 'Diwali Scan Promo',
              'points_rule_version': 1,
              'points_awarded': 60,
              'qr_type': 'product',
              'transaction_type': 'qr_scan',
              'idempotency_key': 'key-101',
              'created_at': '2026-11-07T11:00:00Z',
            }
          ]),
          200,
        );
      });

      final api = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'valid-token',
      );

      final list = await api.getTransactions();
      expect(list.length, 1);
      expect(list.first.pointsRuleName, 'Diwali Scan Promo');
      expect(list.first.pointsRuleVersion, 1);
      expect(list.first.pointsAwarded, 60);
    });
  });

  group('CustomerQrScannerSheet Integration Widget Tests', () {
    testWidgets('1. Manual entry submission succeeds and shows rich points success card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'QR code scanned successfully! Awarded 75 loyalty points.',
            'points_awarded': 75,
            'new_balance': 375,
            'qr_token': 'PROD_QR_777',
            'qr_type': 'product',
            'rule_id': 8,
            'rule_name': 'Retail Product Rule',
            'rule_version': 3,
            'scanned_at': '2026-11-07T12:00:00Z',
            'is_idempotent_replay': false,
          }),
          200,
        );
      });

      final qrApi = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'active-cust-token',
      );

      QrScanResult? capturedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CustomerQrScannerSheet.show(
                  context,
                  mode: ScannerMode.scan,
                  autoSubmit: true,
                  qrApi: qrApi,
                  authToken: 'active-cust-token',
                  onScanSuccess: (res) {
                    capturedResult = res;
                  },
                ),
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      // Tap Enter Code Manually
      expect(find.text('Enter Code Manually'), findsOneWidget);
      await tester.tap(find.text('Enter Code Manually'));
      await tester.pumpAndSettle();

      // Enter code and submit
      await tester.enterText(find.byType(TextField), 'PROD_QR_777');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Verify rich success card elements
      expect(find.text('Points Awarded!'), findsOneWidget);
      expect(find.text('+75 Points'), findsOneWidget);
      expect(find.text('Updated Balance: 375 pts'), findsOneWidget);
      expect(find.text('Rule: Retail Product Rule (v3)'), findsOneWidget);
      expect(find.text('Scan Another'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      expect(capturedResult?.pointsAwarded, 75);
      expect(capturedResult?.newBalance, 375);

      // Tap Done to close
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Duplicate scan displays Already Redeemed card and allows retry',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'This QR code has already been scanned and redeemed.',
          }),
          409,
        );
      });

      final qrApi = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'active-cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CustomerQrScannerSheet.show(
                  context,
                  mode: ScannerMode.scan,
                  autoSubmit: true,
                  qrApi: qrApi,
                  authToken: 'active-cust-token',
                ),
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Code Manually'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ALREADY_REDEEMED_CODE');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // Verify rich Already Redeemed card
      expect(find.text('Already Redeemed'), findsOneWidget);
      expect(find.text('This QR code has already been scanned and redeemed.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Try Again to reset to camera view
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Position the QR code inside the frame'), findsOneWidget);
      expect(find.text('Enter Code Manually'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Inappropriate QR type displays Invalid QR Type card',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': "Inappropriate QR code type: 'staff' QR codes cannot be scanned for loyalty points.",
          }),
          400,
        );
      });

      final qrApi = QrScanApi(
        client: mockClient,
        tokenProvider: () async => 'active-cust-token',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CustomerQrScannerSheet.show(
                  context,
                  mode: ScannerMode.scan,
                  autoSubmit: true,
                  qrApi: qrApi,
                  authToken: 'active-cust-token',
                ),
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Scanner'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Code Manually'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'STAFF_ID_CODE');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid QR Type'), findsOneWidget);
      expect(find.text("Inappropriate QR code type: 'staff' QR codes cannot be scanned for loyalty points."), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. PartnerBalanceScreen does not render misleading product QR button and displays disabled invoice QR action',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = PartnerSessionManager();
      await session.saveSession(
        token: 'partner-test-token',
        user: const PartnerUser(
          id: 50,
          name: 'Partner Pro',
          mobile: '9888888888',
          role: 'partner',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: session,
            pointsEarned: '1000',
            pointsSpent: '200',
            remainingBalance: '800',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify misleading Scan Product QR Code button is NOT present
      expect(find.byKey(const Key('partner_scan_product_qr_button')), findsNothing);
      expect(find.text('Scan Product QR Code'), findsNothing);

      // Verify disabled Invoice QR action is present
      final invoiceBtn = find.byKey(const Key('partner_scan_invoice_qr_button'));
      expect(invoiceBtn, findsOneWidget);
      expect(find.text('Scan Invoice QR Code (Coming Soon)'), findsOneWidget);

      // Tapping disabled button does not open any scanner
      await tester.tap(invoiceBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsNothing);
      expect(find.byType(PartnerBalanceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
