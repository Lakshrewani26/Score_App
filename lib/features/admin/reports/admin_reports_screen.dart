import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
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
  late final AdminApi _adminApi;

  // Selected report type
  String _selectedReportType = 'overview'; // 'overview', 'zone', 'area', 'staff', 'partner'

  // Filter state
  String _selectedPreset = '30d';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final String _selectedInterval = 'daily';
  int? _filterZoneId;
  List<AdminZone> _availableZones = [];

  // Screen state
  bool _isLoading = true;
  String? _errorMessage;

  // Report data holders
  AdminReportOverview? _overviewData;
  ZoneWiseReportResponse? _zoneWiseData;
  AreaWiseReportResponse? _areaWiseData;
  StaffWiseReportResponse? _staffWiseData;
  PartnerWiseReportResponse? _partnerWiseData;

  int _requestCounter = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _reportsApi = widget.reportsApi ??
        widget.adminApi?.reports ??
        AdminReportsApi(sessionManager: _session);
    _adminApi = widget.adminApi ?? AdminApi(sessionManager: _session);

    _loadReport().then((_) {
      if (mounted && widget.adminApi != null) {
        _fetchZones();
      }
    });
  }

  Future<void> _fetchZones() async {
    try {
      final zones = await _adminApi.getZones();
      if (!mounted) return;
      setState(() {
        _availableZones = zones;
      });
    } catch (_) {}
  }

  (DateTime?, DateTime?) _calculateDateRange() {
    final now = DateTime.now();
    if (_selectedPreset == '7d') {
      return (now.subtract(const Duration(days: 7)), now);
    } else if (_selectedPreset == '30d') {
      return (now.subtract(const Duration(days: 30)), now);
    } else if (_selectedPreset == '90d') {
      return (now.subtract(const Duration(days: 90)), now);
    } else if (_selectedPreset == 'custom') {
      return (_customStartDate, _customEndDate);
    }
    return (null, null); // all_time
  }

  Future<void> _loadReport() async {
    final requestId = ++_requestCounter;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (dateFrom, dateTo) = _calculateDateRange();

    try {
      if (_selectedReportType == 'overview') {
        final report = await _reportsApi.getReportOverview(
          preset: _selectedPreset,
          dateFrom: dateFrom,
          dateTo: dateTo,
          interval: _selectedInterval,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() {
          _overviewData = report;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (_selectedReportType == 'zone') {
        final report = await _reportsApi.getZoneWiseReport(
          dateFrom: dateFrom,
          dateTo: dateTo,
          zoneId: _filterZoneId,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() {
          _zoneWiseData = report;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (_selectedReportType == 'area') {
        final report = await _reportsApi.getAreaWiseReport(
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() {
          _areaWiseData = report;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (_selectedReportType == 'staff') {
        final report = await _reportsApi.getStaffWiseReport(
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() {
          _staffWiseData = report;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (_selectedReportType == 'partner') {
        final report = await _reportsApi.getPartnerWiseReport(
          dateFrom: dateFrom,
          dateTo: dateTo,
          zoneId: _filterZoneId,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() {
          _partnerWiseData = report;
          _isLoading = false;
          _errorMessage = null;
        });
      }
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

  void _onReportTypeChanged(String type) {
    if (_selectedReportType == type) return;
    setState(() {
      _selectedReportType = type;
    });
    if ((type == 'zone' || type == 'partner') && _availableZones.isEmpty) {
      _fetchZones();
    }
    _loadReport();
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
          _buildReportTypeSelector(),
          _buildFilterBar(),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    final types = [
      ('overview', 'Overview', Icons.analytics_rounded),
      ('zone', 'Zone-wise', Icons.location_on_rounded),
      ('area', 'Area-wise', Icons.map_rounded),
      ('staff', 'Staff-wise', Icons.badge_rounded),
      ('partner', 'Partner-wise', Icons.handshake_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: types.map((t) {
            final isSelected = _selectedReportType == t.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: Key('report_tab_${t.$1}'),
                onTap: () => _onReportTypeChanged(t.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? _royalBlue : const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.$3,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF557A95),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.$2,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF37474F),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
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
                      fontSize: 12,
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
          if ((_selectedReportType == 'zone' || _selectedReportType == 'partner') &&
              _availableZones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FCFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderBlue),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  key: const Key('report_zone_filter_dropdown'),
                  value: _filterZoneId,
                  isDense: true,
                  hint: const Text('Filter by Zone (All Zones)', style: TextStyle(fontSize: 12)),
                  style: const TextStyle(color: _deepBlue, fontSize: 12, fontWeight: FontWeight.w600),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Zones'),
                    ),
                    ..._availableZones.map((z) => DropdownMenuItem<int?>(
                          value: z.id,
                          child: Text('Zone: ${z.name}'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterZoneId = val;
                    });
                    _loadReport();
                  },
                ),
              ),
            ),
          ],
        ],
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
        fontSize: 12,
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
    if (_isLoading &&
        _overviewData == null &&
        _zoneWiseData == null &&
        _areaWiseData == null &&
        _staffWiseData == null &&
        _partnerWiseData == null) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('admin_reports_loading'),
          valueColor: AlwaysStoppedAnimation<Color>(_royalBlue),
        ),
      );
    }

    if (_errorMessage != null) {
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

    if (_selectedReportType == 'zone') {
      return _buildZoneWiseContent();
    } else if (_selectedReportType == 'area') {
      return _buildAreaWiseContent();
    } else if (_selectedReportType == 'staff') {
      return _buildStaffWiseContent();
    } else if (_selectedReportType == 'partner') {
      return _buildPartnerWiseContent();
    }

    return _buildOverviewContent();
  }

  Widget _buildZoneWiseContent() {
    final data = _zoneWiseData;
    if (data == null || data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: _buildEmptyContainer('No zone-wise transaction records found for the selected period.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryHeaderCard(
            title: 'Zone Performance Summary',
            subtitle: '${data.totalZones} Zones | ${data.totalOrders} Orders | Total: ${formatCurrency(data.totalOrderValue)}',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 14),
          ...data.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _borderBlue),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _royalBlue.withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_city_rounded, color: _royalBlue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.zoneName,
                              style: const TextStyle(color: _deepBlue, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.partnerCount} Partners',
                              style: const TextStyle(color: Color(0xFF00796B), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFE3F2FD), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniMetric('Orders', '${item.orderCount}'),
                          _buildMiniMetric('Order Value', formatCurrency(item.totalOrderValue)),
                          _buildMiniMetric('Payments', '${item.paymentCount} (${formatCurrency(item.totalPaymentsCollected)})'),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAreaWiseContent() {
    final data = _areaWiseData;
    if (data == null || data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: _buildEmptyContainer('No area-wise transaction records found for the selected period.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryHeaderCard(
            title: 'Area Distribution',
            subtitle: '${data.totalAreas} Areas with registered business partners',
            icon: Icons.map_rounded,
          ),
          const SizedBox(height: 14),
          ...data.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _borderBlue),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withAlpha(24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF00897B), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.areaName,
                              style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.partnerCount} Active Partners',
                              style: const TextStyle(color: Color(0xFF557A95), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.orderCount} Orders',
                            style: const TextStyle(color: _deepBlue, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            formatCurrency(item.totalOrderValue),
                            style: const TextStyle(color: _royalBlue, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStaffWiseContent() {
    final data = _staffWiseData;
    if (data == null || data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: _buildEmptyContainer('No staff records found.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryHeaderCard(
            title: 'Staff Performance Report',
            subtitle: '${data.totalStaff} Staff Members registered in system',
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 14),
          ...data.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _borderBlue),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE65100).withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.badge_rounded, color: Color(0xFFE65100), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'ID: ${item.staffId} | Mobile: ${item.mobile}',
                                  style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.assignedPartnerCount} Partners',
                              style: const TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFE3F2FD), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniMetric('Orders Generated', '${item.orderCount}'),
                          _buildMiniMetric('Total Value', formatCurrency(item.totalOrderValue)),
                          _buildMiniMetric('Payments Collected', formatCurrency(item.totalPaymentsCollected)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPartnerWiseContent() {
    final data = _partnerWiseData;
    if (data == null || data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: _buildEmptyContainer('No partner records found for the selected period.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryHeaderCard(
            title: 'Partner Business Report',
            subtitle: '${data.totalPartners} Partners reporting transactions',
            icon: Icons.handshake_rounded,
          ),
          const SizedBox(height: 14),
          ...data.items.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _borderBlue),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withAlpha(24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF00897B), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.businessName.isNotEmpty ? item.businessName : item.partnerName,
                                  style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Contact: ${item.partnerName} (${item.mobile})',
                                  style: const TextStyle(color: Color(0xFF557A95), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (item.zoneName != null && item.zoneName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F4FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Zone: ${item.zoneName}',
                                style: const TextStyle(color: _royalBlue, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFE3F2FD), height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniMetric('Orders', '${item.orderCount}'),
                          _buildMiniMetric('Order Value', formatCurrency(item.totalOrderValue)),
                          _buildMiniMetric('Payments Made', formatCurrency(item.totalPaymentsMade)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSummaryHeaderCard({required String title, required String subtitle, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
        boxShadow: const [
          BoxShadow(color: Color(0x100755B5), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_deepBlue, _royalBlue]),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _deepBlue, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF557A95), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewContent() {
    final data = _overviewData;
    if (data == null) {
      return const Center(child: CircularProgressIndicator(color: _royalBlue));
    }

    return RefreshIndicator(
      color: _royalBlue,
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (data.unsupportedMetrics.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildTransparencyBanner(data.unsupportedMetrics),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _getDateSubtitle(ReportDateFilter filter) {
    if (filter.dateFrom != null && filter.dateTo != null) {
      final f = filter.dateFrom!;
      final t = filter.dateTo!;
      return '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')} to ${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    }
    return 'Lifetime recorded data';
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
            color: Color(0xFF78909C),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewGrid(ReportOverview overview) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Orders',
                value: overview.totalOrders.toString(),
                icon: Icons.receipt_long_rounded,
                accentColor: const Color(0xFF0055B8),
                key: const Key('report_metric_total_orders'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Value',
                value: formatCurrency(overview.totalOrderValue),
                icon: Icons.currency_rupee_rounded,
                accentColor: const Color(0xFF00897B),
                key: const Key('report_metric_total_value'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Pending Staff',
                value: overview.ordersPendingApproval.toString(),
                icon: Icons.hourglass_top_rounded,
                accentColor: const Color(0xFFE65100),
                key: const Key('report_metric_pending_approval'),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Delivered',
                value: overview.ordersDelivered.toString(),
                icon: Icons.task_alt_rounded,
                accentColor: const Color(0xFF2E7D32),
                key: const Key('report_metric_delivered'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Key key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
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
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _deepBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusDistribution(List<StatusCount> list, int total) {
    if (list.isEmpty) {
      return _buildEmptyContainer('No orders recorded in this period.');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: list.map((item) {
          final pct = total > 0 ? (item.count / total) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: _deepBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.count} (${(pct * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        color: Color(0xFF557A95),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(item.status)),
                    backgroundColor: const Color(0xFFECEFF1),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF2E7D32);
      case 'dispatched':
        return const Color(0xFF00897B);
      case 'processing':
        return const Color(0xFF0087D4);
      case 'pending_approval':
        return const Color(0xFFE65100);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFD32F2F);
      default:
        return _royalBlue;
    }
  }

  Widget _buildOrderTrendChart(List<OrderTrendPoint> trends) {
    if (trends.isEmpty) {
      return _buildEmptyContainer('No trend data available for this range.');
    }

    final maxCount = trends.map((t) => t.count).fold<int>(0, math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: trends.map((point) {
                final heightFactor = maxCount > 0 ? (point.count / maxCount) : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (point.count > 0)
                          Text(
                            '${point.count}',
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: math.max(6.0, heightFactor * 80),
                          decoration: BoxDecoration(
                            color: point.count > 0 ? _royalBlue : const Color(0xFFECEFF1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          point.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockRequestSummary(ReportOverview ov, List<StatusCount> statusDist) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Stock Requests',
                  style: TextStyle(
                    color: _deepBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ov.totalStockRequests}',
                style: const TextStyle(
                  color: _royalBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFECEFF1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStockStat('Pending', ov.stockRequestsPendingApproval, const Color(0xFFE65100)),
              _buildStockStat('Approved', ov.stockRequestsApproved, const Color(0xFF2E7D32)),
              _buildStockStat('Rejected', ov.stockRequestsRejected, const Color(0xFFD32F2F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78909C),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogueSummary(CatalogueSummary cat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCatalogueMetricTile(
                  'Products',
                  '${cat.activeProducts} active / ${cat.totalProducts} total',
                  '${cat.inactiveProducts} inactive',
                  Icons.inventory_2_rounded,
                  const Color(0xFF0055B8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCatalogueMetricTile(
                  'Categories',
                  '${cat.activeCategories} active / ${cat.totalCategories} total',
                  '${cat.inactiveCategories} inactive',
                  Icons.category_rounded,
                  const Color(0xFF0087D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cat.productsWithNullPrice > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  cat.productsWithNullPrice > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  color: cat.productsWithNullPrice > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.productsWithNullPrice > 0
                        ? '${cat.productsWithNullPrice} product(s) have no price configured (null price).'
                        : 'All catalogue products have valid prices configured.',
                    style: TextStyle(
                      color: cat.productsWithNullPrice > 0 ? const Color(0xFFBF360C) : const Color(0xFF1B5E20),
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
