import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_api.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/features/admin/catalogue/admin_catalogue_screen.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';
import 'package:score_app/features/admin/home/widgets/admin_update_password_dialog.dart';
import 'package:score_app/features/admin/qr/admin_qr_generation_screen.dart';
import 'package:score_app/features/admin/qr/widgets/admin_create_qr_batch_dialog.dart';
import 'package:score_app/features/admin/settings/admin_settings_screen.dart';
import 'package:score_app/features/admin/users/admin_users_screen.dart';
import 'package:score_app/features/welcome/welcome_screen.dart';

void main() {
  const mockAdminUser = AdminUser(
    id: 1,
    name: 'Super Admin',
    mobile: '9876543210',
    role: 'admin',
    isActive: true,
  );

  Map<String, dynamic> mockPaginatedUsersResponse() => {
        'items': [
          {
            'id': 101,
            'name': 'Partner One',
            'mobile': '9876543211',
            'role': 'partner',
            'is_active': true,
            'business_name': 'Score Auto Spares',
            'partner_code': 'PARTNER-001',
          }
        ],
        'total': 1,
        'page': 1,
        'page_size': 20,
        'total_pages': 1,
      };

  group('Admin Dashboard: Profile Menu & QR Code Generation Tests', () {
    testWidgets(
        '1. Dashboard renders circular profile avatar, removes header logout icon, and removes bottom logout button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Profile avatar button is rendered with tooltip and person icon
      expect(
          find.byKey(const Key('admin_profile_avatar_button')), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsWidgets);

      // Verify header logout icon is removed
      expect(find.byIcon(Icons.logout_rounded), findsNothing);

      // Verify bottom logout button is completely removed
      expect(find.text('Logout'), findsNothing);
    });

    testWidgets(
        '2. Clicking profile avatar opens profile menu without logging out',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click circular profile avatar button
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Menu opens showing 'Update Password' and 'Logout'
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Session remains fully active and screen remains on AdminHomeScreen
      expect(sessionManager.isAuthenticated, isTrue);
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('3. Selecting Update Password opens functional password dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open profile popup menu
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Tap 'Update Password'
      await tester.tap(find.byKey(const Key('profile_menu_update_password')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(AdminUpdatePasswordDialog), findsOneWidget);
      expect(find.text('Admin Security Settings'), findsOneWidget);

      // Structured form inputs are rendered
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.byKey(const Key('admin_update_password_submit_button')),
          findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUpdatePasswordDialog), findsNothing);
    });

    testWidgets(
        '4. Logout selection uses existing session clearing flow with confirmation dialog',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open profile menu
      await tester.tap(find.byKey(const Key('admin_profile_avatar_button')));
      await tester.pumpAndSettle();

      // Select Logout
      await tester.tap(find.byKey(const Key('profile_menu_logout')));
      await tester.pumpAndSettle();

      // Confirmation dialog is displayed
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(
        find.text('Are you sure you want to log out of your Admin session?'),
        findsOneWidget,
      );

      // Confirm logout
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      // Navigates to WelcomeScreen, session cleared
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(sessionManager.isAuthenticated, isFalse);
      expect(sessionManager.currentUser, isNull);
      expect(find.text('Logged out of Admin session'), findsOneWidget);
    });

    testWidgets(
        '5. QR Code Generation button is rendered with Score theme and QR icon',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom button
      await tester.scrollUntilVisible(
          find.byKey(const Key('qr_code_generation_button')), 200);

      expect(find.text('QR Code Generation'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
    });

    testWidgets(
        '6. Clicking QR Code Generation navigates to AdminQrGenerationScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.byKey(const Key('qr_code_generation_button')), 200);
      await tester.tap(find.byKey(const Key('qr_code_generation_button')));
      await tester.pumpAndSettle();

      // Navigated to AdminQrGenerationScreen
      expect(find.byType(AdminQrGenerationScreen), findsOneWidget);
    });

    testWidgets(
        '7. AdminQrGenerationScreen displays all four QR categories, notice, and back navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminQrGenerationScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header title and subtitle
      expect(find.text('QR Code Generation'), findsOneWidget);
      expect(find.text('Manage QR codes for Score'), findsOneWidget);

      // Phase notice
      expect(
        find.text(
          'QR generation, unique-token allocation, batch export, and printing will be implemented in a subsequent phase.',
        ),
        findsOneWidget,
      );

      // Four categories and concise explanatory text
      expect(find.text('Product QR'), findsOneWidget);
      expect(
        find.text('Product packaging and individual unit serial QR codes'),
        findsOneWidget,
      );

      expect(find.text('Invoice QR'), findsOneWidget);
      expect(
        find.text('Invoice verification and billing transaction QR codes'),
        findsOneWidget,
      );

      expect(find.text('Staff QR'), findsOneWidget);
      expect(
        find.text('Staff identification, attendance, and assignment QR codes'),
        findsOneWidget,
      );

      expect(find.text('Partner QR'), findsOneWidget);
      expect(
        find.text(
            'Dealer, distributor, and workshop partner affiliation QR codes'),
        findsOneWidget,
      );

      // Tapping a category opens the QR batch generation dialog
      await tester.tap(find.text('Product QR').first);
      await tester.pumpAndSettle();
      expect(find.byType(AdminCreateQrBatchDialog), findsOneWidget);
      expect(find.text('Generate Product QR Batch'), findsOneWidget);
    });

    testWidgets(
        '8. Back button on AdminQrGenerationScreen returns to AdminHomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminHomeScreen(
            adminUser: mockAdminUser,
            sessionManager: sessionManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to QR screen
      await tester.scrollUntilVisible(
          find.byKey(const Key('qr_code_generation_button')), 200);
      await tester.tap(find.byKey(const Key('qr_code_generation_button')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminQrGenerationScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Returns to AdminHomeScreen
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(find.byType(AdminQrGenerationScreen), findsNothing);
    });

    testWidgets(
        '9. Existing Admin module behavior (User Management & placeholders) is preserved',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sessionManager =
          AdminSessionManager(tokenStorage: InMemoryAdminTokenStorage());
      await sessionManager.saveSession(
          token: 'test_token', user: mockAdminUser);

      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/admin/users') {
          return http.Response(jsonEncode(mockPaginatedUsersResponse()), 200);
        }
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
        if (request.url.path == '/api/v1/admin/points-rules') {
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 0,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final adminApi = AdminApi(
          client: client,
          baseUrl: 'http://localhost',
          sessionManager: sessionManager);

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

      // User Management tile is present with Manage badge
      expect(find.text('User Management'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);

      // Tap User Management -> Navigates to AdminUsersScreen
      await tester.tap(find.text('User Management'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersScreen), findsOneWidget);

      // Return back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);

      // Functional module Catalogue Management navigates to AdminCatalogueScreen
      await tester.scrollUntilVisible(find.text('Catalogue Management'), 100);
      await tester.tap(find.text('Catalogue Management'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminCatalogueScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_catalogue_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);

      expect(find.text('Orders & Requests'), findsNothing);
      expect(find.text('Partner orders & stock requests'), findsNothing);
      expect(find.text('Reports & Analytics'), findsNothing);
      expect(find.text('Transaction logs & points history'), findsNothing);

      await tester.tap(find.text('System Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminSettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_settings_back_button')));
      await tester.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);
    });
  });
}
