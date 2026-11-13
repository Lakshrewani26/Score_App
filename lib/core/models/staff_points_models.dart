import 'package:flutter/foundation.dart';

@immutable
class StaffBalance {
  const StaffBalance({
    required this.pointsEarned,
    required this.pointsSpent,
    required this.currentBalance,
  });

  final int pointsEarned;
  final int pointsSpent;
  final int currentBalance;

  factory StaffBalance.fromJson(Map<String, dynamic> json) {
    return StaffBalance(
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
      other is StaffBalance &&
          runtimeType == other.runtimeType &&
          pointsEarned == other.pointsEarned &&
          pointsSpent == other.pointsSpent &&
          currentBalance == other.currentBalance;

  @override
  int get hashCode =>
      pointsEarned.hashCode ^ pointsSpent.hashCode ^ currentBalance.hashCode;

  @override
  String toString() =>
      'StaffBalance(earned: $pointsEarned, spent: $pointsSpent, current: $currentBalance)';
}

@immutable
class StaffPointHistoryItem {
  const StaffPointHistoryItem({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.points,
    required this.amount,
    required this.title,
    this.description,
    this.referenceId,
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
  final String? senderName;
  final DateTime createdAt;

  bool get isCredit => direction.toLowerCase() == 'credit' || points > 0;
  bool get isDebit => direction.toLowerCase() == 'debit' || points < 0;

  factory StaffPointHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['created_at'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return StaffPointHistoryItem(
      id: (json['id'] ?? '').toString(),
      transactionType: (json['transaction_type'] ?? 'transfer_received').toString(),
      direction: (json['direction'] ?? 'credit').toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
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
        if (senderName != null) 'sender_name': senderName,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPointHistoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'StaffPointHistoryItem(id: $id, type: $transactionType, dir: $direction, pts: $points)';
}

@immutable
class StaffPointsHistoryResponse {
  const StaffPointsHistoryResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  final List<StaffPointHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory StaffPointsHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = <StaffPointHistoryItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemsList.add(StaffPointHistoryItem.fromJson(item));
        }
      }
    }

    return StaffPointsHistoryResponse(
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
      'StaffPointsHistoryResponse(total: $total, page: $page/$totalPages, count: ${items.length})';
}
