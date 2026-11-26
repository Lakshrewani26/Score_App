import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/notification_models.dart';
import '../widgets/order_notification_dialog.dart';
import 'admin_session_manager.dart';
import 'session_revocation_handler.dart';
import 'staff_session_manager.dart';
import '../../features/admin/orders/admin_all_orders_screen.dart';
import '../../features/staff/orders/staff_order_status_screen.dart';

class NotificationService with WidgetsBindingObserver {
  NotificationService({
    http.Client? client,
    String? baseUrl,
    WidgetsBinding? binding,
  })  : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _injectedBinding = binding;

  static final NotificationService instance = NotificationService();

  final http.Client _client;
  final String _baseUrl;
  WidgetsBinding? _injectedBinding;

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isFetching = false;
  String? _currentRole;
  bool _observerRegistered = false;

  bool get isPolling => _isPolling;
  bool get isFetching => _isFetching;
  String? get currentRole => _currentRole;
  bool get isObserverRegistered => _observerRegistered;

  /// Safe accessor for [WidgetsBinding.instance] that returns null
  /// if the binding has not yet been initialized.
  WidgetsBinding? get binding {
    if (_injectedBinding != null) return _injectedBinding;
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }

  bool get isBindingAvailable => binding != null;

  bool get isTestEnvironment {
    final b = binding;
    if (b == null) return true;
    return b.runtimeType.toString().contains('Test');
  }

  /// Can be overridden in unit/widget tests if periodic timer behavior needs to be tested.
  static bool enablePeriodicTimer = true;

  @visibleForTesting
  static bool? forcePeriodicTimerForTesting;

  bool get shouldStartPeriodicTimer {
    if (forcePeriodicTimerForTesting != null) {
      return forcePeriodicTimerForTesting!;
    }
    if (!enablePeriodicTimer) return false;
    final b = binding;
    if (b == null) return false;
    return !b.runtimeType.toString().contains('Test');
  }

  final Set<int> _shownNotificationIds = <int>{};
  final List<AppNotification> _queue = <AppNotification>[];
  bool _isDialogShowing = false;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Safely ensures the [WidgetsBindingObserver] is registered if the binding is available.
  void ensureObserver([WidgetsBinding? targetBinding]) {
    final b = targetBinding ?? binding;
    if (b != null && !_observerRegistered) {
      try {
        b.addObserver(this);
        _observerRegistered = true;
      } catch (_) {
        // WidgetsBinding might not be initialized
      }
    }
  }

  void _removeObserver() {
    if (_observerRegistered) {
      final b = binding;
      if (b != null) {
        try {
          b.removeObserver(this);
        } catch (_) {}
      }
      _observerRegistered = false;
    }
  }

  /// Attaches to the Flutter [WidgetsBinding] when it becomes available.
  /// If notification polling is already active, registers the observer
  /// and starts the periodic timer if appropriate.
  void attachBinding([WidgetsBinding? targetBinding]) {
    if (targetBinding != null) {
      _injectedBinding = targetBinding;
    }
    ensureObserver();
    if (_isPolling && _currentRole != null) {
      _startPeriodicTimerIfNeeded();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPolling && _currentRole != null) {
      fetchUnreadNotifications(_currentRole!);
    }
  }

  Future<String?> _getToken(String role) async {
    if (role == 'admin') {
      return AdminSessionManager.instance.getToken();
    } else if (role == 'staff') {
      return StaffSessionManager.instance.getToken();
    }
    return null;
  }

  void _startPeriodicTimerIfNeeded([Duration interval = const Duration(seconds: 15)]) {
    if (_pollingTimer != null) return;
    if (shouldStartPeriodicTimer && _isPolling && _currentRole != null) {
      final roleToPoll = _currentRole!;
      _pollingTimer = Timer.periodic(interval, (_) {
        if (_isPolling && _currentRole == roleToPoll) {
          fetchUnreadNotifications(roleToPoll);
        }
      });
    }
  }

