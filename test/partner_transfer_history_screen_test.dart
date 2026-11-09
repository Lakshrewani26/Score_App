import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/services/partner_api.dart';
import 'package:score_app/core/services/partner_session_manager.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_history_screen.dart';

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

  group('Partner Transfer History Screen Tests', () {
    testWidgets('1. Displays loading state while history API request is in flight',
        (tester) async {
      _setPhoneSize(tester);
      final completer = Completer<http.Response>();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/partner/points-history') {
          return completer.future;
        }
        return http.Response('Not Found', 404);
      });

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pump();

      // Loading indicator must be visible while request is pending
      expect(
        find.byKey(const Key('partner-history-loading-indicator')),
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
        find.byKey(const Key('partner-history-loading-indicator')),
        findsNothing,
      );
    });

    testWidgets(
        '2. Successfully renders populated history with credit (+) and debit (−) formatting',
        (tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/partner/points-history');
        expect(request.headers['Authorization'], 'Bearer valid-partner-token');

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
                'description':
                    'Transferred 40 points to Vikram Staff (STF-001)',
                'reference_id': 'IDEM-TR-40',
                'recipient_name': 'Vikram Staff',
                'recipient_staff_id': 'STF-001',
                'created_at': '2026-11-10T11:00:00Z',
              },
              {
                'id': 'pt-1',
                'transaction_type': 'qr_scan',
                'direction': 'credit',
                'points': 50,
                'amount': 50,
                'title': 'Points Earned (Product QR)',
                'description': 'Product QR scan: PRD-QR-50',
                'reference_id': 'PRD-QR-50',
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
      });

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify debit item with − sign and recipient details
      expect(find.text('Points Transferred to Vikram Staff'), findsOneWidget);
      expect(find.text('−40 pts'), findsOneWidget);
      expect(find.text('To: Vikram Staff (STF-001)'), findsOneWidget);
      expect(find.text('Ref: IDEM-TR-40'), findsOneWidget);

      // Verify credit item with + sign and reference
      expect(find.text('Points Earned (Product QR)'), findsOneWidget);
      expect(find.text('+50 pts'), findsOneWidget);
      expect(find.text('Ref: PRD-QR-50'), findsOneWidget);

      // Verify direction icons
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('3. Renders honest empty state when no transactions exist',
        (tester) async {
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

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('partner-transfer-history-empty-state')),
        findsOneWidget,
      );
      expect(find.text('No points history available yet.'), findsOneWidget);
    });

    testWidgets('4. Displays error state with retry button on API failure',
        (tester) async {
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
                'id': 'pt-99',
                'transaction_type': 'qr_scan',
                'direction': 'credit',
                'points': 100,
                'amount': 100,
                'title': 'Points Earned (Product QR)',
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
      });

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('partner-history-error-state')),
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
        find.byKey(const Key('partner-history-error-state')),
        findsNothing,
      );
      expect(find.text('+100 pts'), findsOneWidget);
    });

    testWidgets('5. Paginates history when Load More is tapped',
        (tester) async {
      _setPhoneSize(tester);

      final mockClient = MockClient((request) async {
        final page = request.url.queryParameters['page'] ?? '1';

        if (page == '1') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'pt-1',
                  'transaction_type': 'qr_scan',
                  'direction': 'credit',
                  'points': 50,
                  'amount': 50,
                  'title': 'Page 1 Transaction',
                  'created_at': '2026-11-10T10:00:00Z',
                },
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
                  'id': 'tr-2',
                  'transaction_type': 'transfer_sent',
                  'direction': 'debit',
                  'points': -25,
                  'amount': 25,
                  'title': 'Page 2 Transaction',
                  'created_at': '2026-11-10T09:00:00Z',
                },
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
      });

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page 1 Transaction'), findsOneWidget);
      expect(find.text('Load More'), findsOneWidget);

      // Tap Load More
      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();

      // Both Page 1 and Page 2 items should now be in the list
      expect(find.text('Page 1 Transaction'), findsOneWidget);
      expect(find.text('Page 2 Transaction'), findsOneWidget);
      expect(find.text('−25 pts'), findsOneWidget);
      expect(find.text('Load More'), findsNothing);
    });

    testWidgets('6. Pull-to-refresh reloads transaction list', (tester) async {
      _setPhoneSize(tester);
      var refreshCount = 0;

      final mockClient = MockClient((request) async {
        refreshCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'pt-$refreshCount',
                'transaction_type': 'qr_scan',
                'direction': 'credit',
                'points': 50 * refreshCount,
                'amount': 50 * refreshCount,
                'title': 'Scan Batch $refreshCount',
                'created_at': '2026-11-10T10:00:00Z',
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
      });

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Batch 1'), findsOneWidget);

      // Pull down to trigger refresh
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan Batch 2'), findsOneWidget);
      expect(refreshCount, 2);
    });
  });

  group('Navigation & Viewport Tests', () {
    testWidgets(
        '7. Navigation from PartnerHomeScreen opens PartnerTransferHistoryScreen',
        (tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      final historyCard = find.text('Points History');
      expect(historyCard, findsOneWidget);

      await tester.ensureVisible(historyCard);
      await tester.tap(historyCard);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);
      expect(
          find.text('View your recent transfer transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '8. Back button returns to PartnerHomeScreen and Profile nav works',
        (tester) async {
      _setPhoneSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerHomeScreen(sessionManager: sessionManager),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Transfer History
      final historyCard = find.text('Points History');
      await tester.ensureVisible(historyCard);
      await tester.tap(historyCard);
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);

      // Test Profile navigation
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerProfileScreen), findsOneWidget);

      // Tapping Home on Profile pops back to PartnerTransferHistoryScreen
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);

      // Test top-left Back button returning to PartnerHomeScreen
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PartnerHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Empty state renders cleanly on compact mobile viewports',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      final partnerApi = PartnerApi(
        client: mockClient,
        baseUrl: 'http://test.local',
        sessionManager: sessionManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PartnerTransferHistoryScreen(
            sessionManager: sessionManager,
            partnerApi: partnerApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);
      expect(
        find.byKey(const Key('partner-transfer-history-empty-state')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
