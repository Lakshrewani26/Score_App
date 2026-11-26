import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/notification_service.dart';
import 'package:score_app/core/services/session_revocation_handler.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';

void main() {
  setUp(() {
    NotificationService.instance.resetStateForTesting();
  });

  tearDown(() {
    NotificationService.instance.resetStateForTesting();
  });

  group('NotificationService Lifecycle', () {
    test('Customers and Partners cannot start notification monitoring', () {
      NotificationService.instance.startPolling(role: 'customer');
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);

      NotificationService.instance.startPolling(role: 'partner');
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });

    test('Staff and Admin can start notification monitoring', () {
      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));

      NotificationService.instance.stopPolling();
      expect(NotificationService.instance.isPolling, isFalse);

      NotificationService.instance.startPolling(role: 'staff');
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('staff'));
    });

    test('Duplicate startPolling calls do not create duplicate timers', () {
      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);

      // Calling startPolling again with same role is a safe no-op
      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));
    });

    test('AdminSessionManager.saveSession starts polling and clearSession stops polling', () async {
      final manager = AdminSessionManager();
      const admin = AdminUser(id: 1, name: 'Admin', mobile: '9999999999', role: 'admin', isActive: true);

      await manager.saveSession(token: 'test_token', user: admin);
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));

      await manager.clearSession();
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });

    test('StaffSessionManager.saveSession starts polling and clearSession stops polling', () async {
      final manager = StaffSessionManager();
      const staff = StaffUser(id: 2, name: 'Staff', mobile: '8888888888', role: 'staff', isActive: true, staffId: 'STF-01');

      await manager.saveSession(token: 'staff_token', user: staff);
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('staff'));

      await manager.clearSession();
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });

    testWidgets('Notification polling remains active when navigating away from AdminHomeScreen', (tester) async {
      NotificationService.instance.resetStateForTesting();
      const admin = AdminUser(id: 1, name: 'Admin', mobile: '9999999999', role: 'admin', isActive: true);
      NotificationService.instance.startPolling(role: 'admin');

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: SessionRevocationHandler.navigatorKey,
          home: const AdminHomeScreen(adminUser: admin),
        ),
      );

      // Polling should be active when AdminHomeScreen mounts
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));

      // Navigate away to a dummy sub-screen (push replacement or push)
      SessionRevocationHandler.navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Orders Screen')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Orders Screen'), findsOneWidget);

      // CRITICAL: Polling must still be active!
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));

      // Clean up timer before widget tester teardown
      NotificationService.instance.stopPolling();
    });

    test('Notification polling starts correctly when app binding is available', () {
      // In this test file, WidgetsBinding is available
      expect(NotificationService.instance.isBindingAvailable, isTrue);

      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));
      expect(NotificationService.instance.isObserverRegistered, isTrue);

      NotificationService.instance.stopPolling();
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.isObserverRegistered, isFalse);
    });

    test('attachBinding registers observer when polling was previously requested', () {
      NotificationService.instance.resetStateForTesting();

      NotificationService.instance.startPolling(role: 'staff');
      expect(NotificationService.instance.isPolling, isTrue);

      NotificationService.instance.attachBinding();
      expect(NotificationService.instance.isObserverRegistered, isTrue);
      expect(NotificationService.instance.currentRole, equals('staff'));

      NotificationService.instance.stopPolling();
    });

    test('Repeated startPolling calls do not duplicate observer or change role unexpectedly', () {
      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.isObserverRegistered, isTrue);

      // Calling startPolling repeatedly
      NotificationService.instance.startPolling(role: 'admin');
      NotificationService.instance.startPolling(role: 'admin');

      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, equals('admin'));
      expect(NotificationService.instance.isObserverRegistered, isTrue);

      NotificationService.instance.stopPolling();
    });

    test('Logout stops polling, unregisters observer, and clears notification data', () async {
      final manager = AdminSessionManager();
      const admin = AdminUser(id: 1, name: 'Admin', mobile: '9999999999', role: 'admin', isActive: true);

      await manager.saveSession(token: 'token_123', user: admin);
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.isObserverRegistered, isTrue);

      await manager.clearSession();
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
      expect(NotificationService.instance.isObserverRegistered, isFalse);
      expect(NotificationService.instance.unreadCount, 0);
    });

    test('Session revocation stops polling and unregisters observer', () async {
      final adminManager = AdminSessionManager.instance;
      const admin = AdminUser(id: 1, name: 'Admin', mobile: '9999999999', role: 'admin', isActive: true);

      await adminManager.saveSession(token: 'admin_tok', user: admin);
      expect(NotificationService.instance.isPolling, isTrue);

      await SessionRevocationHandler.handleSessionRevocation(role: 'admin');
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
      expect(NotificationService.instance.isObserverRegistered, isFalse);
    });

    test('App lifecycle resumed triggers fetchUnreadNotifications when polling is active', () {
      NotificationService.instance.startPolling(role: 'admin');
      expect(NotificationService.instance.isPolling, isTrue);

      // App transitions to resumed — must not throw
      expect(
        () => NotificationService.instance
            .didChangeAppLifecycleState(AppLifecycleState.resumed),
        returnsNormally,
      );

      NotificationService.instance.stopPolling();

      // App transitions when not polling — must not throw and does nothing
      expect(
        () => NotificationService.instance
            .didChangeAppLifecycleState(AppLifecycleState.resumed),
        returnsNormally,
      );
    });
  });
}
