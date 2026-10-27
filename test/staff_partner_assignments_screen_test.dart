import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/users/staff_partner_assignments_screen.dart';

void main() {
  const staffItem = {
    'id': 11,
    'name': 'Staff One',
    'mobile': '9000000011',
    'role': 'staff',
    'is_active': true,
    'staff_id': 'STF-11',
  };
  const partnerItem = {
    'id': 21,
    'name': 'Partner One',
    'mobile': '9000000021',
    'role': 'partner',
    'is_active': true,
    'business_name': 'Partner Business',
    'partner_code': 'PAR-21',
  };

  Map<String, dynamic> userList(Map<String, dynamic> user) => {
        'items': [user],
        'total': 1,
        'page': 1,
        'page_size': 100,
        'total_pages': 1,
      };

  Map<String, dynamic> assignmentResponse() => {
        'id': 31,
        'staff_id': 11,
        'partner_id': 21,
        'assigned_at': '2025-05-20T10:00:00',
        'is_active': true,
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

  testWidgets('loads active choices and creates a persisted assignment',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var created = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        expect(request.url.queryParameters['is_active'], 'true');
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (request.method == 'POST') {
          created = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, {'staff_id': 11, 'partner_id': 21});
          return http.Response(jsonEncode(assignmentResponse()), 201);
        }
        expect(request.url.queryParameters['is_active'], 'true');
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('Not found', 404);
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

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(
          adminApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff Assignments'), findsOneWidget);
    expect(find.text('Active assignments'), findsOneWidget);
    expect(
      find.text('There are no active Staff-Partner assignments.'),
      findsOneWidget,
    );

    final dropdowns = find.byType(DropdownButtonFormField<int>);
    await tester.tap(dropdowns.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff One (STF-11)').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partner Business (Partner One)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create assignment'));
    await tester.pumpAndSettle();

    expect(created, isTrue);
    expect(find.text('Partner Business'), findsOneWidget);
    expect(find.textContaining('Staff: Staff One'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
