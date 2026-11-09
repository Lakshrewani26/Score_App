import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/services/customer_api.dart';
import 'package:score_app/core/services/customer_session_manager.dart';
import 'package:score_app/features/customer/balance/customer_balance_screen.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/transfer_history/customer_transfer_history_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late CustomerSessionManager sessionManager;

  setUp(() async {
    final storage = InMemoryCustomerTokenStorage();
    sessionManager = CustomerSessionManager(tokenStorage: storage);
    await sessionManager.saveSession(
      token: 'valid-test-token',
      user: const CustomerUser(
        id: 101,
        name: 'Ramesh Customer',
        mobile: '9800000001',
        role: 'customer',
      ),
    );
  });

  group('Customer Balance Screen Tests', () {
    testWidgets('1. Displays loading state while balance API is in flight', (tester) async {
      _setPhoneSize(tester);
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/customer/balance') {
          return completer.future;
        }
        return http.Response('Not Found', 404);
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerBalanceScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      // Pump initial frame to start async load
      await tester.pump();

      // Loading indicator must be visible while request is pending
      expect(
        find.byKey(const Key('customer-balance-loading-indicator')),
        findsOneWidget,
      );

      // Complete request
      completer.complete(
        http.Response(
          jsonEncode({
            'points_earned': 250,
            'points_spent': 50,
            'current_balance': 200,
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      // Loading indicator gone, data rendered
      expect(
        find.byKey(const Key('customer-balance-loading-indicator')),
        findsNothing,
      );
      expect(find.text('250'), findsAtLeastNWidgets(1));
      expect(find.text('50'), findsAtLeastNWidgets(1));
      expect(find.text('200'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. Successfully renders points earned, spent, and remaining balance from API', (tester) async {
      _setPhoneSize(tester);
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customer/balance');
        expect(request.headers['Authorization'], 'Bearer valid-test-token');
        return http.Response(
          jsonEncode({
            'points_earned': 1500,
            'points_spent': 450,
            'current_balance': 1050,
            'total_earned_points': 1500,
            'total_spent_points': 450,
            'remaining_balance': 1050,
          }),
          200,
        );
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerBalanceScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Points Earned'), findsAtLeastNWidgets(1));
      expect(find.text('Points Spent'), findsAtLeastNWidgets(1));
      expect(find.text('Remaining Balance'), findsAtLeastNWidgets(1));

      expect(find.text('1500'), findsAtLeastNWidgets(2)); // in summary card and breakdown
      expect(find.text('450'), findsAtLeastNWidgets(2));
      expect(find.text('1050'), findsAtLeastNWidgets(2));
    });

    testWidgets('3. Renders zero balance empty state correctly without errors', (tester) async {
      _setPhoneSize(tester);
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'points_earned': 0,
            'points_spent': 0,
            'current_balance': 0,
          }),
          200,
        );
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerBalanceScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsAtLeastNWidgets(3));
      expect(find.byKey(const Key('customer-balance-error-state')), findsNothing);
    });

    testWidgets('4. Displays error state with retry button on API error', (tester) async {
      _setPhoneSize(tester);
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'Balance service temporarily unavailable'}),
            503,
          );
        }
        return http.Response(
          jsonEncode({
            'points_earned': 300,
            'points_spent': 100,
            'current_balance': 200,
          }),
          200,
        );
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerBalanceScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state visible
      expect(
        find.byKey(const Key('customer-balance-error-state')),
        findsOneWidget,
      );
      expect(
        find.text('Balance service temporarily unavailable'),
        findsOneWidget,
      );

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // After retry succeeds, error is gone and balance is displayed
      expect(
        find.byKey(const Key('customer-balance-error-state')),
        findsNothing,
      );
      expect(find.text('300'), findsAtLeastNWidgets(1));
      expect(find.text('200'), findsAtLeastNWidgets(1));
    });
  });

  group('Customer Points History Screen Tests', () {
    testWidgets('5. Displays loading state while history API is in flight', (tester) async {
      _setPhoneSize(tester);
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/v1/customer/points-history')) {
          return completer.future;
        }
        return http.Response('Not Found', 404);
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerTransferHistoryScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pump();

      // History loading indicator must be present
      expect(
        find.byKey(const Key('customer-history-loading-indicator')),
        findsOneWidget,
      );

      completer.complete(
        http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0,
            'has_next': false,
            'has_prev': false,
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('customer-history-loading-indicator')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('customer-transfer-history-empty-state')),
        findsOneWidget,
      );
    });

    testWidgets('6. Successfully renders earned and spent history transactions', (tester) async {
      _setPhoneSize(tester);
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/customer/points-history');
        expect(request.headers['Authorization'], 'Bearer valid-test-token');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'tr-1',
                'transaction_type': 'transfer_sent',
                'direction': 'debit',
                'points': -50,
                'amount': 50,
                'title': 'Points Transferred to Apex Motors',
                'description': 'Customer points transfer to Apex Motors',
                'reference_id': 'IDEMP-TR-001',
                'recipient_name': 'Apex Motors',
                'created_at': '2026-11-10T09:30:00Z',
              },
              {
                'id': 'pt-1',
                'transaction_type': 'qr_scan',
                'direction': 'credit',
                'points': 100,
                'amount': 100,
                'title': 'Points Earned (Product QR)',
                'description': 'Product QR scan: PRD-TOKEN-100',
                'reference_id': 'PRD-TOKEN-100',
                'created_at': '2026-11-10T08:00:00Z',
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
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerTransferHistoryScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both items rendered
      expect(find.text('Points Transferred to Apex Motors'), findsOneWidget);
      expect(find.text('-50 pts'), findsOneWidget);
      expect(find.text('Ref: IDEMP-TR-001'), findsOneWidget);

      expect(find.text('Points Earned (Product QR)'), findsOneWidget);
      expect(find.text('+100 pts'), findsOneWidget);
      expect(find.text('Ref: PRD-TOKEN-100'), findsOneWidget);
    });

    testWidgets('7. Renders empty state when no transactions exist', (tester) async {
      _setPhoneSize(tester);
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [],
            'total': 0,
            'page': 1,
            'page_size': 20,
            'total_pages': 0,
            'has_next': false,
            'has_prev': false,
          }),
          200,
        );
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerTransferHistoryScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('customer-transfer-history-empty-state')),
        findsOneWidget,
      );
      expect(find.text('No points history available yet.'), findsOneWidget);
    });

    testWidgets('8. Displays error state with retry button on API failure', (tester) async {
      _setPhoneSize(tester);
      var callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'Failed to retrieve transaction log'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'pt-2',
                'transaction_type': 'qr_scan',
                'direction': 'credit',
                'points': 50,
                'amount': 50,
                'title': 'Points Earned (Product QR)',
                'created_at': '2026-11-10T10:00:00Z',
              }
            ],
            'total': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'has_next': false,
            'has_prev': false,
          }),
          200,
        );
      });

      final customerApi = CustomerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerTransferHistoryScreen(
            sessionManager: sessionManager,
            customerApi: customerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('customer-history-error-state')),
        findsOneWidget,
      );
      expect(
        find.text('Failed to retrieve transaction log'),
        findsOneWidget,
      );

      // Tap Retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('customer-history-error-state')),
        findsNothing,
      );
      expect(find.text('+50 pts'), findsOneWidget);
    });
  });

  group('Navigation from CustomerHomeScreen', () {
    testWidgets('9. Navigates to CustomerBalanceScreen and returns via back button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      final balanceBtn = find.text('Balance');
      expect(balanceBtn, findsOneWidget);
      await tester.ensureVisible(balanceBtn);
      await tester.pumpAndSettle();
      await tester.tap(balanceBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerBalanceScreen), findsOneWidget);
      expect(find.text('Points Breakdown'), findsOneWidget);

      // Top back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeScreen), findsOneWidget);
    });

    testWidgets('10. Navigates to CustomerTransferHistoryScreen and returns via back button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      final historyBtn = find.text('Points History');
      expect(historyBtn, findsOneWidget);
      await tester.ensureVisible(historyBtn);
      await tester.pumpAndSettle();
      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerTransferHistoryScreen), findsOneWidget);
      expect(find.text('Transfer History'), findsOneWidget);

      // Top back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerHomeScreen), findsOneWidget);
    });
  });
}
