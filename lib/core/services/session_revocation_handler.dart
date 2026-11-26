import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_session_manager.dart';
import 'customer_session_manager.dart';
import 'partner_session_manager.dart';
import 'staff_session_manager.dart';
import '../../features/admin/login/admin_login_screen.dart';
import '../../features/customer/login/customer_login_screen.dart';
import '../../features/partner/login/partner_login_screen.dart';
import '../../features/staff/login/staff_login_screen.dart';
import '../../features/welcome/welcome_screen.dart';

class SessionRevocationHandler {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _isHandlingRevocation = false;

  static const String sessionRevokedMessage =
      'Your account was logged in on another device. Please log in again.';

  static bool isSessionRevokedError(String? message) {
    if (message == null) return false;
    final lower = message.toLowerCase();
    return lower.contains('another device') ||
        lower.contains('session expired') ||
        lower.contains('session revoked');
  }

  static Future<void> handleSessionRevocation({
    String? role,
  }) async {
    if (_isHandlingRevocation) return;
    _isHandlingRevocation = true;

    try {
      // 1. Clear credentials and cached user info across all sessions
      await AdminSessionManager.instance.clearSession();
      await StaffSessionManager.instance.clearSession();
      await PartnerSessionManager.instance.clearSession();
      await CustomerSessionManager.instance.clearSession();

      // 2. Resolve Navigator
      final nav = navigatorKey.currentState;

      if (nav != null) {
        Widget targetLogin;
        switch (role?.toLowerCase()) {
          case 'admin':
            targetLogin = const AdminLoginScreen();
            break;
          case 'staff':
            targetLogin = const StaffLoginScreen();
            break;
          case 'partner':
            targetLogin = const PartnerLoginScreen();
            break;
          case 'customer':
            targetLogin = const CustomerLoginScreen();
            break;
          default:
            targetLogin =
                kIsWeb ? const AdminLoginScreen() : const WelcomeScreen();
        }

        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => targetLogin),
          (route) => false,
        );

        // Show message via messengerKey without BuildContext
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(sessionRevokedMessage),
            backgroundColor: Color(0xFFC62828),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Allow future revocations after redirect completes
      Future.delayed(const Duration(seconds: 2), () {
        _isHandlingRevocation = false;
      });
    }
  }
}
