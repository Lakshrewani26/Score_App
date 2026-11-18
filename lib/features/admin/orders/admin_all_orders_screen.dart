import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/admin_order_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_orders_api.dart';
import '../../../core/services/admin_session_manager.dart';
import '../../../core/services/pdf_printer/pdf_printer.dart';

Color _getCreatorBadgeBg(String role) {
  final r = role.toLowerCase();
  if (r == 'staff') return const Color(0xFFE8F5E9);
  if (r.contains('unknown') || r.contains('legacy')) return const Color(0xFFECEFF1);
  return const Color(0xFFEDE7F6);
}

Color _getCreatorBadgeBorder(String role) {
  final r = role.toLowerCase();
  if (r == 'staff') return const Color(0xFF81C784);
  if (r.contains('unknown') || r.contains('legacy')) return const Color(0xFFCFD8DC);
  return const Color(0xFFB39DDB);
}

Color _getCreatorBadgeText(String role) {
  final r = role.toLowerCase();
  if (r == 'staff') return const Color(0xFF2E7D32);
  if (r.contains('unknown') || r.contains('legacy')) return const Color(0xFF546E7A);
  return const Color(0xFF512DA8);
}

/// Dedicated read-only "All Orders" screen in the Admin application.
/// Displays all normal orders created by Partners and Staff members.
/// Strictly excludes stock requests.
/// Allows Admin to search, filter, open order details, and print order PDFs.
class AdminAllOrdersScreen extends StatefulWidget {
  const AdminAllOrdersScreen({
    super.key,
    this.adminApi,
    this.ordersApi,
    this.sessionManager,
    this.pdfPrinter,
  });

  final AdminApi? adminApi;
  final AdminOrdersApi? ordersApi;
  final AdminSessionManager? sessionManager;
  final PdfPrinterFn? pdfPrinter;

  @override
  State<AdminAllOrdersScreen> createState() => _AdminAllOrdersScreenState();
}

