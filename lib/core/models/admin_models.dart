export 'admin_catalogue_models.dart';

class AdminZone {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int partnerCount;

  const AdminZone({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.partnerCount = 0,
  });

  factory AdminZone.fromJson(Map<String, dynamic> json) {
    return AdminZone(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      partnerCount: json['partner_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'partner_count': partnerCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminZone &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          isActive == other.isActive;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ isActive.hashCode;
}

class AdminUser {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.isActive,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          mobile == other.mobile &&
          role == other.role &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      mobile.hashCode ^
      role.hashCode ^
      isActive.hashCode;
}

class AdminAuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AdminUser user;

  const AdminAuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AdminAuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid user in auth response');
    }
    return AdminAuthResponse(
      accessToken: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
      user: AdminUser.fromJson(userJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'user': user.toJson(),
      };
}

class AdminUserSummary {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final String? businessName;
  final String? partnerCode;
  final String? staffId;
  final int? zoneId;
  final String? zoneName;

  const AdminUserSummary({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.businessName,
    this.partnerCode,
    this.staffId,
    this.zoneId,
    this.zoneName,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      businessName: json['business_name'] as String?,
      partnerCode: json['partner_code'] as String?,
      staffId: json['staff_id'] as String?,
      zoneId: json['zone_id'] as int?,
      zoneName: json['zone_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        if (businessName != null) 'business_name': businessName,
        if (partnerCode != null) 'partner_code': partnerCode,
        if (staffId != null) 'staff_id': staffId,
        if (zoneId != null) 'zone_id': zoneId,
        if (zoneName != null) 'zone_name': zoneName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUserSummary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          mobile == other.mobile &&
          role == other.role &&
          isActive == other.isActive &&
          businessName == other.businessName &&
          partnerCode == other.partnerCode &&
          staffId == other.staffId &&
          zoneId == other.zoneId &&
          zoneName == other.zoneName;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      mobile.hashCode ^
      role.hashCode ^
      isActive.hashCode ^
      businessName.hashCode ^
      partnerCode.hashCode ^
      staffId.hashCode ^
      zoneId.hashCode ^
      zoneName.hashCode;
}

class AdminStaffPartnerAssignment {
  const AdminStaffPartnerAssignment({
    required this.id,
    required this.staffId,
    required this.partnerId,
    required this.assignedAt,
    required this.isActive,
    required this.staff,
    required this.partner,
  });

  final int id;
  final int staffId;
  final int partnerId;
  final DateTime assignedAt;
  final bool isActive;
  final AdminUserSummary staff;
  final AdminUserSummary partner;

  factory AdminStaffPartnerAssignment.fromJson(Map<String, dynamic> json) {
    final staffJson = json['staff'];
    final partnerJson = json['partner'];
    final assignedAt = json['assigned_at'];
    if (json['id'] is! int ||
        json['staff_id'] is! int ||
        json['partner_id'] is! int ||
        json['is_active'] is! bool ||
        assignedAt is! String ||
        staffJson is! Map<String, dynamic> ||
        partnerJson is! Map<String, dynamic>) {
      throw const FormatException(
          'Staff-Partner assignment response is invalid');
    }
    final parsedAssignedAt = DateTime.tryParse(assignedAt);
    if (parsedAssignedAt == null) {
      throw const FormatException('Assignment timestamp is invalid');
    }
    return AdminStaffPartnerAssignment(
      id: json['id'] as int,
      staffId: json['staff_id'] as int,
      partnerId: json['partner_id'] as int,
      assignedAt: parsedAssignedAt,
      isActive: json['is_active'] as bool,
      staff: AdminUserSummary.fromJson(staffJson),
      partner: AdminUserSummary.fromJson(partnerJson),
    );
  }
}

class CustomerProfileData {
  final String? state;
  final String? city;
  final String? segment;

  const CustomerProfileData({
    this.state,
    this.city,
    this.segment,
  });

  factory CustomerProfileData.fromJson(Map<String, dynamic> json) {
    return CustomerProfileData(
      state: json['state'] as String?,
      city: json['city'] as String?,
      segment: json['segment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (state != null) 'state': state,
        if (city != null) 'city': city,
        if (segment != null) 'segment': segment,
      };
}

class PartnerProfileData {
  final String businessName;
  final String businessAddress;
  final String? partnerCode;
  final int? zoneId;
  final String? zoneName;

  const PartnerProfileData({
    required this.businessName,
    required this.businessAddress,
    this.partnerCode,
    this.zoneId,
    this.zoneName,
  });

  factory PartnerProfileData.fromJson(Map<String, dynamic> json) {
    return PartnerProfileData(
      businessName: json['business_name'] as String? ?? '',
      businessAddress: json['business_address'] as String? ?? '',
      partnerCode: json['partner_code'] as String?,
      zoneId: json['zone_id'] as int?,
      zoneName: json['zone_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'business_address': businessAddress,
        if (partnerCode != null) 'partner_code': partnerCode,
        if (zoneId != null) 'zone_id': zoneId,
        if (zoneName != null) 'zone_name': zoneName,
      };
}

class StaffProfileData {
  final String staffId;

  const StaffProfileData({
    required this.staffId,
  });

  factory StaffProfileData.fromJson(Map<String, dynamic> json) {
    return StaffProfileData(
      staffId: json['staff_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'staff_id': staffId,
      };
}

class AdminUserDetail {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final String? businessName;
  final String? partnerCode;
  final String? staffId;
  final int? zoneId;
  final String? zoneName;
  final CustomerProfileData? customerProfile;
  final PartnerProfileData? partnerProfile;
  final StaffProfileData? staffProfile;

  const AdminUserDetail({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.businessName,
    this.partnerCode,
    this.staffId,
    this.zoneId,
    this.zoneName,
    this.customerProfile,
    this.partnerProfile,
    this.staffProfile,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    return AdminUserDetail(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      businessName: json['business_name'] as String?,
      partnerCode: json['partner_code'] as String?,
      staffId: json['staff_id'] as String?,
      zoneId: json['zone_id'] as int? ??
          (json['partner_profile'] is Map<String, dynamic>
              ? json['partner_profile']['zone_id'] as int?
              : null),
      zoneName: json['zone_name'] as String? ??
          (json['partner_profile'] is Map<String, dynamic>
              ? json['partner_profile']['zone_name'] as String?
              : null),
      customerProfile: json['customer_profile'] is Map<String, dynamic>
          ? CustomerProfileData.fromJson(
              json['customer_profile'] as Map<String, dynamic>)
          : null,
      partnerProfile: json['partner_profile'] is Map<String, dynamic>
          ? PartnerProfileData.fromJson(
              json['partner_profile'] as Map<String, dynamic>)
          : null,
      staffProfile: json['staff_profile'] is Map<String, dynamic>
          ? StaffProfileData.fromJson(
              json['staff_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'role': role,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        if (businessName != null) 'business_name': businessName,
        if (partnerCode != null) 'partner_code': partnerCode,
        if (staffId != null) 'staff_id': staffId,
        if (zoneId != null) 'zone_id': zoneId,
        if (zoneName != null) 'zone_name': zoneName,
        if (customerProfile != null)
          'customer_profile': customerProfile!.toJson(),
        if (partnerProfile != null) 'partner_profile': partnerProfile!.toJson(),
        if (staffProfile != null) 'staff_profile': staffProfile!.toJson(),
      };

  AdminUserSummary toSummary() => AdminUserSummary(
        id: id,
        name: name,
        mobile: mobile,
        role: role,
        isActive: isActive,
        createdAt: createdAt,
        businessName: businessName ?? partnerProfile?.businessName,
        partnerCode: partnerCode ?? partnerProfile?.partnerCode,
        staffId: staffId ?? staffProfile?.staffId,
        zoneId: zoneId ?? partnerProfile?.zoneId,
        zoneName: zoneName ?? partnerProfile?.zoneName,
      );
}

class AdminPaginatedUsers {
  final List<AdminUserSummary> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const AdminPaginatedUsers({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory AdminPaginatedUsers.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return AdminPaginatedUsers(
      items: rawItems
          .map(
              (item) => AdminUserSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

class CreatePartnerPayload {
  final String name;
  final String mobile;
  final String password;
  final String businessName;
  final String businessAddress;
  final String? partnerCode;
  final int? zoneId;

  const CreatePartnerPayload({
    required this.name,
    required this.mobile,
    required this.password,
    required this.businessName,
    required this.businessAddress,
    this.partnerCode,
    this.zoneId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'password': password,
      'business_name': businessName,
      'business_address': businessAddress,
    };
    if (partnerCode != null && partnerCode!.trim().isNotEmpty) {
      map['partner_code'] = partnerCode!.trim();
    }
    if (zoneId != null) {
      map['zone_id'] = zoneId;
    }
    return map;
  }
}

class CreateCustomerPayload {
  final String name;
  final String mobile;
  final String password;
  final String? state;
  final String? city;
  final String? segment;

  const CreateCustomerPayload({
    required this.name,
    required this.mobile,
    required this.password,
    this.state,
    this.city,
    this.segment,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'password': password,
    };
    if (state != null && state!.trim().isNotEmpty) map['state'] = state!.trim();
    if (city != null && city!.trim().isNotEmpty) map['city'] = city!.trim();
    if (segment != null && segment!.trim().isNotEmpty) map['segment'] = segment!.trim();
    return map;
  }
}

class UpdateUserPayload {
  final String? name;
  final String? mobile;
  final String? state;
  final String? city;
  final String? segment;
  final String? businessName;
  final String? businessAddress;
  final String? partnerCode;
  final int? zoneId;
  final bool? clearZone;
  final String? staffId;

  const UpdateUserPayload({
    this.name,
    this.mobile,
    this.state,
    this.city,
    this.segment,
    this.businessName,
    this.businessAddress,
    this.partnerCode,
    this.zoneId,
    this.clearZone,
    this.staffId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (mobile != null) map['mobile'] = mobile;
    if (state != null) map['state'] = state;
    if (city != null) map['city'] = city;
    if (segment != null) map['segment'] = segment;
    if (businessName != null) map['business_name'] = businessName;
    if (businessAddress != null) map['business_address'] = businessAddress;
    if (partnerCode != null) map['partner_code'] = partnerCode;
    if (zoneId != null) map['zone_id'] = zoneId;
    if (clearZone != null) map['clear_zone'] = clearZone;
    if (staffId != null) map['staff_id'] = staffId;
    return map;
  }
}

class UserDeleteResult {
  final String message;
  final int userId;
  final String action;

  const UserDeleteResult({
    required this.message,
    required this.userId,
    required this.action,
  });

  factory UserDeleteResult.fromJson(Map<String, dynamic> json) {
    return UserDeleteResult(
      message: json['message'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      action: json['action'] as String? ?? 'deactivated',
    );
  }

  bool get wasDeactivated => action == 'deactivated';
}

class CreateStaffPayload {
  final String name;
  final String mobile;
  final String password;
  final String staffId;

  const CreateStaffPayload({
    required this.name,
    required this.mobile,
    required this.password,
    required this.staffId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mobile': mobile,
        'password': password,
        'staff_id': staffId,
      };
}

class AdminPasswordUpdateRequest {
  final String currentPassword;
  final String newPassword;

  const AdminPasswordUpdateRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'current_password': currentPassword,
        'new_password': newPassword,
      };
}

class AdminPasswordUpdateResponse {
  final String message;

  const AdminPasswordUpdateResponse({
    required this.message,
  });

  factory AdminPasswordUpdateResponse.fromJson(Map<String, dynamic> json) {
    return AdminPasswordUpdateResponse(
      message: json['message'] as String? ?? 'Password updated successfully',
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
      };
}
