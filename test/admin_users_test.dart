import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/admin/users/admin_users_screen.dart';
import 'package:score_app/features/admin/users/widgets/create_partner_dialog.dart';
import 'package:score_app/features/admin/users/widgets/create_staff_dialog.dart';
import 'package:score_app/features/admin/users/widgets/user_detail_sheet.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  Map<String, dynamic> mockPaginatedResponse({
    int total = 2,
    int page = 1,
    int pageSize = 20,
    int totalPages = 1,
    List<Map<String, dynamic>>? items,
  }) {
    return {
      'items': items ?? [
        {
          'id': 101,
          'name': 'Rajesh Partner',
          'mobile': '9812345678',
          'role': 'partner',
          'is_active': true,
          'created_at': '2026-10-25T10:00:00',
          'business_name': 'Rajesh Automobiles',
          'partner_code': 'PART001',
          'staff_id': null,
        },
        {
          'id': 102,
          'name': 'Suresh Staff',
          'mobile': '9898765432',
          'role': 'staff',
          'is_active': false,
          'created_at': '2026-10-25T11:00:00',
          'business_name': null,
          'partner_code': null,
          'staff_id': 'EMP042',
        },
      ],
      'total': total,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
    };
  }

  group('Admin Users Screen & Navigation Tests', () {
    testWidgets('Tapping User Management card on AdminHomeScreen navigates to AdminUsersScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users') {
          return http.Response(jsonEncode(mockPaginatedResponse()), 200);
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
            adminApi: adminApi,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify User Management tile is present with Manage badge
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);

      // Tap User Management
      await tester.tap(find.text('User Management'));
      await tester.pumpAndSettle();

      // Expect AdminUsersScreen
      expect(find.byType(AdminUsersScreen), findsOneWidget);
      expect(find.text('View, filter & manage accounts'), findsOneWidget);

      // Tapping back returns to AdminHomeScreen
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);
    });

    testWidgets('Renders paginated user list with role badges, status badges, and identifiers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify user names
      expect(find.text('Rajesh Partner'), findsOneWidget);
      expect(find.text('Suresh Staff'), findsOneWidget);

      // Verify mobile numbers
      expect(find.text('9812345678'), findsOneWidget);
      expect(find.text('9898765432'), findsOneWidget);

      // Verify identifiers
      expect(find.text('Partner Code: PART001'), findsOneWidget);
      expect(find.text('Staff ID: EMP042'), findsOneWidget);

      // Verify status badges
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Inactive'), findsWidgets);

      // Verify role badges
      expect(find.text('PARTNER'), findsOneWidget);
      expect(find.text('STAFF'), findsOneWidget);
    });

    testWidgets('Renders empty state when no users are returned', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(mockPaginatedResponse(total: 0, items: [])),
          200,
        );
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No users found'), findsOneWidget);
      expect(find.text('Try adjusting your search query or filters'), findsOneWidget);
    });

    testWidgets('Renders error state on API failure and allows retry', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Server Error', 500);
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect error state
      expect(find.text('Server error. Please try again later.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Now loaded successfully
      expect(find.text('Rajesh Partner'), findsOneWidget);
    });

    testWidgets('Search input debounces and sends search query parameter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      String? lastSearchParam;
      final client = MockClient((request) async {
        lastSearchParam = request.url.queryParameters['search'];
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastSearchParam, isNull);

      // Enter search text
      await tester.enterText(find.byType(TextField), 'Rajesh');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(lastSearchParam, 'Rajesh');

      // Clear search via clear icon button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(lastSearchParam, isNull);
    });

    testWidgets('Role and Status dropdown filters trigger refetch and reset to page 1', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      String? lastRoleParam;
      String? lastActiveParam;
      final client = MockClient((request) async {
        lastRoleParam = request.url.queryParameters['role'];
        lastActiveParam = request.url.queryParameters['is_active'];
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Change role to 'Partner'
      await tester.tap(find.text('All Roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner').last);
      await tester.pumpAndSettle();

      expect(lastRoleParam, 'partner');

      // Change status to 'Active'
      await tester.tap(find.text('All Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active').last);
      await tester.pumpAndSettle();

      expect(lastActiveParam, 'true');
    });

    testWidgets('Pagination navigation respects page boundaries and updates page param', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      int requestedPage = 1;
      final client = MockClient((request) async {
        requestedPage = int.parse(request.url.queryParameters['page'] ?? '1');
        return http.Response(
          jsonEncode(mockPaginatedResponse(total: 50, page: requestedPage, totalPages: 3)),
          200,
        );
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 of 3
      expect(find.text('Page 1 of 3 (50 total)'), findsOneWidget);

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(requestedPage, 2);
      expect(find.text('Page 2 of 3 (50 total)'), findsOneWidget);

      // Tap Next again
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(requestedPage, 3);
      expect(find.text('Page 3 of 3 (50 total)'), findsOneWidget);

      // Tap Previous
      await tester.tap(find.text('Prev'));
      await tester.pumpAndSettle();

      expect(requestedPage, 2);
      expect(find.text('Page 2 of 3 (50 total)'), findsOneWidget);
    });

    testWidgets('Tapping user opens UserDetailSheet with role-specific details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final partnerDetailJson = {
        'id': 101,
        'name': 'Rajesh Partner',
        'mobile': '9812345678',
        'role': 'partner',
        'is_active': true,
        'created_at': '2026-10-25T10:00:00',
        'business_name': 'Rajesh Automobiles',
        'partner_code': 'PART001',
        'customer_profile': null,
        'partner_profile': {
          'business_name': 'Rajesh Automobiles',
          'business_address': 'Plot 44, Industrial Area, Pune',
          'partner_code': 'PART001',
        },
        'staff_profile': null,
      };

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/101') {
          return http.Response(jsonEncode(partnerDetailJson), 200);
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Rajesh Partner card
      await tester.tap(find.text('Rajesh Partner'));
      await tester.pumpAndSettle();

      // UserDetailSheet should be displayed
      expect(find.byType(UserDetailSheet), findsOneWidget);
      expect(find.text('Account Information'), findsOneWidget);
      expect(find.text('Plot 44, Industrial Area, Pune'), findsOneWidget);
      expect(find.text('Deactivate Account'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(UserDetailSheet), findsNothing);
    });

    testWidgets('Create Partner validation, conflict error, and successful submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      bool returnConflict = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/partners' && request.method == 'POST') {
          if (returnConflict) {
            return http.Response(
              jsonEncode({'detail': 'A user with this mobile number already exists'}),
              409,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 201,
              'name': 'Gita Partner',
              'mobile': '9876543211',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-10-25T12:00:00',
              'business_name': 'Gita Spares',
              'partner_code': 'GIT001',
            }),
            201,
          );
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Create Partner button
      await tester.tap(find.text('Create Partner'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePartnerDialog), findsOneWidget);

      // 1. Submit empty form to trigger validation
      await tester.tap(find.byKey(const Key('submit_create_partner_button')));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Mobile number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      expect(find.text('Business name is required'), findsOneWidget);
      expect(find.text('Business address is required'), findsOneWidget);

      // 2. Fill in the fields
      await tester.enterText(find.byKey(const Key('partner_name_field')), 'Gita Partner');
      await tester.enterText(find.byKey(const Key('partner_mobile_field')), '9876543211');
      await tester.enterText(find.byKey(const Key('partner_password_field')), 'SecretPass@123');
      await tester.enterText(find.byKey(const Key('partner_business_name_field')), 'Gita Spares');
      await tester.enterText(find.byKey(const Key('partner_business_address_field')), '78 Market Street');

      // Scroll down to submit button and tap
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Test 409 conflict
      returnConflict = true;
      await tester.tap(find.byKey(const Key('submit_create_partner_button')));
      await tester.pumpAndSettle();

      // Scroll up to see error banner
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('A user with this mobile number already exists'), findsOneWidget);

      // Now successful submission
      returnConflict = false;
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit_create_partner_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePartnerDialog), findsNothing);
      expect(find.text('Partner account created successfully'), findsOneWidget);
    });

    testWidgets('Create Staff validation, conflict error, and successful submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      bool returnConflict = false;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/staff' && request.method == 'POST') {
          if (returnConflict) {
            return http.Response(
              jsonEncode({'detail': 'A staff member with this staff ID already exists'}),
              409,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 202,
              'name': 'Karan Staff',
              'mobile': '9876543299',
              'role': 'staff',
              'is_active': true,
              'created_at': '2026-10-25T12:00:00',
              'staff_id': 'EMP555',
            }),
            201,
          );
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Create Staff button
      await tester.tap(find.text('Create Staff'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateStaffDialog), findsOneWidget);

      // Submit empty
      await tester.tap(find.byKey(const Key('submit_create_staff_button')));
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Staff ID is required'), findsOneWidget);

      // Fill form
      await tester.enterText(find.byKey(const Key('staff_name_field')), 'Karan Staff');
      await tester.enterText(find.byKey(const Key('staff_mobile_field')), '9876543299');
      await tester.enterText(find.byKey(const Key('staff_password_field')), 'StaffPass@123');
      await tester.enterText(find.byKey(const Key('staff_id_field')), 'EMP555');

      // Test 409 conflict
      returnConflict = true;
      await tester.tap(find.byKey(const Key('submit_create_staff_button')));
      await tester.pumpAndSettle();

      expect(find.text('A staff member with this staff ID already exists'), findsOneWidget);

      // Successful submission
      returnConflict = false;
      await tester.tap(find.byKey(const Key('submit_create_staff_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateStaffDialog), findsNothing);
      expect(find.text('Staff account created successfully'), findsOneWidget);
    });

    testWidgets('Activate/Deactivate confirmation, API success and safeguard error dialogs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      String? safeguardDetail;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/101/status' && request.method == 'POST') {
          if (safeguardDetail != null) {
            return http.Response(
              jsonEncode({'detail': safeguardDetail}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 101,
              'name': 'Rajesh Partner',
              'mobile': '9812345678',
              'role': 'partner',
              'is_active': false,
              'created_at': '2026-10-25T10:00:00',
              'business_name': 'Rajesh Automobiles',
              'partner_code': 'PART001',
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/users/101') {
          return http.Response(
            jsonEncode({
              'id': 101,
              'name': 'Rajesh Partner',
              'mobile': '9812345678',
              'role': 'partner',
              'is_active': true,
              'created_at': '2026-10-25T10:00:00',
              'partner_profile': {
                'business_name': 'Rajesh Automobiles',
                'business_address': 'Address 1',
                'partner_code': 'PART001',
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open detail sheet
      await tester.tap(find.text('Rajesh Partner'));
      await tester.pumpAndSettle();

      // Tap Deactivate Account button
      await tester.tap(find.text('Deactivate Account'));
      await tester.pumpAndSettle();

      // Expect confirmation dialog
      expect(find.text('Are you sure you want to deactivate Rajesh Partner\'s account?'), findsOneWidget);

      // 1. Cancel does not call API
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate Account'), findsOneWidget);

      // 2. Trigger with safeguard error (e.g. self-deactivation)
      safeguardDetail = 'Cannot deactivate your own admin account';
      await tester.tap(find.text('Deactivate Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('Action Blocked'), findsOneWidget);
      expect(find.text('Cannot deactivate your own admin account'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // 3. Trigger last active admin safeguard
      safeguardDetail = 'Cannot deactivate the last active admin account';
      await tester.tap(find.text('Deactivate Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot deactivate the last active admin account'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // 4. Successful deactivation
      safeguardDetail = null;
      await tester.tap(find.text('Deactivate Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('Account deactivated successfully'), findsOneWidget);
      // Button text now toggled to Activate Account
      expect(find.text('Activate Account'), findsOneWidget);
    });

    testWidgets('Preventing accidental duplicate form submissions in CreatePartnerDialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'active_token', user: mockAdminUser);

      final completer = Completer<http.Response>();
      int requestCount = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users/partners' && request.method == 'POST') {
          requestCount++;
          return completer.future;
        }
        return http.Response(jsonEncode(mockPaginatedResponse()), 200);
      });

      final adminApi = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersScreen(
            adminApi: adminApi,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Partner'));
      await tester.pumpAndSettle();

      // Fill in fields
      await tester.enterText(find.byKey(const Key('partner_name_field')), 'Test Partner');
      await tester.enterText(find.byKey(const Key('partner_mobile_field')), '9876543211');
      await tester.enterText(find.byKey(const Key('partner_password_field')), 'Pass@123');
      await tester.enterText(find.byKey(const Key('partner_business_name_field')), 'Test Biz');
      await tester.enterText(find.byKey(const Key('partner_business_address_field')), 'Test Address');

      // Scroll to submit button and tap
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit_create_partner_button')));
      await tester.pump(); // Start request, _isSubmitting becomes true

      expect(requestCount, 1);

      // Attempt second tap while in-flight
      await tester.tap(find.byKey(const Key('submit_create_partner_button')), warnIfMissed: false);
      await tester.pump();
      expect(requestCount, 1); // No duplicate submission occurred!

      // Complete request
      completer.complete(
        http.Response(
          jsonEncode({
            'id': 301,
            'name': 'Test Partner',
            'mobile': '9876543211',
            'role': 'partner',
            'is_active': true,
            'created_at': '2026-10-25T15:00:00',
            'business_name': 'Test Biz',
          }),
          201,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreatePartnerDialog), findsNothing);
    });
  });
}
