class AdminQrBatch {
  final int id;
  final String batchNumber;
  final String qrType;
  final String? description;
  final int? pointsRuleId;
  final String? pointsRuleName;
  final int? productId;
  final String? productName;
  final int? targetUserId;
  final String? targetUserName;
  final int quantity;
  final String status;
  final int activeCount;
  final int redeemedCount;
  final int voidedCount;
  final int? createdBy;
  final String? createdByName;
  final DateTime createdAt;

  const AdminQrBatch({
    required this.id,
    required this.batchNumber,
    required this.qrType,
    this.description,
    this.pointsRuleId,
    this.pointsRuleName,
    this.productId,
    this.productName,
    this.targetUserId,
    this.targetUserName,
    required this.quantity,
    required this.status,
    required this.activeCount,
    required this.redeemedCount,
    required this.voidedCount,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
  });

  String get typeLabel {
    switch (qrType.toLowerCase()) {
      case 'product':
        return 'Product QR';
      case 'invoice':
        return 'Invoice QR';
      case 'staff':
        return 'Staff QR';
      case 'partner':
        return 'Partner QR';
      default:
        return qrType.toUpperCase();
    }
  }

  factory AdminQrBatch.fromJson(Map<String, dynamic> json) {
    return AdminQrBatch(
      id: json['id'] as int,
      batchNumber: json['batch_number'] as String,
      qrType: json['qr_type'] as String,
      description: json['description'] as String?,
      pointsRuleId: json['points_rule_id'] as int?,
      pointsRuleName: json['points_rule_name'] as String?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      targetUserId: json['target_user_id'] as int?,
      targetUserName: json['target_user_name'] as String?,
      quantity: json['quantity'] as int,
      status: json['status'] as String? ?? 'completed',
      activeCount: json['active_count'] as int? ?? 0,
      redeemedCount: json['redeemed_count'] as int? ?? 0,
      voidedCount: json['voided_count'] as int? ?? 0,
      createdBy: json['created_by'] as int?,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_number': batchNumber,
      'qr_type': qrType,
      'description': description,
      'points_rule_id': pointsRuleId,
      'points_rule_name': pointsRuleName,
      'product_id': productId,
      'product_name': productName,
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'quantity': quantity,
      'status': status,
      'active_count': activeCount,
      'redeemed_count': redeemedCount,
      'voided_count': voidedCount,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AdminQrCode {
  final int id;
  final int batchId;
  final String qrType;
  final String token;
  final String codeData;
  final int? pointsAwarded;
  final int? productId;
  final String? productName;
  final int? targetUserId;
  final String? targetUserName;
  final String status;
  final int? redeemedBy;
  final DateTime? redeemedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const AdminQrCode({
    required this.id,
    required this.batchId,
    required this.qrType,
    required this.token,
    required this.codeData,
    this.pointsAwarded,
    this.productId,
    this.productName,
    this.targetUserId,
    this.targetUserName,
    required this.status,
    this.redeemedBy,
    this.redeemedAt,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isRedeemed => status.toLowerCase() == 'redeemed';
  bool get isVoided => status.toLowerCase() == 'voided';

  factory AdminQrCode.fromJson(Map<String, dynamic> json) {
    return AdminQrCode(
      id: json['id'] as int,
      batchId: json['batch_id'] as int,
      qrType: json['qr_type'] as String,
      token: json['token'] as String,
      codeData: json['code_data'] as String,
      pointsAwarded: json['points_awarded'] as int?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      targetUserId: json['target_user_id'] as int?,
      targetUserName: json['target_user_name'] as String?,
      status: json['status'] as String? ?? 'active',
      redeemedBy: json['redeemed_by'] as int?,
      redeemedAt: json['redeemed_at'] != null ? DateTime.parse(json['redeemed_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'qr_type': qrType,
      'token': token,
      'code_data': codeData,
      'points_awarded': pointsAwarded,
      'product_id': productId,
      'product_name': productName,
      'target_user_id': targetUserId,
      'target_user_name': targetUserName,
      'status': status,
      'redeemed_by': redeemedBy,
      'redeemed_at': redeemedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AdminQrBatchListResponse {
  final List<AdminQrBatch> items;
  final int total;

  const AdminQrBatchListResponse({required this.items, required this.total});

  factory AdminQrBatchListResponse.fromJson(Map<String, dynamic> json) {
    return AdminQrBatchListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AdminQrBatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}

class AdminQrCodeListResponse {
  final List<AdminQrCode> items;
  final int total;

  const AdminQrCodeListResponse({required this.items, required this.total});

  factory AdminQrCodeListResponse.fromJson(Map<String, dynamic> json) {
    return AdminQrCodeListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => AdminQrCode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}

class AdminQrBatchPayload {
  final String qrType;
  final int quantity;
  final String? description;
  final int? pointsRuleId;
  final int? productId;
  final int? targetUserId;

  const AdminQrBatchPayload({
    required this.qrType,
    required this.quantity,
    this.description,
    this.pointsRuleId,
    this.productId,
    this.targetUserId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'qr_type': qrType,
      'quantity': quantity,
    };
    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    if (pointsRuleId != null) {
      map['points_rule_id'] = pointsRuleId;
    }
    if (productId != null) {
      map['product_id'] = productId;
    }
    if (targetUserId != null) {
      map['target_user_id'] = targetUserId;
    }
    return map;
  }
}

class ProductQrLabelItem {
  final int productId;
  final String productName;
  final String productCode;
  final String qrNumber;

  const ProductQrLabelItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.qrNumber,
  });

  factory ProductQrLabelItem.fromJson(Map<String, dynamic> json) {
    return ProductQrLabelItem(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String? ?? '',
      productCode: json['product_code'] as String? ?? '',
      qrNumber: json['qr_number'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'product_code': productCode,
        'qr_number': qrNumber,
      };
}

class ProductQrLabelListResponse {
  final List<ProductQrLabelItem> items;
  final int total;

  const ProductQrLabelListResponse({required this.items, required this.total});

  factory ProductQrLabelListResponse.fromJson(Map<String, dynamic> json) {
    return ProductQrLabelListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ProductQrLabelItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}
