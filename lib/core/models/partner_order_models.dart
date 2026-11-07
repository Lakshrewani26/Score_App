import 'catalogue_models.dart';

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
  });

  final CatalogueProduct product;
  final int quantity;

  num? get unitPrice => product.price;
  num? get lineTotal {
    final price = product.price;
    return price == null ? null : price * quantity;
  }

  String get displayUnitPrice {
    if (product.price == null) {
      return 'Price unavailable';
    }
    return product.displayPrice;
  }

  String get displayLineTotal {
    if (product.price == null) {
      return 'N/A';
    }
    final total = lineTotal;
    if (total == null) {
      return 'N/A';
    }
    final rounded = total.toStringAsFixed(2);
    final integerPart = rounded.split('.').first;
    final decimalPart = rounded.split('.').last;
    final thousands = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '₹ $thousands.$decimalPart';
  }

  CartItem copyWith({CatalogueProduct? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class PartnerOrderItemResponse {
  const PartnerOrderItemResponse({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.vehicleType,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.originalPrice,
    this.discountPercentage,
    this.discountAmount,
    this.discountedPrice,
  });

  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final String vehicleType;
  final int quantity;
  final num unitPrice;
  final num subtotal;
  final num? originalPrice;
  final num? discountPercentage;
  final num? discountAmount;
  final num? discountedPrice;

  factory PartnerOrderItemResponse.fromJson(Map<String, dynamic> json) {
    return PartnerOrderItemResponse(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productCode: (json['product_code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      vehicleType: (json['vehicle_type'] ?? '').toString(),
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: num.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      subtotal: num.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      originalPrice: json['original_price'] != null
          ? num.tryParse(json['original_price'].toString())
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? num.tryParse(json['discount_percentage'].toString())
          : null,
      discountAmount: json['discount_amount'] != null
          ? num.tryParse(json['discount_amount'].toString())
          : null,
      discountedPrice: json['discounted_price'] != null
          ? num.tryParse(json['discounted_price'].toString())
          : null,
    );
  }
}

class PartnerOrderResponse {
  const PartnerOrderResponse({
    required this.id,
    required this.orderNumber,
    required this.partnerId,
    required this.partnerName,
    this.businessName,
    this.businessAddress,
    required this.partnerMobile,
    required this.status,
    this.notes,
    required this.createdAt,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.itemCount,
    required this.totalQuantity,
    required this.orderTotal,
    this.items = const [],
    this.subtotalBeforeDiscount,
    this.discountPercentage,
    this.totalDiscount,
    this.finalTotal,
  });

  final int id;
  final String orderNumber;
  final int partnerId;
  final String partnerName;
  final String? businessName;
  final String? businessAddress;
  final String partnerMobile;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final int? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final int itemCount;
  final int totalQuantity;
  final num orderTotal;
  final List<PartnerOrderItemResponse> items;
  final num? subtotalBeforeDiscount;
  final num? discountPercentage;
  final num? totalDiscount;
  final num? finalTotal;

  factory PartnerOrderResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PartnerOrderResponse(
      id: json['id'] as int? ?? 0,
      orderNumber: (json['order_number'] ?? '').toString(),
      partnerId: json['partner_id'] as int? ?? 0,
      partnerName: (json['partner_name'] ?? '').toString(),
      businessName: json['business_name'] as String?,
      businessAddress: json['business_address'] as String?,
      partnerMobile: (json['partner_mobile'] ?? '').toString(),
      status: (json['status'] ?? 'pending_approval').toString(),
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
      orderTotal: num.tryParse(json['order_total']?.toString() ?? '0') ?? 0,
      items: rawItems
          .map((item) =>
              PartnerOrderItemResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotalBeforeDiscount: json['subtotal_before_discount'] != null
          ? num.tryParse(json['subtotal_before_discount'].toString())
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? num.tryParse(json['discount_percentage'].toString())
          : null,
      totalDiscount: json['total_discount'] != null
          ? num.tryParse(json['total_discount'].toString())
          : null,
      finalTotal: json['final_total'] != null
          ? num.tryParse(json['final_total'].toString())
          : null,
    );
  }

  String get displayGrandTotal {
    final rounded = orderTotal.toStringAsFixed(2);
    final integerPart = rounded.split('.').first;
    final decimalPart = rounded.split('.').last;
    final thousands = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '₹ $thousands.$decimalPart';
  }
}

class WhatsAppDeliveryResult {
  const WhatsAppDeliveryResult({
    required this.success,
    required this.status,
    required this.message,
    this.recipient,
    required this.provider,
    this.messageId,
  });

  final bool success;
  final String status;
  final String message;
  final String? recipient;
  final String provider;
  final String? messageId;

  factory WhatsAppDeliveryResult.fromJson(Map<String, dynamic> json) {
    return WhatsAppDeliveryResult(
      success: json['success'] as bool? ?? false,
      status: (json['status'] ?? 'unknown').toString(),
      message: (json['message'] ?? '').toString(),
      recipient: json['recipient'] as String?,
      provider: (json['provider'] ?? 'cloud_api').toString(),
      messageId: json['message_id'] as String?,
    );
  }
}

class PartnerOrderPreviewResponse {
  const PartnerOrderPreviewResponse({
    required this.itemCount,
    required this.totalQuantity,
    required this.grandTotal,
    this.items = const [],
    this.subtotalBeforeDiscount,
    this.discountPercentage,
    this.totalDiscount,
    this.finalTotal,
  });

  final int itemCount;
  final int totalQuantity;
  final num grandTotal;
  final List<PartnerOrderItemResponse> items;
  final num? subtotalBeforeDiscount;
  final num? discountPercentage;
  final num? totalDiscount;
  final num? finalTotal;

  factory PartnerOrderPreviewResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PartnerOrderPreviewResponse(
      itemCount: json['item_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      grandTotal: num.tryParse(json['grand_total']?.toString() ?? '0') ?? 0,
      items: rawItems
          .map((item) =>
              PartnerOrderItemResponse.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotalBeforeDiscount: json['subtotal_before_discount'] != null
          ? num.tryParse(json['subtotal_before_discount'].toString())
          : null,
      discountPercentage: json['discount_percentage'] != null
          ? num.tryParse(json['discount_percentage'].toString())
          : null,
      totalDiscount: json['total_discount'] != null
          ? num.tryParse(json['total_discount'].toString())
          : null,
      finalTotal: json['final_total'] != null
          ? num.tryParse(json['final_total'].toString())
          : null,
    );
  }
}

class PartnerDashboardStats {
  const PartnerDashboardStats({
    required this.totalPoints,
    required this.pointsUsed,
    required this.remainingBalance,
    required this.totalOrders,
    required this.pendingOrders,
    required this.processingOrders,
    required this.dispatchedOrders,
    required this.deliveredOrders,
    required this.cancelledOrders,
  });

  final int totalPoints;
  final int pointsUsed;
  final int remainingBalance;
  final int totalOrders;
  final int pendingOrders;
  final int processingOrders;
  final int dispatchedOrders;
  final int deliveredOrders;
  final int cancelledOrders;

  factory PartnerDashboardStats.fromJson(Map<String, dynamic> json) {
    return PartnerDashboardStats(
      totalPoints: json['total_points'] as int? ?? 0,
      pointsUsed: json['points_used'] as int? ?? 0,
      remainingBalance: json['remaining_balance'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      processingOrders: json['processing_orders'] as int? ?? 0,
      dispatchedOrders: json['dispatched_orders'] as int? ?? 0,
      deliveredOrders: json['delivered_orders'] as int? ?? 0,
      cancelledOrders: json['cancelled_orders'] as int? ?? 0,
    );
  }
}