  void startPolling({
    required String role,
    Duration interval = const Duration(seconds: 15),
  }) {
    final normalized = role.toLowerCase().trim();
    // Customers and Partners must not start this notification service
    if (normalized != 'admin' && normalized != 'staff') {
      return;
    }

    if (_isPolling && _currentRole == normalized) return;
    stopPolling(clearNotificationData: false);

    _currentRole = normalized;
    _isPolling = true;
    ensureObserver();

    // Run first check immediately
    fetchUnreadNotifications(normalized);

    // Only start background periodic timer in production (or when explicitly enabled),
    // preventing '!timersPending' invariant violations during Flutter widget tests,
    // and avoiding starting orphaned timers when running without a Flutter binding.
    _startPeriodicTimerIfNeeded(interval);
  }

  void stopPolling({bool clearNotificationData = true}) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _currentRole = null;
    _removeObserver();
    if (clearNotificationData) {
      _unreadCount = 0;
      unreadCountNotifier.value = 0;
      _queue.clear();
      _shownNotificationIds.clear();
      _isDialogShowing = false;
    }
  }

  @visibleForTesting
  void resetStateForTesting() {
    stopPolling(clearNotificationData: true);
    _injectedBinding = null;
    forcePeriodicTimerForTesting = null;
    _isFetching = false;
  }

  Future<NotificationsListResult?> fetchUnreadNotifications(String role) async {
    if (_isFetching) return null;
    _isFetching = true;
    try {
      final token = await _getToken(role);
      if (token == null || token.isEmpty) return null;

      try {
        final response = await _client.get(
          Uri.parse('$_baseUrl/api/v1/notifications?is_read=false'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 401) {
          final body = response.body;
          if (SessionRevocationHandler.isSessionRevokedError(body)) {
            SessionRevocationHandler.handleSessionRevocation(role: role);
          }
          return null;
        }

        if (response.statusCode == 200) {
          if (!_isPolling) return null;

          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rawList = data['notifications'] as List<dynamic>? ?? [];
          final count = data['unread_count'] as int? ?? rawList.length;

          _unreadCount = count;
          unreadCountNotifier.value = count;

          final notifications = rawList
              .map((item) =>
                  AppNotification.fromJson(item as Map<String, dynamic>))
              .toList();

          // Check for new notifications to show popup
          for (final n in notifications) {
            if (!_shownNotificationIds.contains(n.id) && !n.isRead) {
              _shownNotificationIds.add(n.id);
              _queue.add(n);
            }
          }

          _drainQueue();

          return NotificationsListResult(
            notifications: notifications,
            unreadCount: count,
          );
        }
      } catch (_) {
        // Network/timeout error — ignore during polling
      }
      return null;
    } finally {
      _isFetching = false;
    }
  }

  Future<void> markAsRead(int notificationId, String role) async {
    final token = await _getToken(role);
    if (token == null || token.isEmpty) return;

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/read'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (_unreadCount > 0) {
          _unreadCount--;
          unreadCountNotifier.value = _unreadCount;
        }
      }
    } catch (_) {}
  }

  void _drainQueue() {
    if (_isDialogShowing || _queue.isEmpty) return;

    final context = SessionRevocationHandler.navigatorKey.currentContext;
    if (context == null) return;

    final notification = _queue.removeAt(0);
    _isDialogShowing = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {
          Navigator.of(dialogCtx).pop();
          _isDialogShowing = false;
          markAsRead(notification.id, _currentRole ?? 'admin');

          final nav = SessionRevocationHandler.navigatorKey.currentState ??
              Navigator.maybeOf(context);
          if (nav != null) {
            if (_currentRole == 'admin') {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => const AdminAllOrdersScreen(),
                ),
              );
            } else if (_currentRole == 'staff') {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => const StaffOrderStatusScreen(),
                ),
              );
            }
          }

          _drainQueue();
        },
        onDismiss: () {
          Navigator.of(dialogCtx).pop();
          _isDialogShowing = false;
          markAsRead(notification.id, _currentRole ?? 'admin');
          _drainQueue();
        },
      ),
    ).then((_) {
      _isDialogShowing = false;
      _drainQueue();
    });
  }
}
