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
    this.conversionRate,
    this.pointValue,
    this.minTransactionValue,
    this.maxTransactionValue,
    this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
    this.isCurrent = true,
    this.version = 1,
    this.parentRuleId,
    this.effectiveStatus = 'currently_effective',
    this.isCurrentlyEffective = true,
    this.isFutureScheduled = false,
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
  final double? conversionRate;
  final double? pointValue;
  final double? minTransactionValue;
  final double? maxTransactionValue;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final bool isCurrent;
  final int version;
  final int? parentRuleId;
  final String effectiveStatus;
  final bool isCurrentlyEffective;
  final bool isFutureScheduled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final String? createdByName;
  final String? updatedByName;

  String get categoryLabel {
    switch (category) {
      case 'customer_qr_scan':
        return 'Customer QR Scan';
      case 'partner_qr_scan':
        return 'Partner QR Scan';
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

  static String _deriveEffectiveStatus({
    required bool isActive,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
  }) {
    if (!isActive) return 'inactive';
    final now = DateTime.now();
    if (effectiveFrom != null && effectiveFrom.isAfter(now)) {
      return 'future_scheduled';
    }
    if (effectiveTo != null && effectiveTo.isBefore(now)) {
      return 'expired';
    }
    return 'currently_effective';
  }

  factory AdminPointsRule.fromJson(Map<String, dynamic> json) {
    final isActive = json['is_active'] as bool? ?? true;
    final effectiveFrom = json['effective_from'] != null
        ? DateTime.tryParse(json['effective_from'] as String)
        : null;
    final effectiveTo = json['effective_to'] != null
        ? DateTime.tryParse(json['effective_to'] as String)
        : null;
    final derivedStatus = _deriveEffectiveStatus(
      isActive: isActive,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
    );
    final statusStr = json['effective_status'] as String? ?? derivedStatus;

    return AdminPointsRule(
      id: json['id'] as int,
      ruleName: json['rule_name'] as String? ?? '',
      ruleDescription: json['rule_description'] as String?,
      category: json['category'] as String? ?? 'product_qr_scan',
      pointsAwarded: json['points_awarded'] as int?,
      pointsRequired: json['points_required'] as int?,
      conversionRate: json['conversion_rate'] != null
          ? double.tryParse(json['conversion_rate'].toString())
          : null,
      pointValue: json['point_value'] != null
          ? double.tryParse(json['point_value'].toString())
          : null,
      minTransactionValue: json['min_transaction_value'] != null
          ? double.tryParse(json['min_transaction_value'].toString())
          : null,
      maxTransactionValue: json['max_transaction_value'] != null
          ? double.tryParse(json['max_transaction_value'].toString())
          : null,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      isActive: isActive,
      isCurrent: json['is_current'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      parentRuleId: json['parent_rule_id'] as int?,
      effectiveStatus: statusStr,
      isCurrentlyEffective: json['is_currently_effective'] as bool? ??
          (statusStr == 'currently_effective'),
      isFutureScheduled: json['is_future_scheduled'] as bool? ??
          (statusStr == 'future_scheduled'),
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
        'conversion_rate': conversionRate,
        'point_value': pointValue,
        'min_transaction_value': minTransactionValue,
        'max_transaction_value': maxTransactionValue,
        'effective_from': effectiveFrom?.toIso8601String(),
        'effective_to': effectiveTo?.toIso8601String(),
        'is_active': isActive,
        'is_current': isCurrent,
        'version': version,
        'parent_rule_id': parentRuleId,
        'effective_status': effectiveStatus,
        'is_currently_effective': isCurrentlyEffective,
        'is_future_scheduled': isFutureScheduled,
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
    double? conversionRate,
    double? pointValue,
    double? minTransactionValue,
    double? maxTransactionValue,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isActive,
    bool? isCurrent,
    int? version,
    int? parentRuleId,
    String? effectiveStatus,
    bool? isCurrentlyEffective,
    bool? isFutureScheduled,
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
      conversionRate: conversionRate ?? this.conversionRate,
      pointValue: pointValue ?? this.pointValue,
      minTransactionValue: minTransactionValue ?? this.minTransactionValue,
      maxTransactionValue: maxTransactionValue ?? this.maxTransactionValue,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      isCurrent: isCurrent ?? this.isCurrent,
      version: version ?? this.version,
      parentRuleId: parentRuleId ?? this.parentRuleId,
      effectiveStatus: effectiveStatus ?? this.effectiveStatus,
      isCurrentlyEffective: isCurrentlyEffective ?? this.isCurrentlyEffective,
      isFutureScheduled: isFutureScheduled ?? this.isFutureScheduled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdByName: createdByName ?? this.createdByName,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}

class AdminPointsRuleHistoryResponse {
  const AdminPointsRuleHistoryResponse({
    required this.ruleId,
    required this.ruleName,
    required this.currentVersion,
    this.latestVersion = 1,
    this.effectiveVersion,
    required this.history,
  });

  final int ruleId;
  final String ruleName;
  final int currentVersion;
  final int latestVersion;
  final int? effectiveVersion;
  final List<AdminPointsRule> history;

  factory AdminPointsRuleHistoryResponse.fromJson(Map<String, dynamic> json) {
    final list = json['history'] as List<dynamic>? ?? [];
    return AdminPointsRuleHistoryResponse(
      ruleId: json['rule_id'] as int? ?? 0,
      ruleName: json['rule_name'] as String? ?? '',
      currentVersion: json['current_version'] as int? ?? 1,
      latestVersion: json['latest_version'] as int? ?? (json['current_version'] as int? ?? 1),
      effectiveVersion: json['effective_version'] as int?,
      history: list
          .map((item) => AdminPointsRule.fromJson(item as Map<String, dynamic>))
          .toList(),
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
    this.conversionRate,
    this.pointValue,
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
  final double? conversionRate;
  final double? pointValue;
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
    if (conversionRate != null) {
      map['conversion_rate'] = conversionRate;
    }
    if (pointValue != null) {
      map['point_value'] = pointValue;
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
