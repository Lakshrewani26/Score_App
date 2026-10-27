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
import 'package:score_app/features/admin/home/widgets/admin_update_password_dialog.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Admin Tester',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  group('AdminApi.updatePassword Unit Tests', () {
    test('successful update sends Bearer header, correct body, and parses response', () async {
      String? sentAuth;
      String? sentBody;
      String? sentPath;

      final client = MockClient((request) async {
        sentPath = request.url.path;
        sentAuth = request.headers['Authorization'];
        sentBody = request.body;

        return http.Response(
          jsonEncode({'message': 'Password updated successfully'}),
          200,
        );
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'jwt_admin_secret_token_123', user: mockAdminUser);

      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);
      final response = await api.updatePassword(
        currentPassword: 'CurrentSecret123!',
        newPassword: 'NewSecretPassword456!',
      );

      expect(sentPath, '/api/v1/admin/me/password');
      expect(sentAuth, 'Bearer jwt_admin_secret_token_123');
      expect(response.message, 'Password updated successfully');

      final bodyJson = jsonDecode(sentBody!) as Map<String, dynamic>;
      expect(bodyJson['current_password'], 'CurrentSecret123!');
      expect(bodyJson['new_password'], 'NewSecretPassword456!');
    });

    test('throws AdminApiException on 400 with detail from server', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Current password is incorrect'}),
          400,
        );
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_token', user: mockAdminUser);

      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      expect(
        () => api.updatePassword(
          currentPassword: 'WrongPassword!',
          newPassword: 'NewValidPassword123!',
        ),
        throwsA(isA<AdminApiException>().having(
          (e) => e.message,
          'message',
          'Current password is incorrect',
        )),
      );
    });

    test('throws AdminApiException on 401 unauthenticated session', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Token has expired'}),
          401,
        );
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'expired_token', user: mockAdminUser);

      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      expect(
        () => api.updatePassword(
          currentPassword: 'CurrentPassword!',
          newPassword: 'NewValidPassword123!',
        ),
        throwsA(isA<AdminApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
    });

    test('throws AdminApiException with statusCode 401 when no token is present', () async {
      final client = MockClient((request) async {
        return http.Response('', 200);
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      expect(
        () => api.updatePassword(
          currentPassword: 'CurrentPassword!',
          newPassword: 'NewValidPassword123!',
        ),
        throwsA(isA<AdminApiException>().having(
          (e) => e.message,
          'message',
          'No authentication token provided',
        )),
      );
    });

    test('client-side validation rejects empty or too short new password before request', () async {
      final client = MockClient((request) async {
        fail('Should not send request on client-side validation failure');
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      expect(
        () => api.updatePassword(currentPassword: '', newPassword: 'NewPassword123!'),
        throwsA(isA<AdminApiException>()),
      );
      expect(
        () => api.updatePassword(currentPassword: 'CurrentPassword!', newPassword: 'short'),
        throwsA(isA<AdminApiException>()),
      );
      expect(
        () => api.updatePassword(currentPassword: 'SamePassword123!', newPassword: 'SamePassword123!'),
        throwsA(isA<AdminApiException>()),
      );
    });

    test('never leaks passwords or tokens in AdminApiException string', () async {
      final client = MockClient((request) async {
        return http.Response('Server error occurred', 500);
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'SUPER_SECRET_TOKEN_XYZ', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      try {
        await api.updatePassword(
          currentPassword: 'SUPER_SECRET_CURRENT_PWD',
          newPassword: 'SUPER_SECRET_NEW_PWD',
        );
        fail('Should have thrown');
      } on AdminApiException catch (e) {
        expect(e.toString().contains('SUPER_SECRET_TOKEN_XYZ'), isFalse);
        expect(e.toString().contains('SUPER_SECRET_CURRENT_PWD'), isFalse);
        expect(e.toString().contains('SUPER_SECRET_NEW_PWD'), isFalse);
      }
    });
  });

  group('AdminUpdatePasswordDialog Widget Tests', () {
    Widget buildTestDialog({AdminApi? adminApi}) {
      return MaterialApp(
        home: Scaffold(
          body: AdminUpdatePasswordDialog(adminApi: adminApi),
        ),
      );
    }

    testWidgets('1. All three fields, buttons, and headers render properly', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Update Password'), findsWidgets);
      expect(find.text('Admin Security Settings'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);

      expect(find.byKey(const Key('admin_current_password_input')), findsOneWidget);
      expect(find.byKey(const Key('admin_new_password_input')), findsOneWidget);
      expect(find.byKey(const Key('admin_confirm_password_input')), findsOneWidget);

      expect(find.byKey(const Key('admin_update_password_submit_button')), findsOneWidget);
      expect(find.byKey(const Key('admin_update_password_cancel_button')), findsOneWidget);
    });

    testWidgets('2. Password visibility toggles work for each field independently', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Initially all fields are obscured
      EditableText currentField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_current_password_input')),
        matching: find.byType(EditableText),
      ));
      EditableText newField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_new_password_input')),
        matching: find.byType(EditableText),
      ));
      EditableText confirmField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_confirm_password_input')),
        matching: find.byType(EditableText),
      ));

      expect(currentField.obscureText, isTrue);
      expect(newField.obscureText, isTrue);
      expect(confirmField.obscureText, isTrue);

      // Toggle current password
      await tester.tap(find.byKey(const Key('admin_current_password_visibility_toggle')));
      await tester.pumpAndSettle();

      currentField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_current_password_input')),
        matching: find.byType(EditableText),
      ));
      newField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_new_password_input')),
        matching: find.byType(EditableText),
      ));
      expect(currentField.obscureText, isFalse);
      expect(newField.obscureText, isTrue);

      // Toggle new password
      await tester.tap(find.byKey(const Key('admin_new_password_visibility_toggle')));
      await tester.pumpAndSettle();

      newField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_new_password_input')),
        matching: find.byType(EditableText),
      ));
      expect(newField.obscureText, isFalse);

      // Toggle back to obscure
      await tester.tap(find.byKey(const Key('admin_current_password_visibility_toggle')));
      await tester.pumpAndSettle();

      currentField = tester.widget(find.descendant(
        of: find.byKey(const Key('admin_current_password_input')),
        matching: find.byType(EditableText),
      ));
      expect(currentField.obscureText, isTrue);
    });

    testWidgets('3. Required fields validation triggers on empty submit', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Current password is required'), findsOneWidget);
      expect(find.text('New password is required'), findsOneWidget);
      expect(find.text('Please confirm your new password'), findsOneWidget);
    });

    testWidgets('4. Minimum length validation enforced for new password', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'OldPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'short');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'short');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters long'), findsOneWidget);
    });

    testWidgets('5. Mismatched confirmation password shows error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'OldPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewPassword123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'DifferentPassword123!');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('6. Reusing current password shows error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'IdenticalPass123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'IdenticalPass123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'IdenticalPass123!');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('New password must be different from current password'), findsOneWidget);
    });

    testWidgets('7. Successful password update closes dialog and returns true', (WidgetTester tester) async {
      bool updateCalled = false;
      final client = MockClient((request) async {
        updateCalled = true;
        return http.Response(
          jsonEncode({'message': 'Password updated successfully'}),
          200,
        );
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_test_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () async {
                  dialogResult = await showDialog<bool>(
                    context: context,
                    builder: (_) => AdminUpdatePasswordDialog(adminApi: api),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'CurrentPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewPassword123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'NewPassword123!');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(updateCalled, isTrue);
      expect(find.byType(AdminUpdatePasswordDialog), findsNothing);
      expect(dialogResult, isTrue);
    });

    testWidgets('8. Server error (wrong current password) displays error banner and keeps dialog open', (WidgetTester tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Current password is incorrect'}),
          400,
        );
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_test_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(buildTestDialog(adminApi: api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'WrongPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewPassword123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'NewPassword123!');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      // Dialog stays open
      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);
      // Error banner displays server error message
      expect(find.byKey(const Key('admin_update_password_error_banner')), findsOneWidget);
      expect(find.text('Current password is incorrect'), findsOneWidget);
    });

    testWidgets('9. Network failure displays safe error message without false success', (WidgetTester tester) async {
      final client = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_test_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(buildTestDialog(adminApi: api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'CurrentPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewPassword123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'NewPassword123!');

      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);
      expect(find.byKey(const Key('admin_update_password_error_banner')), findsOneWidget);
      expect(find.textContaining('Network error'), findsOneWidget);
    });

    testWidgets('10. Duplicate submissions are prevented while loading', (WidgetTester tester) async {
      final completer = Completer<http.Response>();
      int requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;
        return completer.future;
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_test_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(buildTestDialog(adminApi: api));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'CurrentPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewPassword123!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'NewPassword123!');

      // Tap submit first time
      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pump(); // Enter loading state without settling

      // Expect progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Attempt second tap during loading
      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pump();

      expect(requestCount, 1);

      // Complete request
      completer.complete(
        http.Response(jsonEncode({'message': 'Password updated successfully'}), 200),
      );
      await tester.pumpAndSettle();

      expect(requestCount, 1);
    });

    testWidgets('11. Cancel button dismisses dialog without calling API', (WidgetTester tester) async {
      bool called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AdminUpdatePasswordDialog(adminApi: api),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_update_password_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUpdatePasswordDialog), findsNothing);
      expect(called, isFalse);
    });

    testWidgets('12. End-to-end: Profile menu -> Update Password -> Success SnackBar on dashboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/me/password') {
          return http.Response(
            jsonEncode({'message': 'Password updated successfully'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final sessionManager = AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(token: 'valid_jwt_token', user: mockAdminUser);
      final api = AdminApi(client: client, baseUrl: 'http://localhost', sessionManager: sessionManager);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
            adminApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open profile popup menu
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Tap 'Update Password' in menu
      await tester.tap(find.byKey(const Key('profile_menu_update_password')));
      await tester.pumpAndSettle();

      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);

      // Enter valid fields
      await tester.enterText(find.byKey(const Key('admin_current_password_input')), 'CurrentPassword123!');
      await tester.enterText(find.byKey(const Key('admin_new_password_input')), 'NewSecurePassword456!');
      await tester.enterText(find.byKey(const Key('admin_confirm_password_input')), 'NewSecurePassword456!');

      // Submit
      await tester.tap(find.byKey(const Key('admin_update_password_submit_button')));
      await tester.pumpAndSettle();

      // Dialog closed
      expect(find.byType(AdminUpdatePasswordDialog), findsNothing);

      // Success SnackBar visible on dashboard
      expect(find.text('Password updated successfully'), findsOneWidget);
    });
  });
}
