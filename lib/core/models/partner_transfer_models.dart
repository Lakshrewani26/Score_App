import 'package:flutter/foundation.dart';

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
