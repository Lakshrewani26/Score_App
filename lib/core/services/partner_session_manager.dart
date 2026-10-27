class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    this.isActive = true,
    this.businessName,
    this.businessAddress,
    this.partnerCode,
  });

  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final String? businessName;
  final String? businessAddress;
  final String? partnerCode;

  factory PartnerUser.fromJson(Map<String, dynamic> json) {
    final profile = json['partner_profile'] as Map<String, dynamic>?;
    return PartnerUser(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      mobile: (json['mobile'] ?? '').toString(),
      role: (json['role'] ?? 'partner').toString(),
      isActive: json['is_active'] as bool? ?? false,
      businessName: profile?['business_name'] as String?,
      businessAddress: profile?['business_address'] as String?,
      partnerCode: profile?['partner_code'] as String?,
    );
  }
}

abstract class PartnerTokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> clearToken();
}

class InMemoryPartnerTokenStorage implements PartnerTokenStorage {
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

class PartnerSessionManager {
  PartnerSessionManager({PartnerTokenStorage? tokenStorage})
      : _tokenStorage = tokenStorage ?? InMemoryPartnerTokenStorage();

  static final PartnerSessionManager instance = PartnerSessionManager();

  final PartnerTokenStorage _tokenStorage;
  PartnerUser? _currentUser;

  PartnerUser? get currentUser => _currentUser;

  bool get isAuthenticated => _currentUser != null;

  Future<void> saveSession({
    required String token,
    required PartnerUser user,
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
