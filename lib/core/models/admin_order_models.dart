String formatCurrency(num? value, {String fallback = 'Price not set'}) {
  if (value == null) {
    return fallback;
  }
  final rounded = value.toStringAsFixed(2);
  final integerPart = rounded.split('.').first;
  final decimalPart = rounded.split('.').last;
  final thousands = integerPart.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (Match match) => '${match[1]},',
  );
  return '₹$thousands.$decimalPart';
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day $month $year, $hour:$minute $ampm';
}

String formatStatus(String status) {
  switch (status.toLowerCase()) {
    case 'pending_approval':
      return 'Pending Approval';
    case 'approved_processing':
      return 'Processing';
    case 'dispatched':
      return 'Dispatched';
    case 'delivered':
      return 'Delivered';
    case 'rejected':
      return 'Rejected';
    case 'approved':
      return 'Approved';
    default:
      return status;
  }
}

class AdminOrderItem {
  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final String vehicleType;
  final int quantity;
  final num? unitPrice;
  final num? subtotal;

  const AdminOrderItem({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.vehicleType,
    required this.quantity,
    this.unitPrice,
    this.subtotal,
  });

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    final rawUnitPrice = json['unit_price'];
    final rawSubtotal = json['subtotal'];
    num? parsedUnitPrice;
    num? parsedSubtotal;

    if (rawUnitPrice != null && rawUnitPrice.toString().trim().isNotEmpty) {
      parsedUnitPrice = num.tryParse(rawUnitPrice.toString());
    }
    if (rawSubtotal != null && rawSubtotal.toString().trim().isNotEmpty) {
      parsedSubtotal = num.tryParse(rawSubtotal.toString());
    }

    return AdminOrderItem(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productCode: (json['product_code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      vehicleType: (json['vehicle_type'] ?? 'Both').toString(),
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: parsedUnitPrice,
      subtotal: parsedSubtotal,
    );
  }

  String get displayUnitPrice => formatCurrency(unitPrice);
  String get displaySubtotal => formatCurrency(subtotal);
}

class AdminOrderStatusHistory {
  final int id;
  final String? oldStatus;
  final String newStatus;
  final int? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? remarks;

  const AdminOrderStatusHistory({
    required this.id,
    this.oldStatus,
    required this.newStatus,
    this.changedBy,
    this.changedByName,
    required this.changedAt,
    this.remarks,
  });

  factory AdminOrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return AdminOrderStatusHistory(
      id: json['id'] as int? ?? 0,
      oldStatus: json['old_status'] as String?,
      newStatus: (json['new_status'] ?? '').toString(),
      changedBy: json['changed_by'] as int?,
      changedByName: json['changed_by_name'] as String?,
      changedAt: json['changed_at'] != null
          ? DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      remarks: json['remarks'] as String?,
    );
  }

  String get displayNewStatus => formatStatus(newStatus);
  String get displayDate => formatDateTime(changedAt);
}

class AdminOrderSummary {
  final int id;
  final String orderNumber;
  final int partnerId;
  final String partnerName;
  final String? businessName;
  final String partnerMobile;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final int? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final int itemCount;
  final int totalQuantity;
  final num? orderTotal;

  const AdminOrderSummary({
    required this.id,
    required this.orderNumber,
    required this.partnerId,
    required this.partnerName,
    this.businessName,
    required this.partnerMobile,
    required this.status,
    this.notes,
    required this.createdAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.itemCount,
    required this.totalQuantity,
    this.orderTotal,
  });

