class AdminSystemInfo {
  const AdminSystemInfo({
    required this.appName,
    required this.environment,
    required this.apiVersion,
    required this.databaseStatus,
  });

  final String appName;
  final String environment;
  final String apiVersion;
  final String databaseStatus;

  factory AdminSystemInfo.fromJson(Map<String, dynamic> json) {
    return AdminSystemInfo(
      appName: json['app_name'] as String? ?? 'Score API',
      environment: json['environment'] as String? ?? 'development',
      apiVersion: json['api_version'] as String? ?? '1.0.0',
      databaseStatus: json['database_status'] as String? ?? 'connected',
    );
  }

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'environment': environment,
        'api_version': apiVersion,
        'database_status': databaseStatus,
      };
}

class AdminPointsRule {
  const AdminPointsRule({
    required this.id,
    required this.ruleName,
    this.ruleDescription,
    required this.category,
    this.pointsAwarded,
    this.pointsRequired,
    this.minTransactionValue,
    this.maxTransactionValue,
    this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.createdByName,
    this.updatedByName,
  });

  final int id;
  final String ruleName;
  final String? ruleDescription;
  final String category;
  final int? pointsAwarded;
  final int? pointsRequired;
  final double? minTransactionValue;
  final double? maxTransactionValue;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final String? createdByName;
  final String? updatedByName;

  String get categoryLabel {
    switch (category) {
      case 'product_qr_scan':
        return 'Product QR Scan';
      case 'invoice_qr_scan':
        return 'Invoice QR Scan';
      case 'redemption':
        return 'Points Redemption';
      case 'customer_to_partner_transfer':
        return 'Customer → Partner Transfer';
      case 'partner_to_staff_transfer':
        return 'Partner → Staff Transfer';
      default:
        return category;
    }
  }

  factory AdminPointsRule.fromJson(Map<String, dynamic> json) {
    return AdminPointsRule(
      id: json['id'] as int,
      ruleName: json['rule_name'] as String? ?? '',
      ruleDescription: json['rule_description'] as String?,
      category: json['category'] as String? ?? 'product_qr_scan',
      pointsAwarded: json['points_awarded'] as int?,
      pointsRequired: json['points_required'] as int?,
      minTransactionValue: json['min_transaction_value'] != null
          ? double.tryParse(json['min_transaction_value'].toString())
          : null,
      maxTransactionValue: json['max_transaction_value'] != null
          ? double.tryParse(json['max_transaction_value'].toString())
          : null,
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'] as String)
          : null,
      effectiveTo: json['effective_to'] != null
          ? DateTime.tryParse(json['effective_to'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      createdBy: json['created_by'] as int?,
      updatedBy: json['updated_by'] as int?,
      createdByName: json['created_by_name'] as String?,
      updatedByName: json['updated_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rule_name': ruleName,
        'rule_description': ruleDescription,
        'category': category,
        'points_awarded': pointsAwarded,
        'points_required': pointsRequired,
        'min_transaction_value': minTransactionValue,
        'max_transaction_value': maxTransactionValue,
        'effective_from': effectiveFrom?.toIso8601String(),
        'effective_to': effectiveTo?.toIso8601String(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'updated_by': updatedBy,
        'created_by_name': createdByName,
        'updated_by_name': updatedByName,
      };

  AdminPointsRule copyWith({
    int? id,
    String? ruleName,
    String? ruleDescription,
    String? category,
    int? pointsAwarded,
    int? pointsRequired,
    double? minTransactionValue,
    double? maxTransactionValue,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? createdBy,
    int? updatedBy,
    String? createdByName,
    String? updatedByName,
  }) {
    return AdminPointsRule(
      id: id ?? this.id,
      ruleName: ruleName ?? this.ruleName,
      ruleDescription: ruleDescription ?? this.ruleDescription,
      category: category ?? this.category,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      pointsRequired: pointsRequired ?? this.pointsRequired,
      minTransactionValue: minTransactionValue ?? this.minTransactionValue,
      maxTransactionValue: maxTransactionValue ?? this.maxTransactionValue,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdByName: createdByName ?? this.createdByName,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}

class AdminPointsRuleListResponse {
  const AdminPointsRuleListResponse({
    required this.items,
    required this.total,
  });

  final List<AdminPointsRule> items;
  final int total;

  factory AdminPointsRuleListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return AdminPointsRuleListResponse(
      items: list
          .map((item) => AdminPointsRule.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? list.length,
    );
  }
}

class AdminPointsRulePayload {
  const AdminPointsRulePayload({
    required this.ruleName,
    this.ruleDescription,
    required this.category,
    this.pointsAwarded,
    this.pointsRequired,
    this.minTransactionValue,
    this.maxTransactionValue,
    this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
  });

  final String ruleName;
  final String? ruleDescription;
  final String category;
  final int? pointsAwarded;
  final int? pointsRequired;
  final double? minTransactionValue;
  final double? maxTransactionValue;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'rule_name': ruleName.trim(),
      'category': category,
      'is_active': isActive,
    };

    if (ruleDescription != null) {
      map['rule_description'] = ruleDescription!.trim().isEmpty
          ? null
          : ruleDescription!.trim();
    }
    if (pointsAwarded != null) {
      map['points_awarded'] = pointsAwarded;
    }
    if (pointsRequired != null) {
      map['points_required'] = pointsRequired;
    }
    if (minTransactionValue != null) {
      map['min_transaction_value'] = minTransactionValue;
    }
    if (maxTransactionValue != null) {
      map['max_transaction_value'] = maxTransactionValue;
    }
    if (effectiveFrom != null) {
      map['effective_from'] = effectiveFrom!.toUtc().toIso8601String();
    }
    if (effectiveTo != null) {
      map['effective_to'] = effectiveTo!.toUtc().toIso8601String();
    }

    return map;
  }
}
