import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';

void main() {
  Map<String, dynamic> assignmentJson({bool isActive = true}) => {
        'id': 31,
        'staff_id': 11,
        'partner_id': 21,
        'assigned_at': '2025-05-20T10:00:00',
        'is_active': isActive,
        'staff': {
          'id': 11,
          'name': 'Staff One',
          'mobile': '9000000011',
          'role': 'staff',
          'is_active': true,
          'staff_id': 'STF-11',
        },
        'partner': {
          'id': 21,
          'name': 'Partner One',
          'mobile': '9000000021',
          'role': 'partner',
          'is_active': true,
          'business_name': 'Partner Business',
          'partner_code': 'PAR-21',
        },
      };

  test('lists active assignments and creates assignment via Admin API',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer admin-token');
      expect(request.url.path, '/api/v1/admin/staff-partner-assignments');
      if (request.method == 'GET') {
        expect(request.url.queryParameters['is_active'], 'true');
        return http.Response(jsonEncode([assignmentJson()]), 200);
      }
      expect(request.method, 'POST');
      expect(
        jsonDecode(request.body),
        {'staff_id': 11, 'partner_id': 21},
      );
      return http.Response(jsonEncode(assignmentJson()), 201);
    });
    final session = AdminSessionManager();
    await session.saveSession(
      token: 'admin-token',
      user: const AdminUser(
        id: 1,
        name: 'Admin',
        mobile: '9000000001',
        role: 'admin',
        isActive: true,
      ),
    );
    final api = AdminApi(
      client: client,
      baseUrl: 'http://localhost',
      sessionManager: session,
    );

    final assignments = await api.getStaffPartnerAssignments(isActive: true);
    final created = await api.createStaffPartnerAssignment(
      staffId: 11,
      partnerId: 21,
    );

    expect(assignments, hasLength(1));
    expect(assignments.single, isA<AdminStaffPartnerAssignment>());
    expect(assignments.single.staff.staffId, 'STF-11');
    expect(created.partner.businessName, 'Partner Business');
  });

  test('deactivates and reactivates staff partner assignment via Admin API',
      () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer admin-token');
      expect(request.url.path,
          '/api/v1/admin/staff-partner-assignments/31/status');
      expect(request.method, 'PATCH');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['is_active'] == false) {
        return http.Response(jsonEncode(assignmentJson(isActive: false)), 200);
      } else {
        return http.Response(jsonEncode(assignmentJson(isActive: true)), 200);
      }
    });
    final session = AdminSessionManager();
    await session.saveSession(
      token: 'admin-token',
      user: const AdminUser(
        id: 1,
        name: 'Admin',
        mobile: '9000000001',
        role: 'admin',
        isActive: true,
      ),
    );
    final api = AdminApi(
      client: client,
      baseUrl: 'http://localhost',
      sessionManager: session,
    );

    final deactivated = await api.deactivateStaffPartnerAssignment(31);
    expect(deactivated.id, 31);
    expect(deactivated.isActive, isFalse);

    final reactivated = await api.reactivateStaffPartnerAssignment(31);
    expect(reactivated.id, 31);
    expect(reactivated.isActive, isTrue);
  });

  group('AdminStaffPartnerAssignment.fromJson', () {
    test('parses valid deactivated_at timestamp', () {
      final json = assignmentJson(isActive: false);
      json['deactivated_at'] = '2025-05-21T14:30:00Z';
      json['deactivated_by'] = 1;
      json['deactivated_by_name'] = 'Super Admin';

      final assignment = AdminStaffPartnerAssignment.fromJson(json);

      expect(assignment.deactivatedAt, DateTime.utc(2025, 5, 21, 14, 30));
      expect(assignment.deactivatedBy, 1);
      expect(assignment.deactivatedByName, 'Super Admin');
    });

    test('preserves null deactivated_at when field is null or absent', () {
      final jsonWithNull = assignmentJson(isActive: true);
      jsonWithNull['deactivated_at'] = null;

      final assignmentFromNull =
          AdminStaffPartnerAssignment.fromJson(jsonWithNull);
      expect(assignmentFromNull.deactivatedAt, isNull);

      final jsonAbsent = assignmentJson(isActive: true);
      jsonAbsent.remove('deactivated_at');

      final assignmentFromAbsent =
          AdminStaffPartnerAssignment.fromJson(jsonAbsent);
      expect(assignmentFromAbsent.deactivatedAt, isNull);
    });

    test(
        'throws FormatException when deactivated_at is malformed non-null string',
        () {
      final json = assignmentJson(isActive: false);
      json['deactivated_at'] = 'not-a-valid-timestamp';

      expect(
        () => AdminStaffPartnerAssignment.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'throws FormatException when deactivated_at is non-null and not a string',
        () {
      final json = assignmentJson(isActive: false);
      json['deactivated_at'] = 123456789;

      expect(
        () => AdminStaffPartnerAssignment.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves strict validation for assigned_at', () {
      final jsonMissingAssignedAt = assignmentJson();
      jsonMissingAssignedAt.remove('assigned_at');

      expect(
        () => AdminStaffPartnerAssignment.fromJson(jsonMissingAssignedAt),
        throwsA(isA<FormatException>()),
      );

      final jsonInvalidAssignedAt = assignmentJson();
      jsonInvalidAssignedAt['assigned_at'] = 'not-a-timestamp';

      expect(
        () => AdminStaffPartnerAssignment.fromJson(jsonInvalidAssignedAt),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
