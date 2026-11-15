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
}
