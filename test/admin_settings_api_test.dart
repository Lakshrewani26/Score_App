import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_settings_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/admin_settings_api.dart';

void main() {
  const dummyToken = 'valid-test-admin-jwt-token';

  Future<AdminSessionManager> createSessionWithToken([String token = dummyToken]) async {
    final storage = InMemoryAdminTokenStorage();
    await storage.saveToken(token);
    return AdminSessionManager(tokenStorage: storage);
  }

  group('AdminSettingsModels Unit Tests', () {
    test('AdminSystemInfo serializes and deserializes correctly', () {
      final json = {
        'app_name': 'Score API',
        'environment': 'development',
        'api_version': '1.0.0 (Phase 7)',
        'database_status': 'connected',
      };

      final info = AdminSystemInfo.fromJson(json);
      expect(info.appName, 'Score API');
      expect(info.environment, 'development');
      expect(info.apiVersion, '1.0.0 (Phase 7)');
      expect(info.databaseStatus, 'connected');

      final serialized = info.toJson();
      expect(serialized['app_name'], 'Score API');
      expect(serialized['environment'], 'development');
      expect(serialized['api_version'], '1.0.0 (Phase 7)');
      expect(serialized['database_status'], 'connected');
    });

    test('AdminPointsRule parses all fields and computed properties correctly', () {
      final json = {
        'id': 42,
        'rule_name': 'Product QR Genuine Parts Reward',
        'rule_description': 'Award points when authentic product QR code is scanned',
        'category': 'product_qr_scan',
        'points_awarded': 50,
        'points_required': null,
        'min_transaction_value': '1000.50',
        'max_transaction_value': '50000.00',
        'effective_from': '2026-01-01T00:00:00Z',
        'effective_to': '2026-12-31T23:59:59Z',
        'is_active': true,
        'created_at': '2026-01-01T12:00:00Z',
        'updated_at': '2026-01-02T12:00:00Z',
        'created_by': 1,
        'updated_by': 1,
        'created_by_name': 'Super Admin',
        'updated_by_name': 'Super Admin',
      };

      final rule = AdminPointsRule.fromJson(json);
      expect(rule.id, 42);
      expect(rule.ruleName, 'Product QR Genuine Parts Reward');
      expect(rule.category, 'product_qr_scan');
      expect(rule.categoryLabel, 'Product QR Scan');
      expect(rule.pointsAwarded, 50);
      expect(rule.pointsRequired, isNull);
      expect(rule.minTransactionValue, 1000.50);
      expect(rule.maxTransactionValue, 50000.00);
      expect(rule.isActive, isTrue);
      expect(rule.createdByName, 'Super Admin');
      expect(rule.updatedByName, 'Super Admin');

      // Test category labels for other categories
      expect(
        rule.copyWith(category: 'invoice_qr_scan').categoryLabel,
        'Invoice QR Scan',
      );
      expect(
        rule.copyWith(category: 'redemption').categoryLabel,
        'Points Redemption',
      );
      expect(
        rule.copyWith(category: 'customer_to_partner_transfer').categoryLabel,
        'Customer → Partner Transfer',
      );
      expect(
        rule.copyWith(category: 'partner_to_staff_transfer').categoryLabel,
        'Partner → Staff Transfer',
      );
    });

    test('AdminPointsRulePayload formats JSON and handles nullable fields correctly', () {
      final payload = AdminPointsRulePayload(
        ruleName: '   Mechanic Scan Bonus   ',
        ruleDescription: '  Qualifying invoice scan  ',
        category: 'invoice_qr_scan',
        pointsAwarded: 100,
        minTransactionValue: 500.0,
        effectiveFrom: DateTime.utc(2026, 6, 1),
        effectiveTo: DateTime.utc(2026, 12, 1),
        isActive: true,
      );

      final json = payload.toJson();
      expect(json['rule_name'], 'Mechanic Scan Bonus');
      expect(json['rule_description'], 'Qualifying invoice scan');
      expect(json['category'], 'invoice_qr_scan');
      expect(json['points_awarded'], 100);
      expect(json['points_required'], isNull);
      expect(json['min_transaction_value'], 500.0);
      expect(json['effective_from'], '2026-06-01T00:00:00.000Z');
      expect(json['effective_to'], '2026-12-01T00:00:00.000Z');
      expect(json['is_active'], isTrue);
    });
  });

  group('AdminSettingsApi Operations Tests', () {
    test('getSystemInfo fetches and parses system metadata', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/settings/system-info');
        expect(request.headers['Authorization'], 'Bearer $dummyToken');
        return http.Response(
          jsonEncode({
            'app_name': 'Score API',
            'environment': 'development',
            'api_version': '1.0.0 (Phase 7)',
            'database_status': 'connected',
          }),
          200,
        );
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final info = await api.getSystemInfo();
      expect(info.appName, 'Score API');
      expect(info.environment, 'development');
      expect(info.apiVersion, '1.0.0 (Phase 7)');
      expect(info.databaseStatus, 'connected');
    });

    test('getPointsRules sends query params and parses rule list', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/points-rules');
        expect(request.url.queryParameters['category'], 'product_qr_scan');
        expect(request.url.queryParameters['is_active'], 'true');
        expect(request.url.queryParameters['search'], 'genuine');

        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 10,
                'rule_name': 'Genuine Parts Scan',
                'category': 'product_qr_scan',
                'points_awarded': 50,
                'is_active': true,
                'created_at': '2026-01-01T00:00:00Z',
                'updated_at': '2026-01-01T00:00:00Z',
              }
            ],
            'total': 1,
          }),
          200,
        );
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final response = await api.getPointsRules(
        category: 'product_qr_scan',
        isActive: true,
        search: 'genuine',
      );

      expect(response.total, 1);
      expect(response.items.length, 1);
      expect(response.items.first.ruleName, 'Genuine Parts Scan');
    });

    test('createPointsRule sends POST and receives created rule', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/points-rules');
        expect(request.method, 'POST');
        final decoded = jsonDecode(request.body);
        expect(decoded['rule_name'], 'Partner Loyalty Bonus');
        expect(decoded['points_awarded'], 250);

        return http.Response(
          jsonEncode({
            'id': 15,
            'rule_name': 'Partner Loyalty Bonus',
            'category': 'invoice_qr_scan',
            'points_awarded': 250,
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'created_by': 1,
            'created_by_name': 'Super Admin',
          }),
          201,
        );
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final created = await api.createPointsRule(
        const AdminPointsRulePayload(
          ruleName: 'Partner Loyalty Bonus',
          category: 'invoice_qr_scan',
          pointsAwarded: 250,
        ),
      );

      expect(created.id, 15);
      expect(created.ruleName, 'Partner Loyalty Bonus');
      expect(created.createdByName, 'Super Admin');
    });

    test('updatePointsRule sends PATCH and receives updated rule', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/points-rules/15');
        expect(request.method, 'PATCH');
        final decoded = jsonDecode(request.body);
        expect(decoded['points_awarded'], 300);

        return http.Response(
          jsonEncode({
            'id': 15,
            'rule_name': 'Partner Loyalty Bonus',
            'category': 'invoice_qr_scan',
            'points_awarded': 300,
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-02T00:00:00Z',
            'updated_by_name': 'Super Admin',
          }),
          200,
        );
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final updated = await api.updatePointsRule(
        15,
        const AdminPointsRulePayload(
          ruleName: 'Partner Loyalty Bonus',
          category: 'invoice_qr_scan',
          pointsAwarded: 300,
        ),
      );

      expect(updated.pointsAwarded, 300);
      expect(updated.updatedByName, 'Super Admin');
    });

    test('updatePointsRuleStatus toggles active state', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/points-rules/15/status');
        expect(request.method, 'POST');
        final decoded = jsonDecode(request.body);
        expect(decoded['is_active'], false);

        return http.Response(
          jsonEncode({
            'id': 15,
            'rule_name': 'Partner Loyalty Bonus',
            'category': 'invoice_qr_scan',
            'is_active': false,
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-02T00:00:00Z',
          }),
          200,
        );
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final toggled = await api.updatePointsRuleStatus(15, false);
      expect(toggled.isActive, isFalse);
    });

    test('Throws AdminApiException 401 when token is missing', () async {
      final emptySession = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      final api = AdminSettingsApi(
        baseUrl: 'http://localhost:8000',
        sessionManager: emptySession,
      );

      expect(
        () => api.getSystemInfo(),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('Throws AdminApiException 403 on forbidden access', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Admin privileges required'}), 403);
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      expect(
        () => api.getPointsRules(),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('Throws AdminApiException 404 when rule not found', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Points rule not found'}), 404);
      });

      final api = AdminSettingsApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      expect(
        () => api.getPointsRuleDetail(9999),
        throwsA(isA<AdminApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('AdminApi forwards settings calls to AdminSettingsApi seamlessly', () async {
      final session = await createSessionWithToken();
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/settings/system-info') {
          return http.Response(
            jsonEncode({
              'app_name': 'Score API',
              'environment': 'development',
              'api_version': '1.0.0 (Phase 7)',
              'database_status': 'connected',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(
        client: client,
        baseUrl: 'http://localhost:8000',
        sessionManager: session,
      );

      final info = await adminApi.settings.getSystemInfo();
      expect(info.appName, 'Score API');
    });
  });
}
