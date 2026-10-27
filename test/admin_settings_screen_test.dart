import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/settings/admin_settings_screen.dart';
import 'package:score_app/features/admin/settings/widgets/admin_points_rule_dialog.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  Map<String, dynamic> mockSystemInfoJson() => {
        'app_name': 'Score API',
        'environment': 'development',
        'api_version': '1.0.0 (Phase 7)',
        'database_status': 'connected',
      };

  Map<String, dynamic> mockRuleJson({
    int id = 1,
    String name = 'Product Scan Reward',
    String category = 'product_qr_scan',
    int points = 50,
    bool isActive = true,
  }) =>
      {
        'id': id,
        'rule_name': name,
        'rule_description': 'Award loyalty points for scans',
        'category': category,
        'points_awarded': points,
        'points_required': null,
        'min_transaction_value': 100.0,
        'max_transaction_value': 5000.0,
        'effective_from': '2026-01-01T00:00:00Z',
        'effective_to': '2026-12-31T23:59:59Z',
        'is_active': isActive,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'created_by': 1,
        'created_by_name': 'Super Admin',
      };

  Widget buildTestScreen({
    required http.Client client,
    AdminSessionManager? sessionManager,
  }) {
    final session = sessionManager ??
        AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());

    final adminApi = AdminApi(
      client: client,
      baseUrl: 'http://localhost:8000',
      sessionManager: session,
    );

    return MaterialApp(
      home: AdminSettingsScreen(
        adminApi: adminApi,
        sessionManager: session,
      ),
    );
  }

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  group('AdminSettingsScreen Widget & Interaction Tests', () {
    testWidgets('1. Renders screen, System Information card, and Points Rules section',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          return http.Response(
            jsonEncode({
              'items': [mockRuleJson()],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Screen Header
      expect(find.text('System Settings'), findsOneWidget);
      expect(find.text('Security policies, app info & points rules'), findsOneWidget);
      expect(find.byKey(const Key('admin_settings_back_button')), findsOneWidget);

      // System Info Card
      expect(find.text('System Information'), findsOneWidget);
      expect(find.text('Score API'), findsOneWidget);
      expect(find.text('DEVELOPMENT'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('1.0.0 (Phase 7)'), findsOneWidget);

      // Points Rules Header & Rule Card
      expect(find.text('Points System Rules'), findsOneWidget);
      expect(find.byKey(const Key('create_points_rule_button')), findsOneWidget);
      expect(find.text('Product Scan Reward'), findsOneWidget);
      expect(find.text('Product QR Scan'), findsWidgets);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('2. Displays error card and retries when rules API fails',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      int rulesCallCount = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          rulesCallCount++;
          if (rulesCallCount == 1) {
            return http.Response(jsonEncode({'detail': 'Failed to load points rules'}), 500);
          }
          return http.Response(
            jsonEncode({
              'items': [mockRuleJson()],
              'total': 1,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // First call fails, showing error & Retry button
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Now rule is rendered successfully
      expect(find.text('Product Scan Reward'), findsOneWidget);
    });

    testWidgets('3. Displays empty state when no rules match filters',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          return http.Response(jsonEncode({'items': [], 'total': 0}), 200);
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      expect(find.text('No points rules found'), findsOneWidget);
      expect(find.text('Try adjusting your search or filters, or create a new rule.'),
          findsOneWidget);
    });

    testWidgets('4. Filter chips trigger updated query to API',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      String? requestedCategory;
      String? requestedActive;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules') {
          requestedCategory = request.url.queryParameters['category'];
          requestedActive = request.url.queryParameters['is_active'];
          return http.Response(jsonEncode({'items': [], 'total': 0}), 200);
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Tap 'Invoice QR' filter chip
      await tester.ensureVisible(find.text('Invoice QR'));
      await tester.tap(find.text('Invoice QR'));
      await tester.pumpAndSettle();
      expect(requestedCategory, 'invoice_qr_scan');

      // Tap 'Inactive Only' status chip
      await tester.ensureVisible(find.text('Inactive Only'));
      await tester.tap(find.text('Inactive Only'));
      await tester.pumpAndSettle();
      expect(requestedActive, 'false');
    });

    testWidgets('5. Create rule dialog opens, validates input, and submits successfully',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      bool createCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules' && request.method == 'GET') {
          return http.Response(jsonEncode({'items': [], 'total': 0}), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules' && request.method == 'POST') {
          createCalled = true;
          final body = jsonDecode(request.body);
          expect(body['rule_name'], 'New QR Bonus');
          expect(body['points_awarded'], 75);
          return http.Response(
            jsonEncode(mockRuleJson(name: 'New QR Bonus', points: 75)),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Open Create dialog
      await tester.ensureVisible(find.byKey(const Key('create_points_rule_button')));
      await tester.tap(find.byKey(const Key('create_points_rule_button')));
      await tester.pumpAndSettle();

      expect(find.text('Create Points Rule'), findsOneWidget);

      // Attempt submit without name -> validation error
      await tester.tap(find.byKey(const Key('save_rule_button')));
      await tester.pumpAndSettle();
      expect(find.text('Rule name is required'), findsOneWidget);

      // Fill in valid details
      await tester.enterText(find.byKey(const Key('rule_name_field')), 'New QR Bonus');
      await tester.enterText(find.byKey(const Key('points_awarded_field')), '75');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('save_rule_button')));
      await tester.pumpAndSettle();

      expect(createCalled, isTrue);
      expect(find.text('Points rule created successfully'), findsOneWidget);
    });

    testWidgets('6. Edit rule dialog opens prefilled and submits update',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      bool updateCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [mockRuleJson(id: 7, name: 'Initial Rule Name')],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/points-rules/7' && request.method == 'PATCH') {
          updateCalled = true;
          final body = jsonDecode(request.body);
          expect(body['rule_name'], 'Modified Rule Name');
          return http.Response(
            jsonEncode(mockRuleJson(id: 7, name: 'Modified Rule Name')),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Click Edit button
      await tester.ensureVisible(find.byKey(const Key('edit_rule_7')));
      await tester.tap(find.byKey(const Key('edit_rule_7')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Points Rule'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AdminPointsRuleDialog),
          matching: find.text('Initial Rule Name'),
        ),
        findsOneWidget,
      );

      // Modify rule name
      await tester.enterText(find.byKey(const Key('rule_name_field')), 'Modified Rule Name');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('save_rule_button')));
      await tester.pumpAndSettle();

      expect(updateCalled, isTrue);
      expect(find.text('Points rule updated successfully'), findsOneWidget);
    });

    testWidgets('7. Deactivate confirmation dialog toggles rule status',
        (WidgetTester tester) async {
      configureViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await session.saveSession(token: 'active_token', user: mockAdminUser);

      bool statusToggleCalled = false;

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(jsonEncode(mockSystemInfoJson()), 200);
        }
        if (request.url.path == '/api/v1/admin/points-rules' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [mockRuleJson(id: 3, name: 'Deactivate Target', isActive: true)],
              'total': 1,
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/points-rules/3/status') {
          statusToggleCalled = true;
          final body = jsonDecode(request.body);
          expect(body['is_active'], false);
          return http.Response(
            jsonEncode(mockRuleJson(id: 3, name: 'Deactivate Target', isActive: false)),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(buildTestScreen(client: client, sessionManager: session));
      await tester.pumpAndSettle();

      // Click Deactivate button
      await tester.ensureVisible(find.byKey(const Key('toggle_status_rule_3')));
      await tester.tap(find.byKey(const Key('toggle_status_rule_3')));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Deactivate Rule?'), findsOneWidget);

      // Confirm deactivation
      await tester.tap(find.byKey(const Key('confirm_status_toggle_button')));
      await tester.pumpAndSettle();

      expect(statusToggleCalled, isTrue);
      expect(find.text('Rule deactivated'), findsOneWidget);
    });
  });
}
