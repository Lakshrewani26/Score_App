import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_order_models.dart' show formatCurrency;
import '../../../core/models/admin_report_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_reports_api.dart';
import '../../../core/services/admin_session_manager.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({
    super.key,
    this.adminApi,
    this.reportsApi,
    this.sessionManager,
  });

  final AdminApi? adminApi;
  final AdminReportsApi? reportsApi;
  final AdminSessionManager? sessionManager;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);
  late final AdminSessionManager _session;
  late final AdminReportsApi _reportsApi;

  // Filter state
  String _selectedPreset = '30d';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final String _selectedInterval = 'daily';

  // Screen state
  bool _isLoading = true;
  String? _errorMessage;
  AdminReportOverview? _reportData;
  int _requestCounter = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _reportsApi = widget.reportsApi ??
        widget.adminApi?.reports ??
        AdminReportsApi(sessionManager: _session);
    _loadReport();
  }

  Future<void> _loadReport() async {
    final requestId = ++_requestCounter;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _reportsApi.getReportOverview(
        preset: _selectedPreset,
        dateFrom: _selectedPreset == 'custom' ? _customStartDate : null,
        dateTo: _selectedPreset == 'custom' ? _customEndDate : null,
        interval: _selectedInterval,
      );

      if (!mounted || requestId != _requestCounter) return;

      setState(() {
        _reportData = report;
        _isLoading = false;
        _errorMessage = null;
      });
    } on AdminApiException catch (e) {
      if (!mounted || requestId != _requestCounter) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted || requestId != _requestCounter) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load report. Please try again.';
      });
    }
  }

  void _onPresetChanged(String preset) {
    if (_selectedPreset == preset && preset != 'custom') return;
    setState(() {
      _selectedPreset = preset;
    });
    _loadReport();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialStart = _customStartDate ?? now.subtract(const Duration(days: 30));
    final initialEnd = _customEndDate ?? now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: initialStart.isBefore(now) ? initialStart : now.subtract(const Duration(days: 7)),
        end: initialEnd.isBefore(now.add(const Duration(days: 1))) ? initialEnd : now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _royalBlue,
              onPrimary: Colors.white,
              onSurface: _deepBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('admin_reports_back_button'),
          icon: const Icon(Icons.arrow_back_rounded, color: _deepBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Analytics',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Live metrics & operational performance',
              style: TextStyle(
                color: Color(0xFF546E7A),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('admin_reports_refresh_button'),
            icon: const Icon(Icons.refresh_rounded, color: _royalBlue),
            tooltip: 'Refresh reports',
            onPressed: _isLoading ? null : _loadReport,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPresetChip('7d', 'Last 7 Days', const Key('preset_chip_7d')),
            const SizedBox(width: 8),
            _buildPresetChip('30d', 'Last 30 Days', const Key('preset_chip_30d')),
            const SizedBox(width: 8),
            _buildPresetChip('90d', 'Last 90 Days', const Key('preset_chip_90d')),
            const SizedBox(width: 8),
            _buildPresetChip('all_time', 'All Time', const Key('preset_chip_all_time')),
            const SizedBox(width: 8),
            ActionChip(
              key: const Key('preset_chip_custom'),
              avatar: const Icon(Icons.date_range_rounded, size: 16, color: _royalBlue),
              label: Text(
                _selectedPreset == 'custom' && _customStartDate != null && _customEndDate != null
                    ? '${_customStartDate!.day}/${_customStartDate!.month} - ${_customEndDate!.day}/${_customEndDate!.month}'
                    : 'Custom Range',
                style: TextStyle(
                  color: _selectedPreset == 'custom' ? Colors.white : _deepBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              backgroundColor: _selectedPreset == 'custom' ? _royalBlue : const Color(0xFFE8F4FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _selectedPreset == 'custom' ? _royalBlue : _borderBlue,
                ),
              ),
              onPressed: _pickCustomDateRange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String preset, String label, Key key) {
    final isSelected = _selectedPreset == preset;
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onPresetChanged(preset),
      selectedColor: _royalBlue,
      backgroundColor: const Color(0xFFE8F4FD),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : _deepBlue,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _royalBlue : _borderBlue,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _reportData == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('admin_reports_loading'),
          valueColor: AlwaysStoppedAnimation<Color>(_royalBlue),
        ),
      );
    }

    if (_errorMessage != null && _reportData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Color(0xFFD32F2F)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('admin_reports_retry_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _reportData!;
    return RefreshIndicator(
      color: _royalBlue,
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_royalBlue),
                backgroundColor: Color(0xFFE6F5FF),
              ),
            _buildSectionHeader(
              title: 'Overview Metrics',
              subtitle: _getDateSubtitle(data.filter),
            ),
            const SizedBox(height: 10),
            _buildOverviewGrid(data.overview),
            const SizedBox(height: 20),
            _buildSectionHeader(
              title: 'Order Status Distribution',
              subtitle: 'Current breakdown of orders within period',
            ),
            const SizedBox(height: 10),
            _buildOrderStatusDistribution(data.orderStatusDistribution, data.overview.totalOrders),
            const SizedBox(height: 20),
            _buildSectionHeader(
              title: 'Order Trends',
              subtitle: 'Order creation volume over time (${data.filter.interval})',
            ),
            const SizedBox(height: 10),
            _buildOrderTrendChart(data.orderTrends),
            const SizedBox(height: 20),
            _buildSectionHeader(
              title: 'Stock Requests',
              subtitle: 'Partner stock replenishment requests',
            ),
            const SizedBox(height: 10),
            _buildStockRequestSummary(data.overview, data.stockRequestStatusDistribution),
            const SizedBox(height: 20),
            _buildSectionHeader(
              title: 'Catalogue Snapshot',
              subtitle: 'Current database products & categories (not date-filtered)',
            ),
            const SizedBox(height: 10),
            _buildCatalogueSummary(data.catalogueSummary),
            const SizedBox(height: 20),
            _buildTransparencyBanner(data.unsupportedMetrics),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getDateSubtitle(ReportDateFilter filter) {
    if (filter.preset == 'all_time') return 'All-time cumulative records';
    if (filter.dateFrom != null && filter.dateTo != null) {
      final from = '${filter.dateFrom!.day}/${filter.dateFrom!.month}/${filter.dateFrom!.year}';
      final to = '${filter.dateTo!.day}/${filter.dateTo!.month}/${filter.dateTo!.year}';
      return 'Filtered from $from to $to';
    }
    return 'Active period';
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _deepBlue,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF607D8B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(ReportOverview overview) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_total_orders'),
                title: 'Total Orders',
                value: overview.totalOrders.toString(),
                icon: Icons.receipt_long_rounded,
                color: _royalBlue,
                subtitle: 'in selected window',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_total_order_value'),
                title: 'Total Value',
                value: formatCurrency(overview.totalOrderValue),
                icon: Icons.payments_rounded,
                color: const Color(0xFF00796B),
                subtitle: 'monetary volume',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_orders_pending'),
                title: 'Pending Staff',
                value: overview.ordersPendingApproval.toString(),
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFE65100),
                subtitle: 'awaiting review',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_orders_processing'),
                title: 'Processing',
                value: overview.ordersProcessing.toString(),
                icon: Icons.sync_rounded,
                color: const Color(0xFF0288D1),
                subtitle: 'approved / packing',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_orders_dispatched'),
                title: 'Dispatched',
                value: overview.ordersDispatched.toString(),
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFF5E35B1),
                subtitle: 'in transit',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_orders_delivered'),
                title: 'Delivered',
                value: overview.ordersDelivered.toString(),
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF2E7D32),
                subtitle: 'fulfilled',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                key: const Key('metric_orders_rejected'),
                title: 'Rejected',
                value: overview.ordersRejected.toString(),
                icon: Icons.cancel_rounded,
                color: const Color(0xFFC62828),
                subtitle: 'declined',
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Key key,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue, width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0755B5),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF455A64),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF90A4AE),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusDistribution(List<StatusCount> items, int total) {
    if (total == 0) {
      return _buildEmptyContainer('No orders recorded in this period.');
    }

    final colors = {
      'pending_approval': const Color(0xFFE65100),
      'approved_processing': const Color(0xFF0288D1),
      'dispatched': const Color(0xFF5E35B1),
      'delivered': const Color(0xFF2E7D32),
      'rejected': const Color(0xFFC62828),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: items.map((sc) {
          final color = colors[sc.status] ?? _royalBlue;
          final pct = total > 0 ? (sc.count / total) * 100 : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sc.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _deepBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sc.count} (${pct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? sc.count / total : 0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFECEFF1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderTrendChart(List<OrderTrendPoint> trends) {
    if (trends.isEmpty) {
      return _buildEmptyContainer('No trend data available for this range.');
    }

    final maxCount = trends.map((t) => t.count).fold(0, math.max);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Volume by Date',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Peak: $maxCount orders',
                style: const TextStyle(
                  color: _royalBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: trends.map((pt) {
                  final barHeight = maxCount > 0 ? (pt.count / maxCount) * 105 : 0.0;
                  final hasOrders = pt.count > 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          pt.count.toString(),
                          style: TextStyle(
                            color: hasOrders ? _royalBlue : const Color(0xFFB0BEC5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 22,
                          height: math.max(barHeight, 4.0),
                          decoration: BoxDecoration(
                            color: hasOrders ? _royalBlue : const Color(0xFFCFD8DC),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 44,
                          child: Text(
                            pt.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF546E7A),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRequestSummary(ReportOverview overview, List<StatusCount> statusDist) {
    return Container(
      key: const Key('metric_stock_requests'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Stock Requests',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                overview.totalStockRequests.toString(),
                style: const TextStyle(
                  color: _royalBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSmallBadge('Pending', overview.stockRequestsPendingApproval, const Color(0xFFE65100)),
              const SizedBox(width: 8),
              _buildSmallBadge('Approved', overview.stockRequestsApproved, const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _buildSmallBadge('Rejected', overview.stockRequestsRejected, const Color(0xFFC62828)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogueSummary(CatalogueSummary cat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCatalogueMetricTile(
                  'Products',
                  '${cat.activeProducts} active / ${cat.totalProducts} total',
                  '${cat.inactiveProducts} inactive',
                  Icons.inventory_2_rounded,
                  _royalBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCatalogueMetricTile(
                  'Categories',
                  '${cat.activeCategories} active / ${cat.totalCategories} total',
                  '${cat.inactiveCategories} inactive',
                  Icons.category_rounded,
                  const Color(0xFF00796B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('metric_null_price_products'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cat.productsWithNullPrice > 0
                  ? const Color(0xFFFFF3E0)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cat.productsWithNullPrice > 0
                    ? const Color(0xFFFFCC80)
                    : const Color(0xFFA5D6A7),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  cat.productsWithNullPrice > 0
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: cat.productsWithNullPrice > 0
                      ? const Color(0xFFE65100)
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.productsWithNullPrice > 0
                        ? '${cat.productsWithNullPrice} product(s) have no price configured (null price).'
                        : 'All catalogue products have valid prices configured.',
                    style: TextStyle(
                      color: cat.productsWithNullPrice > 0
                          ? const Color(0xFFBF360C)
                          : const Color(0xFF1B5E20),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueMetricTile(
    String title,
    String primary,
    String secondary,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            primary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _deepBlue,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencyBanner(List<String> unsupported) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFD8DC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF455A64)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notice: Points balances/transactions, QR code scan logs, and payment gateway analytics are deferred as their database models have not yet been implemented. All displayed numbers reflect verified database records.',
              style: TextStyle(
                color: Color(0xFF455A64),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContainer(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF90A4AE),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
