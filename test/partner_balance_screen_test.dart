import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/services/partner_api.dart';
import 'package:score_app/core/services/partner_order_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/balance/partner_balance_screen.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late PartnerSessionManager sessionManager;

  setUp(() async {
    sessionManager = PartnerSessionManager();
    await sessionManager.saveSession(
      token: 'valid-partner-token',
      user: const PartnerUser(
        id: 10,
        name: 'Apex Motors Partner',
        mobile: '9800000001',
        role: 'partner',
      ),
    );
  });

  group('Partner Balance Screen Tests', () {
    testWidgets('1. Displays loading state while balance API is in flight',
        (tester) async {
      _setPhoneSize(tester);
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/orders/dashboard/stats') {
          return completer.future;
        }
        return http.Response('Not Found', 404);
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pump();

      // Loading indicator must be visible while request is pending
      expect(
        find.byKey(const Key('partner-balance-loading-indicator')),
        findsOneWidget,
      );

      // Complete request
      completer.complete(
        http.Response(
          jsonEncode({
            'total_points': 500,
            'points_used': 150,
            'remaining_balance': 350,
            'total_orders': 4,
            'pending_orders': 1,
            'processing_orders': 1,
            'dispatched_orders': 1,
            'delivered_orders': 1,
            'cancelled_orders': 0,
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      // Loading indicator disappears and values render
      expect(
        find.byKey(const Key('partner-balance-loading-indicator')),
        findsNothing,
      );
      expect(find.text('500'), findsAtLeastNWidgets(1));
      expect(find.text('150'), findsAtLeastNWidgets(1));
      expect(find.text('350'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Correctly renders earned, spent, and remaining balance from API',
        (tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/orders/dashboard/stats');
        expect(request.headers['Authorization'], 'Bearer valid-partner-token');

        return http.Response(
          jsonEncode({
            'total_points': 1250,
            'points_used': 450,
            'remaining_balance': 800,
            'total_orders': 0,
            'pending_orders': 0,
            'processing_orders': 0,
            'dispatched_orders': 0,
            'delivered_orders': 0,
            'cancelled_orders': 0,
          }),
          200,
        );
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1250'), findsWidgets);
      expect(find.text('450'), findsWidgets);
      expect(find.text('800'), findsWidgets);
      expect(find.text('Points Earned'), findsWidgets);
      expect(find.text('Points Spent'), findsWidgets);
      expect(find.text('Remaining Balance'), findsWidgets);
      expect(find.text('Points Earned / Total Points'), findsOneWidget);
      expect(find.text('Points Spent / Points Used'), findsOneWidget);
    });

    testWidgets('3. Correctly renders zero or empty balance values',
        (tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'total_points': 0,
            'points_used': 0,
            'remaining_balance': 0,
            'total_orders': 0,
            'pending_orders': 0,
            'processing_orders': 0,
            'dispatched_orders': 0,
            'delivered_orders': 0,
            'cancelled_orders': 0,
          }),
          200,
        );
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(find.byKey(const Key('partner-balance-error-state')), findsNothing);
    });

    testWidgets('4. Displays error state with retry button on API failure and retries successfully',
        (tester) async {
      _setPhoneSize(tester);
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'Failed to retrieve balance summary'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'total_points': 600,
            'points_used': 100,
            'remaining_balance': 500,
            'total_orders': 0,
            'pending_orders': 0,
            'processing_orders': 0,
            'dispatched_orders': 0,
            'delivered_orders': 0,
            'cancelled_orders': 0,
          }),
          200,
        );
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state must be visible
      expect(
        find.byKey(const Key('partner-balance-error-state')),
        findsOneWidget,
      );
      expect(
        find.text('Failed to retrieve balance summary'),
        findsOneWidget,
      );

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Error banner should be dismissed and balance populated
      expect(
        find.byKey(const Key('partner-balance-error-state')),
        findsNothing,
      );
      expect(find.text('600'), findsWidgets);
      expect(find.text('100'), findsWidgets);
      expect(find.text('500'), findsWidgets);
    });

    testWidgets('5. Pull-to-refresh re-fetches fresh balance', (tester) async {
      _setPhoneSize(tester);
      var fetchCount = 0;

      final mockClient = MockClient((request) async {
        fetchCount++;
        return http.Response(
          jsonEncode({
            'total_points': 1000,
            'points_used': fetchCount * 100,
            'remaining_balance': 1000 - (fetchCount * 100),
            'total_orders': 0,
            'pending_orders': 0,
            'processing_orders': 0,
            'dispatched_orders': 0,
            'delivered_orders': 0,
            'cancelled_orders': 0,
          }),
          200,
        );
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsWidgets);
      expect(find.text('900'), findsWidgets);

      // Trigger pull-to-refresh
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('200'), findsWidgets);
      expect(find.text('800'), findsWidgets);
      expect(fetchCount, 2);
    });

    testWidgets('6. Balance reflects updated deductions after a points transfer',
        (tester) async {
      _setPhoneSize(tester);
      var transferPerformed = false;

      final mockClient = MockClient((request) async {
        final spent = transferPerformed ? 300 : 100;
        final remaining = 1000 - spent;

        return http.Response(
          jsonEncode({
            'total_points': 1000,
            'points_used': spent,
            'remaining_balance': remaining,
            'total_orders': 0,
            'pending_orders': 0,
            'processing_orders': 0,
            'dispatched_orders': 0,
            'delivered_orders': 0,
            'cancelled_orders': 0,
          }),
          200,
        );
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsWidgets);
      expect(find.text('900'), findsWidgets);

      // Simulate a Partner -> Staff transfer occurs
      transferPerformed = true;

      // Trigger refresh
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('300'), findsWidgets);
      expect(find.text('700'), findsWidgets);
    });

    testWidgets('7. Balance values are 100% mathematically consistent with Points History',
        (tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/orders/dashboard/stats') {
          return http.Response(
            jsonEncode({
              'total_points': 300,
              'points_used': 80,
              'remaining_balance': 220,
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

        if (request.url.path == '/api/v1/partner/points-history') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'tr-1',
                  'transaction_type': 'transfer_sent',
                  'direction': 'debit',
                  'points': -80,
                  'amount': 80,
                  'title': 'Points Transferred to Vikram Staff',
                  'created_at': '2026-11-10T11:00:00Z',
                },
                {
                  'id': 'pt-1',
                  'transaction_type': 'qr_scan',
                  'direction': 'credit',
                  'points': 300,
                  'amount': 300,
                  'title': 'Points Earned (Product QR)',
                  'created_at': '2026-11-10T10:00:00Z',
                },
              ],
              'total': 2,
              'page': 1,
              'page_size': 20,
              'total_pages': 1,
              'has_next': false,
              'has_prev': false,
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final orderApi = PartnerOrderApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );
      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      // Verify balance screen
      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            orderApi: orderApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('300'), findsWidgets);
      expect(find.text('80'), findsWidgets);
      expect(find.text('220'), findsWidgets);

      // Also verify history API response matches these numbers exactly
      final hist = await partnerApi.getPointsHistory();
      final totalCredits = hist.items
          .where((it) => it.isCredit)
          .fold<int>(0, (sum, it) => sum + it.amount);
      final totalDebits = hist.items
          .where((it) => it.isDebit)
          .fold<int>(0, (sum, it) => sum + it.amount);
      final netPoints = hist.items.fold<int>(0, (sum, it) => sum + it.points);

      expect(totalCredits, 300);
      expect(totalDebits, 80);
      expect(netPoints, 220);
    });

    testWidgets('8. No misleading product QR scanner action is present',
        (tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerBalanceScreen(
            sessionManager: sessionManager,
            pointsEarned: '500',
            pointsSpent: '100',
            remainingBalance: '400',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product QR scanner button must be gone
      expect(find.byKey(const Key('partner_scan_product_qr_button')), findsNothing);
      expect(find.text('Scan Product QR Code'), findsNothing);

      // Disabled Invoice QR action is present instead
      final invoiceBtn = find.byKey(const Key('partner_scan_invoice_qr_button'));
      expect(invoiceBtn, findsOneWidget);
      expect(find.text('Scan Invoice QR Code (Coming Soon)'), findsOneWidget);
    });

    testWidgets('9. Navigation from PartnerHomeScreen and back button returns to Home',
        (tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      final balanceCard = find.text('Balance');
      expect(balanceCard, findsOneWidget);

      await tester.ensureVisible(balanceCard);
      await tester.tap(balanceCard);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerBalanceScreen), findsOneWidget);
      expect(find.text('Points Earned'), findsWidgets);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
