import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/services/admin_session_manager.dart';
import 'package:score_app/core/services/notification_service.dart';
import 'package:score_app/core/services/staff_session_manager.dart';

void main() {
  setUp(() {
    NotificationService.instance.resetStateForTesting();
  });

  tearDown(() {
    NotificationService.instance.resetStateForTesting();
  });

  group('Session Saving Without Initialized Flutter WidgetsBinding', () {
    test('Admin session can be saved without an initialized binding', () async {
      // Confirm that the Flutter binding is not available in pure unit test
      expect(NotificationService.instance.isBindingAvailable, isFalse);

      final storage = InMemoryAdminTokenStorage();
      final manager = AdminSessionManager(tokenStorage: storage);

      const admin = AdminUser(
        id: 10,
        name: 'Head Admin',
        mobile: '9123456789',
        role: 'admin',
        isActive: true,
      );

      // Must complete successfully without throwing WidgetsBinding errors
      await manager.saveSession(token: 'admin_test_token_xyz', user: admin);

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentUser?.id, 10);
      expect(manager.currentUser?.name, 'Head Admin');
      expect(await manager.getToken(), 'admin_test_token_xyz');

      // Notification polling state reflects the session role safely
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, 'admin');

      // Clear session safely clears session and stops polling
      await manager.clearSession();
      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentUser, isNull);
      expect(await manager.getToken(), isNull);
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });

    test('Staff session can be saved without an initialized binding', () async {
      expect(NotificationService.instance.isBindingAvailable, isFalse);

      final storage = InMemoryStaffTokenStorage();
      final manager = StaffSessionManager(tokenStorage: storage);

      const staff = StaffUser(
        id: 20,
        name: 'Field Staff',
        mobile: '9876501234',
        role: 'staff',
        isActive: true,
        staffId: 'STF-020',
      );

      // Must complete successfully without throwing WidgetsBinding errors
      await manager.saveSession(token: 'staff_test_token_abc', user: staff);

      expect(manager.isAuthenticated, isTrue);
      expect(manager.currentUser?.id, 20);
      expect(manager.currentUser?.name, 'Field Staff');
      expect(manager.currentUser?.staffId, 'STF-020');
      expect(await manager.getToken(), 'staff_test_token_abc');

      // Notification polling state reflects the session role safely
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, 'staff');

      // Clear session safely clears session and stops polling
      await manager.clearSession();
      expect(manager.isAuthenticated, isFalse);
      expect(manager.currentUser, isNull);
      expect(await manager.getToken(), isNull);
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });

    test('NotificationService.startPolling is safe without initialized binding', () {
      expect(NotificationService.instance.isBindingAvailable, isFalse);

      // Direct startPolling call without binding must not throw
      expect(
        () => NotificationService.instance.startPolling(role: 'admin'),
        returnsNormally,
      );
      expect(NotificationService.instance.isPolling, isTrue);
      expect(NotificationService.instance.currentRole, 'admin');

      NotificationService.instance.stopPolling();
      expect(NotificationService.instance.isPolling, isFalse);
      expect(NotificationService.instance.currentRole, isNull);
    });
  });
}
