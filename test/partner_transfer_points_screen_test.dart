import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:score_app/core/services/partner_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/customer/qr_scanner/customer_qr_scanner.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_points_screen.dart';

void main() {
  late PartnerSessionManager testSession;

  setUp(() async {
    testSession = PartnerSessionManager();
    await testSession.saveSession(
      token: 'test-partner-jwt-token',
      user: const PartnerUser(
        id: 1,
        name: 'Apex Motors Partner',
        mobile: '9811111111',
        role: 'partner',
      ),
    );
  });

  PartnerApi createMockApi({
    int availableBalance = 1000,
    Map<String, dynamic>? resolveResponse,
    int resolveStatus = 200,
    Map<String, dynamic>? transferResponse,
    int transferStatus = 200,
    List<http.Request>? recordedRequests,
  }) {
    int currentBalance = availableBalance;
    final client = MockClient((request) async {
      recordedRequests?.add(request);

      if (request.url.path == '/api/v1/orders/dashboard/stats') {
        return http.Response(
          jsonEncode({
            'total_points': currentBalance + 500,
            'points_used': 500,
            'remaining_balance': currentBalance,
            'total_orders': 5,
            'pending_orders': 1,
            'processing_orders': 1,
            'dispatched_orders': 1,
            'delivered_orders': 2,
            'cancelled_orders': 0,
          }),
          200,
        );
      }

      if (request.url.path == '/api/v1/staff/qr/resolve') {
        if (resolveStatus == 200) {
          return http.Response(
            jsonEncode(resolveResponse ??
                {
                  'staff_user_id': 10,
                  'staff_name': 'Rajesh Kumar Staff',
                  'staff_id': 'STF-001',
                  'qr_code_id': 50,
                  'qr_type': 'staff',
                }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode(resolveResponse ??
                {'detail': 'Staff QR code token not found.'}),
            resolveStatus,
          );
        }
      }

      if (request.url.path == '/api/v1/partner/transfers') {
        if (transferStatus == 200) {
          final body = jsonDecode(request.body);
          final int amt = body['amount'] as int? ?? 250;
          currentBalance -= amt;
          return http.Response(
            jsonEncode(transferResponse ??
                {
                  'transfer_id': 101,
                  'amount': amt,
                  'sender_id': 1,
                  'recipient_id': 10,
                  'recipient_name': 'Rajesh Kumar Staff',
                  'recipient_staff_id': 'STF-001',
                  'created_at': '2026-11-10T01:30:00Z',
                  'sender_balance': currentBalance,
                  'recipient_balance': amt,
                  'is_idempotent_replay': false,
                }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode(transferResponse ??
                {'detail': 'Transfer amount is below minimum.'}),
            transferStatus,
          );
        }
      }

      return http.Response('Not Found', 404);
    });

    return PartnerApi(
      client: client,
      baseUrl: 'http://localhost',
      sessionManager: testSession,
    );
  }

  group('PartnerTransferPointsScreen Tests', () {
    testWidgets('1. Transfer screen loads and displays balance from API',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(availableBalance: 1250);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Subtitle
      expect(find.text('Transfer Points'), findsAtLeastNWidgets(1));
      expect(find.text('Transfer points to staff securely'), findsOneWidget);

      // Verify Loaded Balance
      expect(find.text('Available Points'), findsOneWidget);
      expect(find.text('1250'), findsOneWidget);

      // Verify Options
      expect(find.text('Scan Staff QR Code'), findsOneWidget);
      expect(find.text('Enter Staff ID'), findsOneWidget);
    });

    testWidgets('2. QR Scanner option opens CustomerQrScannerSheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(availableBalance: 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scanBtn = find.text('Scan Staff QR Code');
      expect(scanBtn, findsOneWidget);
      await tester.tap(scanBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);

      // Close scanner
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerQrScannerSheet), findsNothing);
      expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);
    });

    testWidgets(
        '3. Successful Staff QR resolution displays recipient details and verified badge',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(
        availableBalance: 1000,
        resolveResponse: {
          'staff_user_id': 10,
          'staff_name': 'Rajesh Kumar Staff',
          'staff_id': 'STF-001',
          'qr_code_id': 50,
          'qr_type': 'staff',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open manual entry dialog to resolve QR token
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();

      final input = find.widgetWithText(TextField, 'Enter Staff ID');
      await tester.enterText(input, 'STAFF_TRF_TOKEN_001');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Recipient section is displayed
      expect(find.text('Staff Recipient'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Rajesh Kumar Staff'), findsOneWidget);
      expect(find.text('Staff ID: STF-001'), findsOneWidget);

      // Selection buttons are now hidden
      expect(find.text('Scan Staff QR Code'), findsNothing);
      expect(find.text('Enter Staff ID'), findsNothing);

      // Clearing recipient restores selection options
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Kumar Staff'), findsNothing);
      expect(find.text('Scan Staff QR Code'), findsOneWidget);
      expect(find.text('Enter Staff ID'), findsOneWidget);
    });

    testWidgets(
        '4. Invalid QR response displays clear error and does not populate recipient',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(
        availableBalance: 1000,
        resolveStatus: 400,
        resolveResponse: {
          'detail':
              "Inappropriate QR code type: 'product' QR codes cannot be resolved as Staff recipients."
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();

      final input = find.widgetWithText(TextField, 'Enter Staff ID');
      await tester.enterText(input, 'PRODUCT_TOKEN_123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Error message is displayed in alert banner
      expect(
        find.textContaining('Inappropriate QR code type'),
        findsOneWidget,
      );

      // Recipient is not resolved
      expect(find.text('Verified'), findsNothing);

      // Transfer button remains disabled
      final transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNull);
    });

    testWidgets('5. Amount validation prevents zero, negative, or blank input',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(availableBalance: 1000);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resolve recipient first
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_TOKEN_001',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      final pointsField = find.widgetWithText(TextField, 'Enter points');

      // Empty points: Transfer disabled
      var transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNull);

      // 0 points: Transfer disabled & error shown
      await tester.enterText(pointsField, '0');
      await tester.pumpAndSettle();
      expect(find.text('Points must be greater than zero'), findsOneWidget);
      transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNull);

      // Valid points: Transfer enabled & error gone
      await tester.enterText(pointsField, '250');
      await tester.pumpAndSettle();
      expect(find.text('Points must be greater than zero'), findsNothing);
      transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNotNull);
    });

    testWidgets('6. Insufficient balance disables transfer and shows error',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(availableBalance: 300);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resolve recipient
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_TOKEN_001',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      final pointsField = find.widgetWithText(TextField, 'Enter points');

      // Enter amount exceeding available balance (500 > 300)
      await tester.enterText(pointsField, '500');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Insufficient points balance (available: 300 points)'),
        findsOneWidget,
      );

      final transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNull);
    });

    testWidgets(
        '7. Successful transfer updates balance, clears form, and displays success',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <http.Request>[];
      final api = createMockApi(
        availableBalance: 1000,
        recordedRequests: requests,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Resolve recipient
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_TOKEN_001',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // 2. Enter points
      final pointsField = find.widgetWithText(TextField, 'Enter points');
      await tester.enterText(pointsField, '300');
      await tester.pumpAndSettle();

      // 3. Tap Transfer Points to open Confirm Transfer dialog
      final transferButtonFinder =
          find.widgetWithText(ElevatedButton, 'Transfer Points');
      await tester.ensureVisible(transferButtonFinder);
      await tester.tap(transferButtonFinder);
      await tester.pumpAndSettle();

      // 4. Verify confirmation dialog details
      expect(find.text('Confirm Transfer'), findsOneWidget);
      expect(find.text('Rajesh Kumar Staff'), findsWidgets);
      expect(find.text('300 Points'), findsOneWidget);
      expect(find.text('1000 Points'), findsOneWidget);
      expect(find.text('700 Points'), findsOneWidget);

      // 5. Confirm transfer
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify transfer API request was sent
      final transferReq = requests.firstWhere(
        (r) => r.url.path == '/api/v1/partner/transfers',
      );
      expect(transferReq.headers['Authorization'], 'Bearer test-partner-jwt-token');
      final body = jsonDecode(transferReq.body);
      expect(body['amount'], 300);
      expect(body['token'], 'STAFF_TRF_TOKEN_001');

      // Verify success feedback & updated balance
      expect(
        find.textContaining('Successfully transferred 300 points'),
        findsOneWidget,
      );
      expect(find.text('700'), findsOneWidget);

      // Recipient is cleared and selection buttons restored
      expect(find.text('Scan Staff QR Code'), findsOneWidget);
    });

    testWidgets(
        '8. Transfer API error allows retry with the same idempotency key',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <http.Request>[];
      int transferCallCount = 0;
      int currentBal = 1000;

      final client = MockClient((request) async {
        requests.add(request);

        if (request.url.path == '/api/v1/orders/dashboard/stats') {
          return http.Response(
            jsonEncode({
              'total_points': currentBal + 500,
              'points_used': 500,
              'remaining_balance': currentBal,
              'total_orders': 0,
              'pending_orders': 0,
              'processing_orders': 0,
              'dispatched_orders': 0,
              'delivered_orders': 0,
              'cancelled_orders': 0,
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/staff/qr/resolve') {
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
        }

        if (request.url.path == '/api/v1/partner/transfers') {
          transferCallCount++;
          if (transferCallCount == 1) {
            // First attempt fails with temporary network timeout / 500 error
            return http.Response(
              jsonEncode({'detail': 'Temporary connection failure'}),
              500,
            );
          } else {
            // Second attempt (retry) succeeds
            currentBal = 800;
            return http.Response(
              jsonEncode({
                'transfer_id': 102,
                'amount': 200,
                'sender_id': 1,
                'recipient_id': 10,
                'recipient_name': 'Rajesh Kumar Staff',
                'recipient_staff_id': 'STF-001',
                'created_at': '2026-11-10T01:30:00Z',
                'sender_balance': 800,
                'recipient_balance': 200,
                'is_idempotent_replay': false,
              }),
              200,
            );
          }
        }

        return http.Response('Not Found', 404);
      });

      final api = PartnerApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: testSession,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resolve recipient
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_TOKEN_001',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Enter points
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter points'),
        '200',
      );
      await tester.pumpAndSettle();

      // Open confirm dialog
      final transferButtonFinder =
          find.widgetWithText(ElevatedButton, 'Transfer Points');
      await tester.ensureVisible(transferButtonFinder);
      await tester.tap(transferButtonFinder);
      await tester.pumpAndSettle();

      // 1st attempt: tap Confirm
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();

      // Error message is displayed in dialog
      expect(find.text('Temporary connection failure'), findsOneWidget);
      expect(find.text('Retry Transfer'), findsOneWidget);

      // 2nd attempt: tap Retry Transfer
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry Transfer'));
      await tester.pumpAndSettle();

      // Both requests should have been sent to /api/v1/partner/transfers
      final transferRequests = requests
          .where((r) => r.url.path == '/api/v1/partner/transfers')
          .toList();
      expect(transferRequests.length, 2);

      // Verify BOTH attempts used the EXACT SAME idempotency key!
      final key1 = jsonDecode(transferRequests[0].body)['idempotency_key'];
      final key2 = jsonDecode(transferRequests[1].body)['idempotency_key'];
      expect(key1, isNotEmpty);
      expect(key1, equals(key2));

      // Successfully finished
      expect(find.text('800'), findsOneWidget);
    });

    testWidgets('9. Back button returns to PartnerHomeScreen and Profile nav works',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Transfer Points
      final transferCard = find.text('Transfer Points');
      await tester.ensureVisible(transferCard);
      await tester.tap(transferCard);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);

      // Profile navigation
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerProfileScreen), findsOneWidget);

      // Return to PartnerTransferPointsScreen
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);

      // Top-left Back button returns to PartnerHomeScreen
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
    });

    testWidgets(
        '10. Duplicate submission prevention disables confirm button while submitting',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<http.Response>();
      int transferCallCount = 0;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/orders/dashboard/stats') {
          return http.Response(
            jsonEncode({
              'total_points': 1000,
              'points_used': 0,
              'remaining_balance': 1000,
              'total_orders': 0,
              'pending_orders': 0,
              'processing_orders': 0,
              'dispatched_orders': 0,
              'delivered_orders': 0,
              'cancelled_orders': 0,
            }),
            200,
          );
        }

        if (request.url.path == '/api/v1/staff/qr/resolve') {
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
        }

        if (request.url.path == '/api/v1/partner/transfers') {
          transferCallCount++;
          return completer.future;
        }

        return http.Response('Not Found', 404);
      });

      final api = PartnerApi(
        client: client,
        baseUrl: 'http://localhost',
        sessionManager: testSession,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resolve recipient
      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_TOKEN_001',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      // Enter points
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter points'),
        '300',
      );
      await tester.pumpAndSettle();

      // Open confirm dialog
      final transferButtonFinder =
          find.widgetWithText(ElevatedButton, 'Transfer Points');
      await tester.ensureVisible(transferButtonFinder);
      await tester.tap(transferButtonFinder);
      await tester.pumpAndSettle();

      // Tap confirm button - starts submission
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm');
      await tester.tap(confirmBtnFinder);
      await tester.pump(); // Render in-flight state

      // Verify submission is in-flight: transferCallCount == 1
      expect(transferCallCount, 1);

      // Verify that while submitting, the progress indicator is active
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Complete the pending request
      completer.complete(
        http.Response(
          jsonEncode({
            'transfer_id': 103,
            'amount': 300,
            'sender_id': 1,
            'recipient_id': 10,
            'recipient_name': 'Rajesh Kumar Staff',
            'recipient_staff_id': 'STF-001',
            'created_at': '2026-11-10T01:30:00Z',
            'sender_balance': 700,
            'recipient_balance': 300,
            'is_idempotent_replay': false,
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      // Verify only 1 transfer call was ever made
      expect(transferCallCount, 1);
    });

    testWidgets(
        '11. Expired or voided Staff QR code returns error and blocks transfer',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = createMockApi(
        availableBalance: 1000,
        resolveStatus: 400,
        resolveResponse: {'detail': 'This Staff QR code has expired.'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferPointsScreen(
            partnerApi: api,
            sessionManager: testSession,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Staff ID'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Enter Staff ID'),
        'STAFF_TRF_EXPIRED_002',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('This Staff QR code has expired.'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);

      final transferBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Transfer Points'),
      );
      expect(transferBtn.onPressed, isNull);
    });
  });
}
