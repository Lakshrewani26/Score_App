import '../models/admin_models.dart';

/// Abstract storage strategy for Admin authentication tokens.
abstract class AdminTokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

/// In-memory token storage strategy.
///
/// Keeps the JWT access token in application memory during the active session.
/// Tokens are never written to unencrypted local storage (such as plain
/// SharedPreferences or browser localStorage), preventing token theft via
/// device inspection or XSS. When the app is closed or when the Admin logs out,
/// the token is destroyed.
///
/// In a future phase, a native hardware-backed secure storage solution
/// (e.g., flutter_secure_storage backed by iOS Keychain / Android Keystore)
/// can be plugged in without changing the API client or UI layer.
class InMemoryAdminTokenStorage implements AdminTokenStorage {
  String? _token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }
}

/// Manages the authenticated Admin session and in-memory state.
class AdminSessionManager {
  AdminSessionManager({AdminTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? InMemoryAdminTokenStorage();

  static AdminSessionManager instance = AdminSessionManager();

  final AdminTokenStorage _tokenStorage;
  AdminUser? _currentUser;

  AdminTokenStorage get tokenStorage => _tokenStorage;
  AdminUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Saves the active authenticated Admin session.
  Future<void> saveSession({
    required String token,
    required AdminUser user,
  }) async {
    await _tokenStorage.saveToken(token);
    _currentUser = user;
  }

  /// Retrieves the stored access token.
  Future<String?> getToken() async {
    return _tokenStorage.getToken();
  }

  /// Clears the authentication state and token from storage.
  Future<void> clearSession() async {
    await _tokenStorage.clearToken();
    _currentUser = null;
  }
}
