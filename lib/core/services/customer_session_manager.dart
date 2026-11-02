class CustomerUser {
  const CustomerUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    this.isActive = true,
    this.state,
    this.city,
    this.segment,
  });

  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final String? state;
  final String? city;
  final String? segment;

  factory CustomerUser.fromJson(Map<String, dynamic> json) {
    final profile = json['customer_profile'] as Map<String, dynamic>?;
    return CustomerUser(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      role: (json['role'] ?? 'customer').toString(),
      isActive: json['is_active'] as bool? ?? false,
      state: profile?['state'] as String?,
      city: profile?['city'] as String?,
      segment: profile?['segment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'role': role,
      'is_active': isActive,
      'customer_profile': {
        'state': state,
        'city': city,
        'segment': segment,
      },
    };
  }
}

abstract class CustomerTokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class InMemoryCustomerTokenStorage implements CustomerTokenStorage {
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

class CustomerSessionManager {
  CustomerSessionManager({CustomerTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? InMemoryCustomerTokenStorage();

  static final CustomerSessionManager instance = CustomerSessionManager();

  final CustomerTokenStorage _tokenStorage;
  CustomerUser? _currentUser;

  CustomerUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Future<void> saveSession({
    required String token,
    required CustomerUser user,
  }) async {
    await _tokenStorage.saveToken(token);
    _currentUser = user;
  }

  Future<String?> getToken() async {
    return _tokenStorage.getToken();
  }

  Future<void> clearSession() async {
    await _tokenStorage.clearToken();
    _currentUser = null;
  }
}
