import 'package:flutter/foundation.dart';

@immutable
class PartnerBalance {
  const PartnerBalance({
    required this.pointsEarned,
    required this.pointsSpent,
    required this.currentBalance,
  });

  final int pointsEarned;
  final int pointsSpent;
  final int currentBalance;

  factory PartnerBalance.fromJson(Map<String, dynamic> json) {
    return PartnerBalance(
      pointsEarned: ((json['points_earned'] ??
              json['total_earned_points'] ??
              json['total_points'] ??
              0) as num)
          .toInt(),
      pointsSpent: ((json['points_spent'] ??
              json['total_spent_points'] ??
              json['points_used'] ??
              0) as num)
          .toInt(),
      currentBalance: ((json['current_balance'] ??
              json['remaining_balance'] ??
              0) as num)
          .toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'points_earned': pointsEarned,
        'points_spent': pointsSpent,
        'current_balance': currentBalance,
        'total_earned_points': pointsEarned,
        'total_spent_points': pointsSpent,
        'remaining_balance': currentBalance,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerBalance &&
          runtimeType == other.runtimeType &&
          pointsEarned == other.pointsEarned &&
          pointsSpent == other.pointsSpent &&
          currentBalance == other.currentBalance;

  @override
  int get hashCode =>
      pointsEarned.hashCode ^ pointsSpent.hashCode ^ currentBalance.hashCode;

  @override
  String toString() =>
      'PartnerBalance(earned: $pointsEarned, spent: $pointsSpent, current: $currentBalance)';
}

@immutable
class StaffQrRecipient {
  const StaffQrRecipient({
    required this.staffUserId,
    required this.staffName,
    this.staffId,
    required this.qrCodeId,
    required this.qrType,
  });

  final int staffUserId;
  final String staffName;
  final String? staffId;
  final int qrCodeId;
  final String qrType;

  factory StaffQrRecipient.fromJson(Map<String, dynamic> json) {
    return StaffQrRecipient(
      staffUserId: (json['staff_user_id'] as num).toInt(),
      staffName: (json['staff_name'] ?? '').toString(),
      staffId: json['staff_id'] as String?,
      qrCodeId: (json['qr_code_id'] as num).toInt(),
      qrType: (json['qr_type'] ?? 'staff').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'staff_user_id': staffUserId,
        'staff_name': staffName,
        if (staffId != null) 'staff_id': staffId,
        'qr_code_id': qrCodeId,
        'qr_type': qrType,
      };

  @override
  String toString() =>
      'StaffQrRecipient(staffUserId: $staffUserId, staffName: $staffName, staffId: $staffId)';
}

@immutable
class PartnerTransferResponse {
  const PartnerTransferResponse({
    required this.transferId,
    required this.amount,
    required this.senderId,
    required this.recipientId,
    this.recipientName,
    this.recipientStaffId,
    this.createdAt,
    required this.senderBalance,
    required this.recipientBalance,
    this.isIdempotentReplay = false,
  });

  final int transferId;
  final int amount;
  final int senderId;
  final int recipientId;
  final String? recipientName;
  final String? recipientStaffId;
  final DateTime? createdAt;
  final int senderBalance;
  final int recipientBalance;
  final bool isIdempotentReplay;

  factory PartnerTransferResponse.fromJson(Map<String, dynamic> json) {
    return PartnerTransferResponse(
      transferId: (json['transfer_id'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      recipientId: (json['recipient_id'] as num).toInt(),
      recipientName: json['recipient_name'] as String?,
      recipientStaffId: json['recipient_staff_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      senderBalance: (json['sender_balance'] as num).toInt(),
      recipientBalance: (json['recipient_balance'] as num).toInt(),
      isIdempotentReplay: json['is_idempotent_replay'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'transfer_id': transferId,
        'amount': amount,
        'sender_id': senderId,
        'recipient_id': recipientId,
        if (recipientName != null) 'recipient_name': recipientName,
        if (recipientStaffId != null) 'recipient_staff_id': recipientStaffId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'sender_balance': senderBalance,
        'recipient_balance': recipientBalance,
        'is_idempotent_replay': isIdempotentReplay,
      };

  @override
  String toString() =>
      'PartnerTransferResponse(transferId: $transferId, amount: $amount, senderBalance: $senderBalance, isReplay: $isIdempotentReplay)';
}

@immutable
class PartnerPointHistoryItem {
  const PartnerPointHistoryItem({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.points,
    required this.amount,
    required this.title,
    this.description,
    this.referenceId,
    this.recipientName,
    this.recipientStaffId,
    this.senderName,
    required this.createdAt,
  });

  final String id;
  final String transactionType;
  final String direction;
  final int points;
  final int amount;
  final String title;
  final String? description;
  final String? referenceId;
  final String? recipientName;
  final String? recipientStaffId;
  final String? senderName;
  final DateTime createdAt;

  bool get isCredit => direction.toLowerCase() == 'credit' || points > 0;
  bool get isDebit => direction.toLowerCase() == 'debit' || points < 0;

  factory PartnerPointHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return PartnerPointHistoryItem(
      id: (json['id'] ?? '').toString(),
      transactionType: (json['transaction_type'] ?? 'qr_scan').toString(),
      direction: (json['direction'] ?? 'credit').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientStaffId: json['recipient_staff_id'] as String?,
      senderName: json['sender_name'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transaction_type': transactionType,
        'direction': direction,
        'points': points,
        'amount': amount,
        'title': title,
        if (description != null) 'description': description,
        if (referenceId != null) 'reference_id': referenceId,
        if (recipientName != null) 'recipient_name': recipientName,
        if (recipientStaffId != null) 'recipient_staff_id': recipientStaffId,
        if (senderName != null) 'sender_name': senderName,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerPointHistoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PartnerPointHistoryItem(id: $id, type: $transactionType, dir: $direction, pts: $points)';
}

@immutable
class PartnerPointsHistoryResponse {
  const PartnerPointsHistoryResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final List<PartnerPointHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory PartnerPointsHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = <PartnerPointHistoryItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(PartnerPointHistoryItem.fromJson(item));
        }
      }
    }

    return PartnerPointsHistoryResponse(
      items: itemsList,
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrev: json['has_prev'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
        'has_next': hasNext,
        'has_prev': hasPrev,
      };

  @override
  String toString() =>
      'PartnerPointsHistoryResponse(total: $total, page: $page/$totalPages, count: ${items.length})';
}