class _AdminAllOrdersScreenState extends State<AdminAllOrdersScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  late final AdminSessionManager _session;
  late final AdminOrdersApi _ordersApi;
  late final PdfPrinterFn _pdfPrinter;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  String _selectedStatus = 'all';
  String _selectedVehicleType = 'all';

  int _currentPage = 1;
  static const int _pageSize = 20;

  bool _isLoading = true;
  String? _errorMessage;
  List<AdminOrderSummary> _orders = [];
  int _totalOrders = 0;
  int _totalPages = 0;
  int _requestSeq = 0;

  final Set<int> _printingOrderIds = {};

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _ordersApi = widget.ordersApi ??
        widget.adminApi?.orders ??
        AdminOrdersApi(sessionManager: _session);
    _pdfPrinter = widget.pdfPrinter ?? printPdfDocument;

    _searchController.addListener(_onSearchChanged);
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
      });
      _fetchOrders();
    });
  }

  Future<void> _fetchOrders() async {
    final thisSeq = ++_requestSeq;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final searchVal = _searchController.text.trim();

    try {
      final res = await _ordersApi.getOrders(
        search: searchVal.isNotEmpty ? searchVal : null,
        status: _selectedStatus != 'all' ? _selectedStatus : null,
        vehicleType: _selectedVehicleType != 'all' ? _selectedVehicleType : null,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted || thisSeq != _requestSeq) return;

      setState(() {
        _orders = res.items;
        _totalOrders = res.total;
        _totalPages = res.totalPages;
        _isLoading = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _requestSeq) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _requestSeq) return;
      setState(() {
        _errorMessage = 'Unable to connect to server. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePrintOrder(AdminOrderSummary order) async {
    if (_printingOrderIds.contains(order.id)) return;

    setState(() {
      _printingOrderIds.add(order.id);
    });

    try {
      final pdfBytes = await _ordersApi.downloadOrderPdf(order.id);
      if (!mounted) return;

      final fileName = 'Score_Order_${order.orderNumber}.pdf';
      await _pdfPrinter(bytes: pdfBytes, fileName: fileName);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print preview opened for Order #${order.orderNumber}.'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final String errorMsg;
      if (e is AdminApiException) {
        errorMsg = e.message;
      } else {
        errorMsg = e.toString().replaceFirst(RegExp(r'^(Exception|AdminApiException):\s*'), '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print order: $errorMsg'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _printingOrderIds.remove(order.id);
        });
      }
    }
  }

  void _openOrderDetail(AdminOrderSummary order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminAllOrderDetailSheet(
        order: order,
        ordersApi: _ordersApi,
        onPrintPdf: () => _handlePrintOrder(order),
        isPrinting: _printingOrderIds.contains(order.id),
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return const Color(0xFFFFF3E0);
      case 'approved_processing':
        return const Color(0xFFE1F5FE);
      case 'dispatched':
        return const Color(0xFFEDE7F6);
      case 'delivered':
        return const Color(0xFFE8F8EE);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFECEFF1);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return const Color(0xFFE65100);
      case 'approved_processing':
        return const Color(0xFF0277BD);
      case 'dispatched':
        return const Color(0xFF512DA8);
      case 'delivered':
        return const Color(0xFF2E7D32);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 800;
            final contentWidth = math.min(width * 0.96, 1100.0);

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildFiltersCard(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildContent(isDesktop),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            key: const Key('admin_all_orders_back_button'),
            icon: const Icon(Icons.arrow_back_rounded, color: _deepBlue),
            tooltip: 'Back to Admin Dashboard',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Orders',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Complete list of Partner & Staff orders (Read-Only)',
                  style: TextStyle(
                    color: Color(0xFF557A95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('admin_all_orders_refresh_button'),
            icon: const Icon(Icons.refresh_rounded, color: _royalBlue),
            tooltip: 'Refresh Orders',
            onPressed: _fetchOrders,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0755B5),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search input
          TextField(
            key: const Key('all_orders_search_input'),
            controller: _searchController,
            style: const TextStyle(fontSize: 14, color: _deepBlue),
            decoration: InputDecoration(
              hintText: 'Search by Order #, Partner, Business, or Creator...',
              hintStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _royalBlue, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF90A4AE)),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _fieldBorderBlue),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _fieldBorderBlue),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _royalBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('all_orders_status_filter'),
                  initialValue: _selectedStatus,
                  isDense: true,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: const TextStyle(fontSize: 12, color: _royalBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _fieldBorderBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _fieldBorderBlue),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'approved_processing', child: Text('Processing', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'dispatched', child: Text('Dispatched', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'rejected', child: Text('Rejected', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedStatus = val;
                      _currentPage = 1;
                    });
                    _fetchOrders();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const Key('all_orders_vehicle_filter'),
                  initialValue: _selectedVehicleType,
                  isDense: true,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Type',
                    labelStyle: const TextStyle(fontSize: 12, color: _royalBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _fieldBorderBlue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _fieldBorderBlue),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Vehicles', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '2-Wheeler', child: Text('2-Wheeler', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: '3-Wheeler', child: Text('3-Wheeler', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Both', child: Text('Both', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedVehicleType = val;
                      _currentPage = 1;
                    });
                    _fetchOrders();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _royalBlue),
            SizedBox(height: 14),
            Text(
              'Loading orders...',
              style: TextStyle(color: _deepBlue, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
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
              const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('all_orders_retry_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                onPressed: _fetchOrders,
              ),
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: _royalBlue, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Orders Found',
                style: TextStyle(color: _deepBlue, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'No normal orders match the selected filters or search query.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF557A95), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: isDesktop ? _buildDesktopTable() : _buildMobileList(),
        ),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0755B5), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F6FC)),
            horizontalMargin: 16,
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Order #', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Partner / Business', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Creator', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13))),
            ],
            rows: _orders.map((order) {
              final statusBg = _getStatusBgColor(order.status);
              final statusFg = _getStatusTextColor(order.status);
              final isPrinting = _printingOrderIds.contains(order.id);

              final creatorRole = order.displayCreatorRole;

              return DataRow(
                cells: [
                  // Order #
                  DataCell(
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: _deepBlue, fontSize: 13),
                    ),
                    onTap: () => _openOrderDetail(order),
                  ),
                  // Partner / Business
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          order.businessName ?? order.partnerName,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: _royalBlue, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (order.businessName != null && order.businessName!.isNotEmpty)
                          Text(
                            order.partnerName,
                            style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    onTap: () => _openOrderDetail(order),
                  ),
                  // Creator & Role
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCreatorBadgeBg(creatorRole),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getCreatorBadgeBorder(creatorRole),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            creatorRole,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _getCreatorBadgeText(creatorRole),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            order.displayCreatorName,
                            style: const TextStyle(fontSize: 12, color: _deepBlue, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date
                  DataCell(
                    Text(
                      order.displayDate,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
                    ),
                  ),
                  // Total Qty
                  DataCell(
                    Text(
                      '${order.totalQuantity} pcs',
                      style: const TextStyle(fontSize: 12, color: _deepBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Amount
                  DataCell(
                    Text(
                      order.displayOrderTotal,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _deepBlue, fontSize: 13),
                    ),
                  ),
                  // Status
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusFg.withAlpha(70), width: 1),
                      ),
                      child: Text(
                        order.displayStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  // Actions: View & Print
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('view_order_${order.id}'),
                          icon: const Icon(Icons.visibility_rounded, size: 18, color: _royalBlue),
                          tooltip: 'View Order Details',
                          onPressed: () => _openOrderDetail(order),
                        ),
                        isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _royalBlue),
                              )
                            : IconButton(
                                key: Key('print_order_${order.id}'),
                                icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF00897B)),
                                tooltip: 'Print Order (PDF)',
                                onPressed: () => _handlePrintOrder(order),
                              ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final statusBg = _getStatusBgColor(order.status);
        final statusFg = _getStatusTextColor(order.status);
        final isPrinting = _printingOrderIds.contains(order.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderBlue, width: 1.3),
            boxShadow: const [
              BoxShadow(color: Color(0x100755B5), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openOrderDetail(order),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Order # and Status
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.receipt_long_rounded, color: statusFg, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              Text(order.displayDate, style: const TextStyle(color: Color(0xFF78909C), fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusFg.withAlpha(70), width: 1),
                          ),
                          child: Text(
                            order.displayStatus.toUpperCase(),
                            style: TextStyle(color: statusFg, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF0F7FC)),
                    const SizedBox(height: 8),

                    // Line 2: Partner / Business
                    Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF607D8B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.businessName != null && order.businessName!.isNotEmpty
                                ? '${order.businessName} (${order.partnerName})'
                                : order.partnerName,
                            style: const TextStyle(color: _royalBlue, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Line 3: Creator & Creator Role
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF607D8B)),
                        const SizedBox(width: 6),
                        Text(
                          'Created by: ${order.displayCreatorName} ',
                          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _getCreatorBadgeBg(order.displayCreatorRole),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _getCreatorBadgeBorder(order.displayCreatorRole),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            order.displayCreatorRole,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: _getCreatorBadgeText(order.displayCreatorRole),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Line 4: Quantity, Amount and Print Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${order.itemCount} items • ${order.totalQuantity} pcs',
                          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            Text(
                              order.displayOrderTotal,
                              style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              key: Key('mobile_print_order_${order.id}'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00897B),
                                side: const BorderSide(color: Color(0xFF00897B), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(60, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: isPrinting ? null : () => _handlePrintOrder(order),
                              icon: isPrinting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00897B)),
                                    )
                                  : const Icon(Icons.print_rounded, size: 16),
                              label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _pageSize + 1} - ${math.min(_currentPage * _pageSize, _totalOrders)} of $_totalOrders orders',
            style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              IconButton(
                key: const Key('all_orders_prev_page'),
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchOrders();
                      }
                    : null,
              ),
              Text(
                '$_currentPage / ${math.max(1, _totalPages)}',
                style: const TextStyle(color: _deepBlue, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              IconButton(
                key: const Key('all_orders_next_page'),
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchOrders();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only complete order detail sheet for Admin All Orders.
class AdminAllOrderDetailSheet extends StatefulWidget {
  const AdminAllOrderDetailSheet({
    super.key,
    required this.order,
    this.ordersApi,
    required this.onPrintPdf,
    required this.isPrinting,
  });

  final AdminOrderSummary order;
  final AdminOrdersApi? ordersApi;
  final VoidCallback onPrintPdf;
  final bool isPrinting;

  @override
  State<AdminAllOrderDetailSheet> createState() => _AdminAllOrderDetailSheetState();
}

class _AdminAllOrderDetailSheetState extends State<AdminAllOrderDetailSheet> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _borderBlue = Color(0xFFCBEBFF);

  late AdminOrderSummary _summary;
  AdminOrderDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _summary = widget.order;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (widget.ordersApi == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await widget.ordersApi!.getOrderDetail(_summary.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _summary = detail;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load complete order items.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${_summary.orderNumber}',
                        style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Read-only order view • ${_summary.displayDate}',
                        style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Print PDF Button
                ElevatedButton.icon(
                  key: const Key('all_orders_detail_print_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: widget.isPrinting ? null : widget.onPrintPdf,
                  icon: widget.isPrinting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Print Order', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECEFF1)),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _royalBlue))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReadonlyNotice(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF9A9A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _fetchDetail,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(40, 24),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Retry', style: TextStyle(fontSize: 12, color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _buildOrderMetaCard(),
                        const SizedBox(height: 14),
                        _buildItemsSection(),
                        const SizedBox(height: 14),
                        _buildFinancialSummary(),
                        if (_detail != null && _detail!.statusHistory.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAuditHistory(),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadonlyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This view is strictly read-only. No edits or status changes can be performed from All Orders.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMetaCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderBlue, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Partner / Business', style: TextStyle(color: Color(0xFF78909C), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _summary.businessName ?? _summary.partnerName,
                      style: const TextStyle(color: _deepBlue, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Contact: ${_summary.partnerName} • ${_summary.partnerMobile}',
                      style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Order Creator', style: TextStyle(color: Color(0xFF78909C), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCreatorBadgeBg(_summary.displayCreatorRole),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getCreatorBadgeBorder(_summary.displayCreatorRole),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _summary.displayCreatorRole,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _getCreatorBadgeText(_summary.displayCreatorRole),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _summary.displayCreatorName,
                        style: const TextStyle(color: _deepBlue, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (_summary.notes != null && _summary.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 6),
            Text(
              'Notes / Transport: ${_summary.notes}',
              style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final items = _detail?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ordered Products (${items.length} items, ${_summary.totalQuantity} total qty)',
          style: const TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderBlue, width: 1),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFECEFF1)),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Color(0xFF78909C), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'SKU: ${item.productCode} • ${item.vehicleType}',
                            style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                          ),
                          Text(
                            'MRP: ${item.displayMrp} | List: ${item.displayListPrice}'
                            '${(item.discountAmount != null && item.discountAmount! > 0) ? ' (-${item.discountPercentage?.toStringAsFixed(1)}%)' : ''}',
                            style: const TextStyle(color: _royalBlue, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.quantity} × ${formatCurrency(item.discountedPrice ?? item.unitPrice)}',
                          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 11),
                        ),
                        Text(
                          formatCurrency(item.quantity * (item.discountedPrice ?? item.unitPrice ?? 0)),
                          style: const TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal Before Discount:', style: TextStyle(color: Color(0xFF546E7A), fontSize: 13)),
              Text(_summary.displaySubtotalBeforeDiscount, style: const TextStyle(color: _deepBlue, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Partner Discount (${_summary.discountPercentage?.toStringAsFixed(1) ?? '0.0'}%):', style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13)),
              Text('- ${_summary.displayTotalDiscount}', style: const TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Final Order Total:', style: TextStyle(color: _deepBlue, fontSize: 15, fontWeight: FontWeight.w800)),
              Text(_summary.displayOrderTotal, style: const TextStyle(color: _deepBlue, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditHistory() {
    final history = _detail?.statusHistory ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Progression History',
          style: TextStyle(color: _deepBlue, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderBlue, width: 1),
          ),
          child: Column(
            children: history.map((h) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 14, color: _royalBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${h.displayNewStatus} • ${h.changedByName ?? 'System'}',
                        style: const TextStyle(color: _deepBlue, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      h.displayDate,
                      style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
