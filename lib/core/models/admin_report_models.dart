class ReportDateFilter {
  final String? preset;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String interval;

  const ReportDateFilter({
    this.preset,
    this.dateFrom,
    this.dateTo,
    this.interval = 'daily',
  });

  factory ReportDateFilter.fromJson(Map<String, dynamic> json) {
    return ReportDateFilter(
      preset: json['preset'] as String?,
      dateFrom: json['date_from'] != null
          ? DateTime.tryParse(json['date_from'].toString())
          : null,
      dateTo: json['date_to'] != null
          ? DateTime.tryParse(json['date_to'].toString())
          : null,
      interval: json['interval'] as String? ?? 'daily',
    );
  }
}

class ReportOverview {
  final int totalOrders;
  final int ordersPendingApproval;
  final int ordersProcessing;
  final int ordersDispatched;
  final int ordersDelivered;
  final int ordersRejected;
  final int totalStockRequests;
  final int stockRequestsPendingApproval;
  final int stockRequestsApproved;
  final int stockRequestsRejected;
  final num totalOrderValue;

  const ReportOverview({
    this.totalOrders = 0,
    this.ordersPendingApproval = 0,
    this.ordersProcessing = 0,
    this.ordersDispatched = 0,
    this.ordersDelivered = 0,
    this.ordersRejected = 0,
    this.totalStockRequests = 0,
    this.stockRequestsPendingApproval = 0,
    this.stockRequestsApproved = 0,
    this.stockRequestsRejected = 0,
    this.totalOrderValue = 0,
  });

  factory ReportOverview.fromJson(Map<String, dynamic> json) {
    return ReportOverview(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      ordersPendingApproval:
          (json['orders_pending_approval'] as num?)?.toInt() ?? 0,
      ordersProcessing: (json['orders_processing'] as num?)?.toInt() ?? 0,
      ordersDispatched: (json['orders_dispatched'] as num?)?.toInt() ?? 0,
      ordersDelivered: (json['orders_delivered'] as num?)?.toInt() ?? 0,
      ordersRejected: (json['orders_rejected'] as num?)?.toInt() ?? 0,
      totalStockRequests: (json['total_stock_requests'] as num?)?.toInt() ?? 0,
      stockRequestsPendingApproval:
          (json['stock_requests_pending_approval'] as num?)?.toInt() ?? 0,
      stockRequestsApproved:
          (json['stock_requests_approved'] as num?)?.toInt() ?? 0,
      stockRequestsRejected:
          (json['stock_requests_rejected'] as num?)?.toInt() ?? 0,
      totalOrderValue: num.tryParse(json['total_order_value']?.toString() ?? '0') ?? 0,
    );
  }
}

class CatalogueSummary {
  final int totalProducts;
  final int activeProducts;
  final int inactiveProducts;
  final int totalCategories;
  final int activeCategories;
  final int inactiveCategories;
  final int productsWithNullPrice;

  const CatalogueSummary({
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.inactiveProducts = 0,
    this.totalCategories = 0,
    this.activeCategories = 0,
    this.inactiveCategories = 0,
    this.productsWithNullPrice = 0,
  });

  factory CatalogueSummary.fromJson(Map<String, dynamic> json) {
    return CatalogueSummary(
      totalProducts: (json['total_products'] as num?)?.toInt() ?? 0,
      activeProducts: (json['active_products'] as num?)?.toInt() ?? 0,
      inactiveProducts: (json['inactive_products'] as num?)?.toInt() ?? 0,
      totalCategories: (json['total_categories'] as num?)?.toInt() ?? 0,
      activeCategories: (json['active_categories'] as num?)?.toInt() ?? 0,
      inactiveCategories: (json['inactive_categories'] as num?)?.toInt() ?? 0,
      productsWithNullPrice:
          (json['products_with_null_price'] as num?)?.toInt() ?? 0,
    );
  }
}

class StatusCount {
  final String status;
  final String label;
  final int count;

  const StatusCount({
    required this.status,
    required this.label,
    required this.count,
  });

  factory StatusCount.fromJson(Map<String, dynamic> json) {
    return StatusCount(
      status: json['status']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderTrendPoint {
  final String period;
  final String label;
  final int count;
  final num totalValue;

  const OrderTrendPoint({
    required this.period,
    required this.label,
    required this.count,
    this.totalValue = 0,
  });

  factory OrderTrendPoint.fromJson(Map<String, dynamic> json) {
    return OrderTrendPoint(
      period: json['period']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalValue: num.tryParse(json['total_value']?.toString() ?? '0') ?? 0,
    );
  }
}

class AdminReportOverview {
  final DateTime generatedAt;
  final ReportDateFilter filter;
  final ReportOverview overview;
  final CatalogueSummary catalogueSummary;
  final List<StatusCount> orderStatusDistribution;
  final List<StatusCount> stockRequestStatusDistribution;
  final List<OrderTrendPoint> orderTrends;
  final List<String> unsupportedMetrics;

  const AdminReportOverview({
    required this.generatedAt,
    required this.filter,
    required this.overview,
    required this.catalogueSummary,
    required this.orderStatusDistribution,
    required this.stockRequestStatusDistribution,
    required this.orderTrends,
    required this.unsupportedMetrics,
  });

  factory AdminReportOverview.fromJson(Map<String, dynamic> json) {
    final rawOrderStatus = json['order_status_distribution'];
    final rawStockStatus = json['stock_request_status_distribution'];
    final rawTrends = json['order_trends'];
    final rawUnsupported = json['unsupported_metrics'];

    return AdminReportOverview(
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      filter: json['filter'] is Map<String, dynamic>
          ? ReportDateFilter.fromJson(json['filter'] as Map<String, dynamic>)
          : const ReportDateFilter(),
      overview: json['overview'] is Map<String, dynamic>
          ? ReportOverview.fromJson(json['overview'] as Map<String, dynamic>)
          : const ReportOverview(),
      catalogueSummary: json['catalogue_summary'] is Map<String, dynamic>
          ? CatalogueSummary.fromJson(json['catalogue_summary'] as Map<String, dynamic>)
          : const CatalogueSummary(),
      orderStatusDistribution: rawOrderStatus is List
          ? rawOrderStatus
              .whereType<Map<String, dynamic>>()
              .map((e) => StatusCount.fromJson(e))
              .toList()
          : const [],
      stockRequestStatusDistribution: rawStockStatus is List
          ? rawStockStatus
              .whereType<Map<String, dynamic>>()
              .map((e) => StatusCount.fromJson(e))
              .toList()
          : const [],
      orderTrends: rawTrends is List
          ? rawTrends
              .whereType<Map<String, dynamic>>()
              .map((e) => OrderTrendPoint.fromJson(e))
              .toList()
          : const [],
      unsupportedMetrics: rawUnsupported is List
          ? rawUnsupported.map((e) => e.toString()).toList()
          : const [],
    );
  }
}
