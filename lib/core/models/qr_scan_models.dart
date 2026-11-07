/// Request payload for scanning a QR code and awarding loyalty points.
class QrScanRequest {
  final String? codeData;
  final String? token;
  final String? idempotencyKey;

  const QrScanRequest({
    this.codeData,
    this.token,
    this.idempotencyKey,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (codeData != null && codeData!.isNotEmpty) {
      map['code_data'] = codeData;
    }
    if (token != null && token!.isNotEmpty) {
      map['token'] = token;
    }
    if (idempotencyKey != null && idempotencyKey!.isNotEmpty) {
      map['idempotency_key'] = idempotencyKey;
    }
    return map;
  }
}

/// Response returned when a QR code is scanned and points are awarded.
class QrScanResult {
  final bool success;
  final String message;
  final int pointsAwarded;
  final int newBalance;
  final String qrToken;
  final String qrType;
  final int ruleId;
  final String ruleName;
  final int ruleVersion;
  final DateTime scannedAt;
  final bool isIdempotentReplay;

  const QrScanResult({
    required this.success,
    required this.message,
    required this.pointsAwarded,
    required this.newBalance,
    required this.qrToken,
    required this.qrType,
    required this.ruleId,
    required this.ruleName,
    required this.ruleVersion,
    required this.scannedAt,
    this.isIdempotentReplay = false,
  });

  factory QrScanResult.fromJson(Map<String, dynamic> json) {
    return QrScanResult(
      success: json['success'] as bool? ?? false,
      message: (json['message'] ?? '').toString(),
      pointsAwarded: (json['points_awarded'] as num?)?.toInt() ?? 0,
      newBalance: (json['new_balance'] as num?)?.toInt() ?? 0,
      qrToken: (json['qr_token'] ?? '').toString(),
      qrType: (json['qr_type'] ?? '').toString(),
      ruleId: (json['rule_id'] as num?)?.toInt() ?? 0,
      ruleName: (json['rule_name'] ?? '').toString(),
      ruleVersion: (json['rule_version'] as num?)?.toInt() ?? 1,
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isIdempotentReplay: json['is_idempotent_replay'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'points_awarded': pointsAwarded,
      'new_balance': newBalance,
      'qr_token': qrToken,
      'qr_type': qrType,
      'rule_id': ruleId,
      'rule_name': ruleName,
      'rule_version': ruleVersion,
      'scanned_at': scannedAt.toIso8601String(),
      'is_idempotent_replay': isIdempotentReplay,
    };
  }
}

/// Representation of an immutable point transaction.
class PointTransactionItem {
  final int id;
  final int userId;
  final int qrCodeId;
  final String qrToken;
  final int pointsRuleId;
  final String? pointsRuleName;
  final int? pointsRuleVersion;
  final int pointsAwarded;
  final String qrType;
  final String transactionType;
  final String? idempotencyKey;
  final DateTime createdAt;

  const PointTransactionItem({
    required this.id,
    required this.userId,
    required this.qrCodeId,
    required this.qrToken,
    required this.pointsRuleId,
    this.pointsRuleName,
    this.pointsRuleVersion,
    required this.pointsAwarded,
    required this.qrType,
    required this.transactionType,
    this.idempotencyKey,
    required this.createdAt,
  });

  factory PointTransactionItem.fromJson(Map<String, dynamic> json) {
    return PointTransactionItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      qrCodeId: (json['qr_code_id'] as num?)?.toInt() ?? 0,
      qrToken: (json['qr_token'] ?? '').toString(),
      pointsRuleId: (json['points_rule_id'] as num?)?.toInt() ?? 0,
      pointsRuleName: json['points_rule_name'] as String?,
      pointsRuleVersion: (json['points_rule_version'] as num?)?.toInt(),
      pointsAwarded: (json['points_awarded'] as num?)?.toInt() ?? 0,
      qrType: (json['qr_type'] ?? '').toString(),
      transactionType: (json['transaction_type'] ?? 'qr_scan').toString(),
      idempotencyKey: json['idempotency_key'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
