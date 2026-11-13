import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/points_history/staff_points_history_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late StaffSessionManager sessionManager;

  setUp(() async {
    sessionManager = StaffSessionManager(
      tokenStorage: InMemoryStaffTokenStorage(),
    );
    await sessionManager.saveSession(
      token: 'valid-staff-token',
      user: const StaffUser(
        id: 7,
        name: 'Vikram Staff',
        mobile: '9800000003',
        role: 'staff',
        isActive: true,
        staffId: 'STF-001',
      ),
    );
  });

  group('StaffPointsHistoryScreen Tests', () {
    testWidgets('1. Displays loading state while history request is in flight',
        (WidgetTester tester) async {
      _setPhoneSize(tester);
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/staff/points-history') {
          return completer.future;
        }
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 0,
              'points_spent': 0,
              'current_balance': 0,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pump();

      // Loading indicator must be visible while request is pending
      expect(
        find.byKey(const Key('staff-points-history-loading-indicator')),
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

      // Loading indicator gone after settlement
      expect(
        find.byKey(const Key('staff-points-history-loading-indicator')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Renders honest empty state when no transfers exist',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 0,
              'points_spent': 0,
              'current_balance': 0,
            }),
            200,
          );
        }
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

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);
      expect(find.text('Points History'), findsOneWidget);
      expect(find.text('View received points'), findsOneWidget);
      expect(
        find.byKey(const Key('staff-points-history-empty-state')),
        findsOneWidget,
      );
      expect(find.text('Points history is not available yet.'), findsOneWidget);
      expect(
        find.text('Received points are retained in Score.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('staff-balance-display')), findsOneWidget);
      expect(find.text('0 pts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3. Successfully renders populated history with positive transfer credit styling',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer valid-staff-token');
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 150,
              'points_spent': 0,
              'current_balance': 150,
              'total_earned_points': 150,
              'total_spent_points': 0,
              'remaining_balance': 150,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/staff/points-history') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'tr-1',
                  'transaction_type': 'transfer_received',
                  'direction': 'credit',
                  'points': 150,
                  'amount': 150,
                  'title': 'Points Received from Apex Motors Workshop',
                  'description': 'Loyalty transfer from partner',
                  'reference_id': 'tx-idem-150',
                  'sender_name': 'Apex Motors Workshop',
                  'created_at': '2026-11-10T12:00:00Z',
                },
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
        }
        return http.Response('Not Found', 404);
      });

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify positive transfer styling and content
      expect(
        find.text('Points Received from Apex Motors Workshop'),
        findsOneWidget,
      );
      expect(find.text('+150 pts'), findsOneWidget);
      expect(find.text('From: Apex Motors Workshop'), findsOneWidget);
      expect(find.text('Ref: tx-idem-150'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);

      // Verify balance and retained-in-Score explanation
      expect(find.text('150 pts'), findsOneWidget);
      expect(
        find.text('Received points are retained in Score.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Displays error state with retry button on API failure',
        (WidgetTester tester) async {
      _setPhoneSize(tester);
      var callCount = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 0,
              'points_spent': 0,
              'current_balance': 0,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/staff/points-history') {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({'detail': 'Failed to load points history'}),
              500,
            );
          }
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'tr-2',
                  'transaction_type': 'transfer_received',
                  'direction': 'credit',
                  'points': 50,
                  'amount': 50,
                  'title': 'Points Received from Zenith Spares',
                  'reference_id': 'tx-idem-50',
                  'sender_name': 'Zenith Spares',
                  'created_at': '2026-11-10T12:00:00Z',
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
        }
        return http.Response('Not Found', 404);
      });

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error state visible
      expect(
        find.byKey(const Key('staff-points-history-error-state')),
        findsOneWidget,
      );
      expect(find.text('Failed to load points history'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Now successfully rendered
      expect(
        find.byKey(const Key('staff-points-history-error-state')),
        findsNothing,
      );
      expect(
        find.text('Points Received from Zenith Spares'),
        findsOneWidget,
      );
      expect(find.text('+50 pts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Pull-to-refresh re-fetches history and balance',
        (WidgetTester tester) async {
      _setPhoneSize(tester);
      var historyFetches = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 80,
              'points_spent': 0,
              'current_balance': 80,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/staff/points-history') {
          historyFetches++;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'tr-3',
                  'transaction_type': 'transfer_received',
                  'direction': 'credit',
                  'points': 80,
                  'amount': 80,
                  'title': 'Points Received from Partner',
                  'created_at': '2026-11-10T12:00:00Z',
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
        }
        return http.Response('Not Found', 404);
      });

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(historyFetches, 1);
      expect(find.text('+80 pts'), findsOneWidget);

      // Trigger pull-to-refresh
      await tester.fling(
        find.byType(ListView),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pumpAndSettle();

      expect(historyFetches, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Supports pagination via Load More button',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/staff/balance') {
          return http.Response(
            jsonEncode({
              'points_earned': 70,
              'points_spent': 0,
              'current_balance': 70,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/staff/points-history') {
          final page = request.url.queryParameters['page'] ?? '1';
          if (page == '1') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'tr-10',
                    'transaction_type': 'transfer_received',
                    'direction': 'credit',
                    'points': 40,
                    'amount': 40,
                    'title': 'Points Received - Transfer A',
                    'created_at': '2026-11-10T12:00:00Z',
                  }
                ],
                'total': 2,
                'page': 1,
                'page_size': 1,
                'total_pages': 2,
                'has_next': true,
                'has_prev': false,
              }),
              200,
            );
          } else {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'tr-11',
                    'transaction_type': 'transfer_received',
                    'direction': 'credit',
                    'points': 30,
                    'amount': 30,
                    'title': 'Points Received - Transfer B',
                    'created_at': '2026-11-10T11:00:00Z',
                  }
                ],
                'total': 2,
                'page': 2,
                'page_size': 1,
                'total_pages': 2,
                'has_next': false,
                'has_prev': true,
              }),
              200,
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final staffApi = StaffApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPointsHistoryScreen(
            sessionManager: sessionManager,
            staffApi: staffApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 item rendered
      expect(find.text('Points Received - Transfer A'), findsOneWidget);
      expect(find.text('Points Received - Transfer B'), findsNothing);

      // Load More button visible
      final loadMoreFinder = find.byKey(const Key('staff-points-history-load-more'));
      expect(loadMoreFinder, findsOneWidget);

      await tester.tap(loadMoreFinder);
      await tester.pumpAndSettle();

      // Both items rendered
      expect(find.text('Points Received - Transfer A'), findsOneWidget);
      expect(find.text('Points Received - Transfer B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Top-left Back button returns to StaffHomeScreen',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Points\nHistory');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);

      final backButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Tapping Home bottom navigation returns to StaffHomeScreen',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Points\nHistory');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);

      final homeTab = find.text('Home');
      await tester.tap(homeTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '9. Tapping Profile bottom navigation navigates to StaffProfileScreen',
        (WidgetTester tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPointsHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