  factory AdminOrderSummary.fromJson(Map<String, dynamic> json) {
    final rawTotal = json['order_total'];
    num? parsedTotal;
    if (rawTotal != null && rawTotal.toString().trim().isNotEmpty) {
      parsedTotal = num.tryParse(rawTotal.toString());
    }

    return AdminOrderSummary(
      id: json['id'] as int? ?? 0,
      orderNumber: (json['order_number'] ?? '').toString(),
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: (json['partner_name'] ?? '').toString(),
      businessName: json['business_name'] as String?,
      partnerMobile: (json['partner_mobile'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      approvedBy: json['approved_by'] as int?,
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      itemCount: json['item_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      orderTotal: parsedTotal,
    );
  }

  String get displayStatus => formatStatus(status);
  String get displayOrderTotal => formatCurrency(orderTotal);
  String get displayDate => formatDateTime(createdAt);

  bool get canDispatch => status == 'approved_processing';
  bool get canDeliver => status == 'dispatched';
}

class AdminOrderDetail extends AdminOrderSummary {
  final List<AdminOrderItem> items;
  final List<AdminOrderStatusHistory> statusHistory;

  const AdminOrderDetail({
    required super.id,
    required super.orderNumber,
    required super.partnerId,
    required super.partnerName,
    super.businessName,
    required super.partnerMobile,
    required super.status,
    super.notes,
    required super.createdAt,
    super.approvedBy,
    super.approvedByName,
    super.approvedAt,
    required super.itemCount,
    required super.totalQuantity,
    super.orderTotal,
    required this.items,
    required this.statusHistory,
  });

  factory AdminOrderDetail.fromJson(Map<String, dynamic> json) {
    final summary = AdminOrderSummary.fromJson(json);
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawHistory = json['status_history'] as List<dynamic>? ?? [];

    return AdminOrderDetail(
      id: summary.id,
      orderNumber: summary.orderNumber,
      partnerId: summary.partnerId,
      partnerName: summary.partnerName,
      businessName: summary.businessName,
      partnerMobile: summary.partnerMobile,
      status: summary.status,
      notes: summary.notes,
      createdAt: summary.createdAt,
      approvedBy: summary.approvedBy,
      approvedByName: summary.approvedByName,
      approvedAt: summary.approvedAt,
      itemCount: summary.itemCount,
      totalQuantity: summary.totalQuantity,
      orderTotal: summary.orderTotal,
      items: rawItems
          .map((i) => AdminOrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      statusHistory: rawHistory
          .map((h) => AdminOrderStatusHistory.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaginatedOrdersResponse {
  final List<AdminOrderSummary> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedOrdersResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedOrdersResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedOrdersResponse(
      items: rawItems
          .map((i) => AdminOrderSummary.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Request Models
// ---------------------------------------------------------------------------

class AdminStockRequestItem {
  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final String vehicleType;
  final int quantity;

  const AdminStockRequestItem({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.vehicleType,
    required this.quantity,
  });

  factory AdminStockRequestItem.fromJson(Map<String, dynamic> json) {
    return AdminStockRequestItem(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productCode: (json['product_code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      vehicleType: (json['vehicle_type'] ?? 'Both').toString(),
      quantity: json['quantity'] as int? ?? 0,
    );
  }
}

class AdminStockRequestStatusHistory {
  final int id;
  final String? oldStatus;
  final String newStatus;
  final int? changedBy;
  final String? changedByName;
  final DateTime changedAt;
  final String? remarks;

  const AdminStockRequestStatusHistory({
    required this.id,
    this.oldStatus,
    required this.newStatus,
    this.changedBy,
    this.changedByName,
    required this.changedAt,
    this.remarks,
  });

  factory AdminStockRequestStatusHistory.fromJson(Map<String, dynamic> json) {
    return AdminStockRequestStatusHistory(
      id: json['id'] as int? ?? 0,
      oldStatus: json['old_status'] as String?,
      newStatus: (json['new_status'] ?? '').toString(),
      changedBy: json['changed_by'] as int?,
      changedByName: json['changed_by_name'] as String?,
      changedAt: json['changed_at'] != null
          ? DateTime.tryParse(json['changed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      remarks: json['remarks'] as String?,
    );
  }

  String get displayNewStatus => formatStatus(newStatus);
  String get displayDate => formatDateTime(changedAt);
}

class AdminStockRequestSummary {
  final int id;
  final String requestNumber;
  final int partnerId;
  final String partnerName;
  final String? businessName;
  final String partnerMobile;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final int? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final int itemCount;
  final int totalQuantity;

  const AdminStockRequestSummary({
    required this.id,
    required this.requestNumber,
    required this.partnerId,
    required this.partnerName,
    this.businessName,
    required this.partnerMobile,
    required this.status,
    this.notes,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    required this.itemCount,
    required this.totalQuantity,
  });

  factory AdminStockRequestSummary.fromJson(Map<String, dynamic> json) {
    return AdminStockRequestSummary(
      id: json['id'] as int? ?? 0,
      requestNumber: (json['request_number'] ?? '').toString(),
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: (json['partner_name'] ?? '').toString(),
      businessName: json['business_name'] as String?,
      partnerMobile: (json['partner_mobile'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reviewedBy: json['reviewed_by'] as int?,
      reviewedByName: json['reviewed_by_name'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'].toString())
          : null,
      itemCount: json['item_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
    );
  }

  String get displayStatus => formatStatus(status);
  String get displayDate => formatDateTime(createdAt);
}

class AdminStockRequestDetail extends AdminStockRequestSummary {
  final List<AdminStockRequestItem> items;
  final List<AdminStockRequestStatusHistory> statusHistory;

  const AdminStockRequestDetail({
    required super.id,
    required super.requestNumber,
    required super.partnerId,
    required super.partnerName,
    super.businessName,
    required super.partnerMobile,
    required super.status,
    super.notes,
    required super.createdAt,
    super.reviewedBy,
    super.reviewedByName,
    super.reviewedAt,
    required super.itemCount,
    required super.totalQuantity,
    required this.items,
    required this.statusHistory,
  });

  factory AdminStockRequestDetail.fromJson(Map<String, dynamic> json) {
    final summary = AdminStockRequestSummary.fromJson(json);
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawHistory = json['status_history'] as List<dynamic>? ?? [];

    return AdminStockRequestDetail(
      id: summary.id,
      requestNumber: summary.requestNumber,
      partnerId: summary.partnerId,
      partnerName: summary.partnerName,
      businessName: summary.businessName,
      partnerMobile: summary.partnerMobile,
      status: summary.status,
      notes: summary.notes,
      createdAt: summary.createdAt,
      reviewedBy: summary.reviewedBy,
      reviewedByName: summary.reviewedByName,
      reviewedAt: summary.reviewedAt,
      itemCount: summary.itemCount,
      totalQuantity: summary.totalQuantity,
      items: rawItems
          .map((i) => AdminStockRequestItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      statusHistory: rawHistory
          .map((h) =>
              AdminStockRequestStatusHistory.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaginatedStockRequestsResponse {
  final List<AdminStockRequestSummary> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedStockRequestsResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedStockRequestsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedStockRequestsResponse(
      items: rawItems
          .map((i) =>
              AdminStockRequestSummary.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      totalPages: json['total_pages'] as int? ?? 0,
    );
  }
}
