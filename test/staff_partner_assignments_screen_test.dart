import 'dart:async';
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

  Map<String, dynamic> assignmentResponse({
    int id = 31,
    int staffId = 11,
    int partnerId = 21,
    bool isActive = true,
    String? deactivatedAt,
    int? deactivatedBy,
    String? deactivatedByName,
  }) =>
      {
        'id': id,
        'staff_id': staffId,
        'partner_id': partnerId,
        'assigned_at': '2025-05-20T10:00:00',
        'is_active': isActive,
        'deactivated_at': deactivatedAt,
        'deactivated_by': deactivatedBy,
        'deactivated_by_name': deactivatedByName,
        'staff': {
          'id': staffId,
          'name': 'Staff One',
          'mobile': '9000000011',
          'role': 'staff',
          'is_active': true,
          'staff_id': 'STF-11',
        },
        'partner': {
          'id': partnerId,
          'name': 'Partner One',
          'mobile': '9000000021',
          'role': 'partner',
          'is_active': true,
          'business_name': 'Partner Business',
          'partner_code': 'PAR-21',
        },
      };

  Future<AdminApi> createApi(MockClientHandler handler) async {
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
    return AdminApi(
      client: MockClient(handler),
      baseUrl: 'http://localhost',
      sessionManager: session,
    );
  }

  testWidgets('loads active choices and creates a persisted assignment',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var created = false;
    final api = await createApi((request) async {
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
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff Assignments'), findsOneWidget);
    expect(find.text('Assignments'), findsOneWidget);
    expect(
      find.text('There are no Staff-Partner assignments.'),
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
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'displays active and inactive status indicators with appropriate actions',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        return http.Response(
          jsonEncode([
            assignmentResponse(id: 1, isActive: true),
            assignmentResponse(id: 2, isActive: false),
          ]),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    // Verify indicators
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);

    // Active assignment has Deactivate button
    expect(find.byKey(const Key('deactivate_assignment_1')), findsOneWidget);
    // Inactive assignment has Reassign button
    expect(find.byKey(const Key('reassign_assignment_2')), findsOneWidget);
  });

  testWidgets(
      'deactivates an active assignment with confirmation and refreshes list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var isDeactivated = false;
    var listCallCount = 0;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        listCallCount++;
        return http.Response(
          jsonEncode([assignmentResponse(id: 31, isActive: !isDeactivated)]),
          200,
        );
      }
      if (request.url.path ==
              '/api/v1/admin/staff-partner-assignments/31/status' &&
          request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['is_active'], false);
        isDeactivated = true;
        return http.Response(
          jsonEncode(assignmentResponse(id: 31, isActive: false)),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(const Key('deactivate_assignment_31')), findsOneWidget);

    // Tap Deactivate
    await tester.tap(find.byKey(const Key('deactivate_assignment_31')));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Deactivate Assignment'), findsOneWidget);
    expect(
      find.textContaining('Are you sure you want to deactivate'),
      findsOneWidget,
    );

    // Confirm dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(isDeactivated, isTrue);
    expect(find.text('Assignment deactivated successfully'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.byKey(const Key('reassign_assignment_31')), findsOneWidget);
    expect(listCallCount, greaterThan(1));
  });

  testWidgets(
      'reassigns an inactive assignment via dialog creating a new assignment period and refreshes list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var isReassigned = false;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              if (!isReassigned)
                assignmentResponse(id: 31, isActive: false)
              else ...[
                assignmentResponse(id: 32, isActive: true),
                assignmentResponse(id: 31, isActive: false),
              ]
            ]),
            200,
          );
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['staff_id'], 11);
          expect(body['partner_id'], 21);
          isReassigned = true;
          return http.Response(
            jsonEncode(assignmentResponse(id: 32, isActive: true)),
            201,
          );
        }
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inactive'), findsOneWidget);
    expect(find.byKey(const Key('reassign_assignment_31')), findsOneWidget);

    // Tap Reassign
    await tester.tap(find.byKey(const Key('reassign_assignment_31')));
    await tester.pumpAndSettle();

    // Verify dialog explains new assignment period
    expect(find.text('Reassign Partner'), findsOneWidget);
    expect(
      find.textContaining('Reassignment creates a new assignment period rather than reopening this inactive record.'),
      findsOneWidget,
    );

    // Confirm dialog
    await tester.tap(find.byKey(const Key('confirm_reassign_button')));
    await tester.pumpAndSettle();

    expect(isReassigned, isTrue);
    expect(find.text('Partner reassigned successfully. New assignment period created.'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('canceling confirmation dialog does not update status',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var patchCalled = false;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        return http.Response(
          jsonEncode([assignmentResponse(id: 31, isActive: true)]),
          200,
        );
      }
      if (request.url.path ==
          '/api/v1/admin/staff-partner-assignments/31/status') {
        patchCalled = true;
        return http.Response(
          jsonEncode(assignmentResponse(id: 31, isActive: false)),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deactivate_assignment_31')));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(patchCalled, isFalse);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('displays API error clearly when status update fails',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        return http.Response(
          jsonEncode([assignmentResponse(id: 31, isActive: true)]),
          200,
        );
      }
      if (request.url.path ==
          '/api/v1/admin/staff-partner-assignments/31/status') {
        return http.Response(
          jsonEncode({
            'detail':
                'Assignment deactivation failed on server',
          }),
          400,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deactivate_assignment_31')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Assignment deactivation failed on server'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'handles filter change failure without displaying stale assignments',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var initialLoadDone = false;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (!initialLoadDone) {
          initialLoadDone = true;
          return http.Response(
            jsonEncode([assignmentResponse(id: 31, isActive: true)]),
            200,
          );
        }
        return http.Response(
          jsonEncode({'detail': 'Failed to load assignments for selected filter'}),
          400,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial active assignment is displayed
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Partner Business'), findsOneWidget);

    // Change filter to 'Inactive'
    await tester.tap(find.byKey(const Key('assignment_status_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactive').last);
    await tester.pumpAndSettle();

    // Stale assignments from previous filter must NOT be displayed
    expect(find.text('Partner Business'), findsNothing);
    expect(find.text('Active'), findsNothing);

    // Verify error banner is visible with error message
    expect(
      find.text('Failed to load assignments for selected filter'),
      findsOneWidget,
    );
  });

  testWidgets(
      'handles overlapping filter requests and discards out-of-order responses',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final completerInactive = Completer<http.Response>();
    final completerActive = Completer<http.Response>();

    var initialLoad = true;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (initialLoad) {
          initialLoad = false;
          return http.Response(
            jsonEncode([assignmentResponse(id: 31, isActive: true)]),
            200,
          );
        }
        final isActiveQuery = request.url.queryParameters['is_active'];
        if (isActiveQuery == 'false') {
          return completerInactive.future;
        } else if (isActiveQuery == 'true') {
          return completerActive.future;
        }
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Change filter to 'Inactive' (triggers request 1)
    await tester.tap(find.byKey(const Key('assignment_status_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactive').last);
    await tester.pump();

    // 2. Quickly change filter to 'Active' (triggers request 2)
    await tester.tap(find.byKey(const Key('assignment_status_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active').last);
    await tester.pump();

    // 3. Resolve request 2 (Active) FIRST
    completerActive.complete(
      http.Response(
        jsonEncode([assignmentResponse(id: 99, isActive: true)]),
        200,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Active result is displayed
    expect(find.text('Active assignments'), findsOneWidget);
    expect(find.byKey(const Key('deactivate_assignment_99')), findsOneWidget);

    // 4. Resolve older request 1 (Inactive) LATER
    completerInactive.complete(
      http.Response(
        jsonEncode([assignmentResponse(id: 88, isActive: false)]),
        200,
      ),
    );
    await tester.pumpAndSettle();

    // The older response must be discarded; screen must remain on Active results
    expect(find.text('Active assignments'), findsOneWidget);
    expect(find.byKey(const Key('deactivate_assignment_99')), findsOneWidget);
    expect(find.byKey(const Key('reactivate_assignment_88')), findsNothing);
  });

  testWidgets(
      'main assignment form displays the one-active-Staff explanation',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Staff members and Partners have many-to-many associations. A Partner can be associated with multiple Staff members, and a Staff member can manage multiple Partners.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'inactive assignment cards display deactivation metadata, date fallback, and admin info',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const utcDeactivatedAt = '2025-05-21T14:30:00Z';
    final localDt = DateTime.parse(utcDeactivatedAt).toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month - 1];
    final year = localDt.year;
    final hour = localDt.hour % 12 == 0 ? 12 : localDt.hour % 12;
    final minute = localDt.minute.toString().padLeft(2, '0');
    final ampm = localDt.hour >= 12 ? 'PM' : 'AM';
    final expectedLocalDateStr = '$day $month $year, $hour:$minute $ampm';

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        return http.Response(
          jsonEncode([
            // Assignment 1: Inactive with explicit UTC date and admin name
            assignmentResponse(
              id: 101,
              isActive: false,
              deactivatedAt: utcDeactivatedAt,
              deactivatedBy: 1,
              deactivatedByName: 'Admin Alice',
            ),
            // Assignment 2: Inactive with null date and admin ID fallback
            assignmentResponse(
              id: 102,
              isActive: false,
              deactivatedAt: null,
              deactivatedBy: 7,
              deactivatedByName: null,
            ),
          ]),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify card 101 displays formatted local deactivation date and deactivating admin name
    expect(find.text('Deactivated: $expectedLocalDateStr'), findsOneWidget);
    expect(find.text('Deactivated by: Admin Alice'), findsOneWidget);

    // Scroll to reveal card 102
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // 2. Verify card 102 displays clear fallback for null date and admin ID label
    expect(find.text('Deactivated: Unavailable'), findsOneWidget);
    expect(find.text('Deactivated by: Admin #7'), findsOneWidget);
  });

  testWidgets(
      'reassign dialog safely handles inactive/absent staff ID without dropdown assertion',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var isReassigned = false;
    Map<String, dynamic>? postedBody;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        // Active staff list contains ONLY Staff ID 11
        return http.Response(
          jsonEncode(
              role == 'staff' ? userList(staffItem) : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              // Inactive assignment references deactivated Staff ID 99 (absent from active staff list)
              assignmentResponse(
                id: 41,
                isActive: false,
                staffId: 99,
                partnerId: 21,
              ),
            ]),
            200,
          );
        }
        if (request.method == 'POST') {
          postedBody = jsonDecode(request.body) as Map<String, dynamic>;
          isReassigned = true;
          return http.Response(
            jsonEncode(assignmentResponse(id: 42, isActive: true, staffId: 11)),
            201,
          );
        }
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reassign_assignment_41')), findsOneWidget);

    // Tap Reassign button - must NOT throw dropdown assertion error
    await tester.tap(find.byKey(const Key('reassign_assignment_41')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reassign Partner'), findsOneWidget);

    // Initial selection is empty -> Confirm button is disabled
    final confirmButton = tester.widget<ElevatedButton>(find.byKey(const Key('confirm_reassign_button')));
    expect(confirmButton.onPressed, isNull);

    // Select active Staff 11 from dropdown
    await tester.tap(find.byKey(const Key('reassign_staff_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff One (STF-11)').last);
    await tester.pumpAndSettle();

    // Confirm button is now enabled
    final enabledConfirmButton = tester.widget<ElevatedButton>(find.byKey(const Key('confirm_reassign_button')));
    expect(enabledConfirmButton.onPressed, isNotNull);

    // Tap confirm
    await tester.tap(find.byKey(const Key('confirm_reassign_button')));
    await tester.pumpAndSettle();

    expect(isReassigned, isTrue);
    expect(postedBody, {'staff_id': 11, 'partner_id': 21});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reassign dialog shows explanatory message and disables confirm when no active staff exist',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var postCalled = false;

    final api = await createApi((request) async {
      if (request.url.path == '/api/v1/admin/users') {
        final role = request.url.queryParameters['role'];
        // Return empty paginated items when role == 'staff'
        return http.Response(
          jsonEncode(role == 'staff'
              ? {
                  'items': [],
                  'total': 0,
                  'page': 1,
                  'page_size': 100,
                  'total_pages': 1,
                }
              : userList(partnerItem)),
          200,
        );
      }
      if (request.url.path == '/api/v1/admin/staff-partner-assignments') {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              assignmentResponse(
                id: 51,
                isActive: false,
                staffId: 99,
                partnerId: 21,
              ),
            ]),
            200,
          );
        }
        if (request.method == 'POST') {
          postCalled = true;
          return http.Response(jsonEncode({}), 201);
        }
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StaffPartnerAssignmentsScreen(adminApi: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reassign_assignment_51')), findsOneWidget);

    // Tap Reassign button
    await tester.ensureVisible(find.byKey(const Key('reassign_assignment_51')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reassign_assignment_51')));
    await tester.pumpAndSettle();

    // Verify explanatory message appears in the dialog
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('No active Staff accounts are available.'),
      ),
      findsOneWidget,
    );

    // Verify confirm button is disabled
    final confirmButton = tester.widget<ElevatedButton>(find.byKey(const Key('confirm_reassign_button')));
    expect(confirmButton.onPressed, isNull);

    // Close dialog via cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify no POST request was made
    expect(postCalled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
