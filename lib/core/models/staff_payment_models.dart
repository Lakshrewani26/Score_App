import 'package:flutter/foundation.dart';

@immutable
class PaymentReviewDetail {
  const PaymentReviewDetail({
    this.changedBy,
    this.changedByName,
    required this.changedAt,
    this.oldStatus,
    required this.newStatus,
    this.remarks,
  });

  final int? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? oldStatus;
  final String newStatus;
  final String? remarks;

  factory PaymentReviewDetail.fromJson(Map<String, dynamic> json) {
    return PaymentReviewDetail(
      changedBy: json['changed_by'] as int?,
      changedByName: json['changed_by_name'] as String?,
      changedAt: DateTime.tryParse(json['changed_at']?.toString() ?? '') ??
          DateTime.now(),
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String? ?? '',
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'changed_by': changedBy,
        'changed_by_name': changedByName,
        'changed_at': changedAt.toIso8601String(),
        'old_status': oldStatus,
        'new_status': newStatus,
        'remarks': remarks,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentReviewDetail &&
          runtimeType == other.runtimeType &&
          changedBy == other.changedBy &&
          changedByName == other.changedByName &&
          changedAt == other.changedAt &&
          oldStatus == other.oldStatus &&
          newStatus == other.newStatus &&
          remarks == other.remarks;

  @override
  int get hashCode =>
      changedBy.hashCode ^
      changedByName.hashCode ^
      changedAt.hashCode ^
      oldStatus.hashCode ^
      newStatus.hashCode ^
      remarks.hashCode;

  @override
  String toString() =>
      'PaymentReviewDetail(by: $changedByName, status: $newStatus, at: $changedAt)';
}

@immutable
class StaffPaymentRecordItem {
  const StaffPaymentRecordItem({
    required this.id,
    required this.staffId,
    required this.partnerId,
    this.partnerName,
    this.businessName,
    this.partnerMobile,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    required this.status,
    required this.recordedBy,
    this.recordedByName,
    required this.recordedAt,
    this.notes,
    this.latestReview,
    this.statusHistory = const [],
  });

  final int id;
  final int staffId;
  final int partnerId;
  final String? partnerName;
  final String? businessName;
  final String? partnerMobile;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final String status;
  final int recordedBy;
  final String? recordedByName;
  final DateTime recordedAt;
  final String? notes;
  final PaymentReviewDetail? latestReview;
  final List<PaymentReviewDetail> statusHistory;

  bool get isRecorded => status.toLowerCase() == 'recorded';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isVoided => status.toLowerCase() == 'voided';

  String get displayDealerName {
    if (businessName != null && businessName!.trim().isNotEmpty) {
      return businessName!.trim();
    }
    if (partnerName != null && partnerName!.trim().isNotEmpty) {
      return partnerName!.trim();
    }
    return 'Dealer #$partnerId';
  }

  String get displayReference {
    if (referenceNumber != null && referenceNumber!.trim().isNotEmpty) {
      return referenceNumber!.trim();
    }
    return 'PAY-$id';
  }

  factory StaffPaymentRecordItem.fromJson(Map<String, dynamic> json) {
    double parsedAmount = 0.0;
    final rawAmount = json['amount'];
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount = double.tryParse(rawAmount) ?? 0.0;
    }

    final rawHistory = json['status_history'];
    final historyList = <PaymentReviewDetail>[];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map<String, dynamic>) {
          historyList.add(PaymentReviewDetail.fromJson(item));
        }
      }
    }

    PaymentReviewDetail? review;
    if (json['latest_review'] is Map<String, dynamic>) {
      review = PaymentReviewDetail.fromJson(
          json['latest_review'] as Map<String, dynamic>);
    } else if (historyList.isNotEmpty) {
      review = historyList.first;
    }

    return StaffPaymentRecordItem(
      id: json['id'] as int? ?? 0,
      staffId: json['staff_id'] as int? ?? 0,
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: json['partner_name'] as String?,
      businessName: json['business_name'] as String?,
      partnerMobile: json['partner_mobile'] as String?,
      amount: parsedAmount,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      referenceNumber: json['reference_number'] as String?,
      status: json['status'] as String? ?? 'recorded',
      recordedBy: json['recorded_by'] as int? ?? 0,
      recordedByName: json['recorded_by_name'] as String?,
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
          DateTime.now(),
      notes: json['notes'] as String?,
      latestReview: review,
      statusHistory: historyList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'staff_id': staffId,
        'partner_id': partnerId,
        'partner_name': partnerName,
        'business_name': businessName,
        'partner_mobile': partnerMobile,
        'amount': amount,
        'payment_method': paymentMethod,
        'reference_number': referenceNumber,
        'status': status,
        'recorded_by': recordedBy,
        'recorded_by_name': recordedByName,
        'recorded_at': recordedAt.toIso8601String(),
        'notes': notes,
        'latest_review': latestReview?.toJson(),
        'status_history': statusHistory.map((h) => h.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentRecordItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          staffId == other.staffId &&
          partnerId == other.partnerId &&
          amount == other.amount &&
          paymentMethod == other.paymentMethod &&
          referenceNumber == other.referenceNumber &&
          status == other.status &&
          recordedAt == other.recordedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      staffId.hashCode ^
      partnerId.hashCode ^
      amount.hashCode ^
      paymentMethod.hashCode ^
      referenceNumber.hashCode ^
      status.hashCode ^
      recordedAt.hashCode;

  @override
  String toString() =>
      'StaffPaymentRecordItem(id: $id, amount: $amount, status: $status, dealer: $displayDealerName)';
}

@immutable
class StaffPaymentListResponse {
  const StaffPaymentListResponse({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.pageSize = 20,
    this.totalPages = 0,
    this.hasNext = false,
    this.hasPrev = false,
  });

  final List<StaffPaymentRecordItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  factory StaffPaymentListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemList = <StaffPaymentRecordItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          itemList.add(StaffPaymentRecordItem.fromJson(item));
        }
      }
    }

    return StaffPaymentListResponse(
      items: List.unmodifiable(itemList),
      total: (json['total'] as num?)?.toInt() ?? itemList.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ??
          (itemList.isNotEmpty ? 1 : 0),
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentListResponse &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          page == other.page &&
          pageSize == other.pageSize &&
          totalPages == other.totalPages &&
          hasNext == other.hasNext &&
          hasPrev == other.hasPrev &&
          listEquals(items, other.items);

  @override
  int get hashCode =>
      total.hashCode ^
      page.hashCode ^
      pageSize.hashCode ^
      totalPages.hashCode ^
      hasNext.hashCode ^
      hasPrev.hashCode ^
      items.hashCode;

  @override
  String toString() =>
      'StaffPaymentListResponse(total: $total, page: $page/$totalPages, count: ${items.length})';
}
