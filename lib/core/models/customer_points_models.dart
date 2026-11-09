import 'package:flutter/foundation.dart';

@immutable
class CustomerBalance {
  const CustomerBalance({
    required this.pointsEarned,
    required this.pointsSpent,
    required this.currentBalance,
  });

  final int pointsEarned;
  final int pointsSpent;
  final int currentBalance;

  factory CustomerBalance.fromJson(Map<String, dynamic> json) {
    return CustomerBalance(
      pointsEarned: (json['points_earned'] ?? json['total_earned_points'] ?? 0) as int,
      pointsSpent: (json['points_spent'] ?? json['total_spent_points'] ?? 0) as int,
      currentBalance: (json['current_balance'] ?? json['remaining_balance'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'points_earned': pointsEarned,
      'points_spent': pointsSpent,
      'current_balance': currentBalance,
      'total_earned_points': pointsEarned,
      'total_spent_points': pointsSpent,
      'remaining_balance': currentBalance,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerBalance &&
          runtimeType == other.runtimeType &&
          pointsEarned == other.pointsEarned &&
          pointsSpent == other.pointsSpent &&
          currentBalance == other.currentBalance;

  @override
  int get hashCode =>
      pointsEarned.hashCode ^ pointsSpent.hashCode ^ currentBalance.hashCode;
}

@immutable
class CustomerPointHistoryItem {
  const CustomerPointHistoryItem({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.points,
    required this.amount,
    required this.title,
    this.description,
    this.referenceId,
    this.recipientName,
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
  final String? senderName;
  final DateTime createdAt;

  bool get isCredit => direction == 'credit' || points > 0;
  bool get isDebit => direction == 'debit' || points < 0;

  factory CustomerPointHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return CustomerPointHistoryItem(
      id: (json['id'] ?? '').toString(),
      transactionType: (json['transaction_type'] ?? 'qr_scan').toString(),
      direction: (json['direction'] ?? 'credit').toString(),
      points: (json['points'] ?? 0) as int,
      amount: (json['amount'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      recipientName: json['recipient_name'] as String?,
      senderName: json['sender_name'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type': transactionType,
      'direction': direction,
      'points': points,
      'amount': amount,
      'title': title,
      'description': description,
      'reference_id': referenceId,
      'recipient_name': recipientName,
      'sender_name': senderName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerPointHistoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class CustomerPointsHistoryResponse {
  const CustomerPointsHistoryResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final List<CustomerPointHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory CustomerPointsHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = <CustomerPointHistoryItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(CustomerPointHistoryItem.fromJson(item));
        }
      }
    }

    return CustomerPointsHistoryResponse(
      items: itemsList,
      total: (json['total'] ?? 0) as int,
      page: (json['page'] ?? 1) as int,
      pageSize: (json['page_size'] ?? 20) as int,
      totalPages: (json['total_pages'] ?? 0) as int,
      hasNext: (json['has_next'] ?? false) as bool,
      hasPrev: (json['has_prev'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((i) => i.toJson()).toList(),
      'total': total,
      'page': page,
      'page_size': pageSize,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_prev': hasPrev,
    };
  }
}
