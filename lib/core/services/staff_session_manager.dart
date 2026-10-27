class StaffUser {
  const StaffUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.isActive,
    required this.staffId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final String staffId;
  final DateTime? createdAt;

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['name'] is! String ||
        json['mobile'] is! String ||
        json['role'] is! String ||
        json['is_active'] is! bool ||
        json['staff_id'] is! String) {
      throw const FormatException('Staff user response is invalid');
    }

    return StaffUser(
      id: json['id'] as int,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      staffId: json['staff_id'] as String,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

abstract class StaffTokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class InMemoryStaffTokenStorage implements StaffTokenStorage {
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

class StaffSessionManager {
  StaffSessionManager({StaffTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? InMemoryStaffTokenStorage();

  static final StaffSessionManager instance = StaffSessionManager();

  final StaffTokenStorage _tokenStorage;
  StaffUser? _currentUser;

  StaffUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<void> saveSession({
    required String token,
    required StaffUser user,
  }) async {
    await _tokenStorage.saveToken(token);
    _currentUser = user;
  }

  Future<String?> getToken() => _tokenStorage.getToken();

  Future<void> clearSession() async {
    await _tokenStorage.clearToken();
    _currentUser = null;
  }
}
