import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_order_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_orders_api.dart';
import '../../../core/services/admin_session_manager.dart';
import 'widgets/admin_order_card.dart';
import 'widgets/admin_order_detail_sheet.dart';
import 'widgets/admin_stock_request_card.dart';
import 'widgets/admin_stock_request_detail_sheet.dart';

enum AdminOrdersTab { orders, stockRequests }

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({
    super.key,
    this.adminApi,
    this.ordersApi,
    this.sessionManager,
  });

  final AdminApi? adminApi;
  final AdminOrdersApi? ordersApi;
  final AdminSessionManager? sessionManager;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  late final AdminSessionManager _session;
  late final AdminOrdersApi _ordersApi;

  AdminOrdersTab _activeTab = AdminOrdersTab.orders;

  // ---------------------------------------------------------------------------
  // Orders Tab State
  // ---------------------------------------------------------------------------
  final TextEditingController _orderSearchController = TextEditingController();
  Timer? _orderSearchDebounceTimer;

  String _selectedOrderStatus = 'all';
  String _selectedVehicleType = 'all';

  int _orderPage = 1;
  static const int _orderPageSize = 20;

  bool _isLoadingOrders = true;
  String? _orderErrorMessage;
  List<AdminOrderSummary> _orders = [];
  int _totalOrders = 0;
  int _totalOrderPages = 0;
  int _orderRequestSeq = 0;

  // ---------------------------------------------------------------------------
  // Stock Requests Tab State
  // ---------------------------------------------------------------------------
  final TextEditingController _stockRequestSearchController = TextEditingController();
  Timer? _stockRequestSearchDebounceTimer;

  String _selectedStockRequestStatus = 'all';

  int _stockRequestPage = 1;
  static const int _stockRequestPageSize = 20;

  bool _isLoadingStockRequests = true;
  String? _stockRequestErrorMessage;
  List<AdminStockRequestSummary> _stockRequests = [];
  int _totalStockRequests = 0;
  int _totalStockRequestPages = 0;
  int _stockRequestSeq = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.sessionManager ?? AdminSessionManager.instance;
    _ordersApi = widget.ordersApi ??
        widget.adminApi?.orders ??
        AdminOrdersApi(sessionManager: _session);

    _orderSearchController.addListener(_onOrderSearchChanged);
    _stockRequestSearchController.addListener(_onStockRequestSearchChanged);

    _fetchOrders();
    _fetchStockRequests();
  }

  @override
  void dispose() {
    _orderSearchDebounceTimer?.cancel();
    _stockRequestSearchDebounceTimer?.cancel();
    _orderSearchController.removeListener(_onOrderSearchChanged);
    _stockRequestSearchController.removeListener(_onStockRequestSearchChanged);
    _orderSearchController.dispose();
    _stockRequestSearchController.dispose();
    super.dispose();
  }

  void _onOrderSearchChanged() {
    _orderSearchDebounceTimer?.cancel();
    _orderSearchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _orderPage = 1;
      });
      _fetchOrders();
    });
  }

  void _onStockRequestSearchChanged() {
    _stockRequestSearchDebounceTimer?.cancel();
    _stockRequestSearchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _stockRequestPage = 1;
      });
      _fetchStockRequests();
    });
  }

  Future<void> _fetchOrders() async {
    final thisSeq = ++_orderRequestSeq;

    setState(() {
      _isLoadingOrders = true;
      _orderErrorMessage = null;
    });

    final searchVal = _orderSearchController.text.trim();

    try {
      final res = await _ordersApi.getOrders(
        search: searchVal.isNotEmpty ? searchVal : null,
        status: _selectedOrderStatus != 'all' ? _selectedOrderStatus : null,
        vehicleType: _selectedVehicleType != 'all' ? _selectedVehicleType : null,
        page: _orderPage,
        pageSize: _orderPageSize,
      );

      if (!mounted || thisSeq != _orderRequestSeq) return;

      setState(() {
        _orders = res.items;
        _totalOrders = res.total;
        _totalOrderPages = res.totalPages;
        _isLoadingOrders = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _orderRequestSeq) return;
      setState(() {
        _orderErrorMessage = e.message;
        _isLoadingOrders = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _orderRequestSeq) return;
      setState(() {
        _orderErrorMessage = 'Unable to connect to server. Please try again.';
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _fetchStockRequests() async {
    final thisSeq = ++_stockRequestSeq;

    setState(() {
      _isLoadingStockRequests = true;
      _stockRequestErrorMessage = null;
    });

    final searchVal = _stockRequestSearchController.text.trim();

    try {
      final res = await _ordersApi.getStockRequests(
        search: searchVal.isNotEmpty ? searchVal : null,
        status: _selectedStockRequestStatus != 'all' ? _selectedStockRequestStatus : null,
        page: _stockRequestPage,
        pageSize: _stockRequestPageSize,
      );

      if (!mounted || thisSeq != _stockRequestSeq) return;

      setState(() {
        _stockRequests = res.items;
        _totalStockRequests = res.total;
        _totalStockRequestPages = res.totalPages;
        _isLoadingStockRequests = false;
      });
    } on AdminApiException catch (e) {
      if (!mounted || thisSeq != _stockRequestSeq) return;
      setState(() {
        _stockRequestErrorMessage = e.message;
        _isLoadingStockRequests = false;
      });
    } catch (_) {
      if (!mounted || thisSeq != _stockRequestSeq) return;
      setState(() {
        _stockRequestErrorMessage = 'Unable to connect to server. Please try again.';
        _isLoadingStockRequests = false;
      });
    }
  }

  void _openOrderDetail(AdminOrderSummary order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminOrderDetailSheet(
        order: order,
        ordersApi: _ordersApi,
        onOrderUpdated: (_) {
          _fetchOrders();
        },
      ),
    );
  }

  void _openStockRequestDetail(AdminStockRequestSummary request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminStockRequestDetailSheet(
        stockRequest: request,
        ordersApi: _ordersApi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = math.min(width * 0.94, 600.0);

            return Center(
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildHeader(context, width),
                    const SizedBox(height: 12),
                    _buildTabBar(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _activeTab == AdminOrdersTab.orders
                          ? _buildOrdersTabContent()
                          : _buildStockRequestsTabContent(),
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

  Widget _buildHeader(BuildContext context, double width) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            key: const Key('admin_orders_back_button'),
            icon: const Icon(Icons.arrow_back_rounded, color: _deepBlue),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orders & Requests',
                  style: TextStyle(
                    color: _deepBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Review and manage partner orders & stock requests',
                  style: TextStyle(
                    color: Color(0xFF557A95),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('admin_orders_refresh_button'),
            icon: const Icon(Icons.refresh_rounded, color: _royalBlue),
            tooltip: 'Refresh',
            onPressed: () {
              if (_activeTab == AdminOrdersTab.orders) {
                _fetchOrders();
              } else {
                _fetchStockRequests();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              key: const Key('admin_orders_tab_orders'),
              label: 'Orders',
              icon: Icons.shopping_bag_rounded,
              badgeCount: _totalOrders,
              isActive: _activeTab == AdminOrdersTab.orders,
              onTap: () {
                setState(() {
                  _activeTab = AdminOrdersTab.orders;
                });
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              key: const Key('admin_orders_tab_stock_requests'),
              label: 'Stock Requests',
              icon: Icons.swap_horiz_rounded,
              badgeCount: _totalStockRequests,
              isActive: _activeTab == AdminOrdersTab.stockRequests,
              onTap: () {
                setState(() {
                  _activeTab = AdminOrdersTab.stockRequests;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required Key key,
    required String label,
    required IconData icon,
    required int badgeCount,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x140755B5),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? _deepBlue : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: isActive ? _deepBlue : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE8F4FD) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isActive ? _royalBlue : const Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Orders Tab Content
  // =========================================================================

  Widget _buildOrdersTabContent() {
    return Column(
      children: [
        _buildOrdersFilterBar(),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingOrders
              ? const Center(child: CircularProgressIndicator(color: _royalBlue))
              : _orderErrorMessage != null
                  ? _buildErrorView(
                      message: _orderErrorMessage!,
                      onRetry: _fetchOrders,
                    )
                  : _orders.isEmpty
                      ? _buildEmptyView(
                          message: 'No orders found matching your criteria.',
                          onReset: () {
                            _orderSearchController.clear();
                            setState(() {
                              _selectedOrderStatus = 'all';
                              _selectedVehicleType = 'all';
                              _orderPage = 1;
                            });
                            _fetchOrders();
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            return AdminOrderCard(
                              key: Key('admin_order_card_${order.id}'),
                              order: order,
                              onTap: () => _openOrderDetail(order),
                            );
                          },
                        ),
        ),
        if (!_isLoadingOrders && _orderErrorMessage == null && _totalOrders > 0)
          _buildPaginationFooter(
            currentPage: _orderPage,
            totalPages: _totalOrderPages,
            totalItems: _totalOrders,
            itemName: 'orders',
            onPageChanged: (newPage) {
              setState(() {
                _orderPage = newPage;
              });
              _fetchOrders();
            },
          ),
      ],
    );
  }

  Widget _buildOrdersFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorderBlue, width: 1.2),
            ),
            child: TextField(
              key: const Key('admin_orders_search_input'),
              controller: _orderSearchController,
              decoration: const InputDecoration(
                hintText: 'Search order number, partner, or mobile...',
                hintStyle: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _royalBlue, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Filters Row
          Row(
            children: [
              // Status dropdown
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('admin_orders_status_dropdown'),
                      value: _selectedOrderStatus,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: _royalBlue),
                      style: const TextStyle(
                        color: _deepBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedOrderStatus = val;
                          _orderPage = 1;
                        });
                        _fetchOrders();
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(
                            value: 'pending_approval', child: Text('Pending Approval')),
                        DropdownMenuItem(
                            value: 'approved_processing', child: Text('Processing')),
                        DropdownMenuItem(
                            value: 'dispatched', child: Text('Dispatched')),
                        DropdownMenuItem(
                            value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(
                            value: 'rejected', child: Text('Rejected')),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Vehicle Type dropdown
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _fieldBorderBlue, width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('admin_orders_vehicle_dropdown'),
                      value: _selectedVehicleType,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: _royalBlue),
                      style: const TextStyle(
                        color: _deepBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedVehicleType = val;
                          _orderPage = 1;
                        });
                        _fetchOrders();
                      },
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Vehicles')),
                        DropdownMenuItem(value: '2-Wheeler', child: Text('2-Wheeler')),
                        DropdownMenuItem(value: '3-Wheeler', child: Text('3-Wheeler')),
                        DropdownMenuItem(value: 'Both', child: Text('Both')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Stock Requests Tab Content
  // =========================================================================

  Widget _buildStockRequestsTabContent() {
    return Column(
      children: [
        _buildStockRequestsFilterBar(),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingStockRequests
              ? const Center(child: CircularProgressIndicator(color: _royalBlue))
              : _stockRequestErrorMessage != null
                  ? _buildErrorView(
                      message: _stockRequestErrorMessage!,
                      onRetry: _fetchStockRequests,
                    )
                  : _stockRequests.isEmpty
                      ? _buildEmptyView(
                          message: 'No stock requests found matching your criteria.',
                          onReset: () {
                            _stockRequestSearchController.clear();
                            setState(() {
                              _selectedStockRequestStatus = 'all';
                              _stockRequestPage = 1;
                            });
                            _fetchStockRequests();
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _stockRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final req = _stockRequests[index];
                            return AdminStockRequestCard(
                              key: Key('admin_stock_request_card_${req.id}'),
                              stockRequest: req,
                              onTap: () => _openStockRequestDetail(req),
                            );
                          },
                        ),
        ),
        if (!_isLoadingStockRequests &&
            _stockRequestErrorMessage == null &&
            _totalStockRequests > 0)
          _buildPaginationFooter(
            currentPage: _stockRequestPage,
            totalPages: _totalStockRequestPages,
            totalItems: _totalStockRequests,
            itemName: 'requests',
            onPageChanged: (newPage) {
              setState(() {
                _stockRequestPage = newPage;
              });
              _fetchStockRequests();
            },
          ),
      ],
    );
  }

  Widget _buildStockRequestsFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorderBlue, width: 1.2),
            ),
            child: TextField(
              key: const Key('admin_stock_requests_search_input'),
              controller: _stockRequestSearchController,
              decoration: const InputDecoration(
                hintText: 'Search request number, partner, or mobile...',
                hintStyle: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _royalBlue, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Status Filter
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _fieldBorderBlue, width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('admin_stock_requests_status_dropdown'),
                value: _selectedStockRequestStatus,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _royalBlue),
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedStockRequestStatus = val;
                    _stockRequestPage = 1;
                  });
                  _fetchStockRequests();
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(
                      value: 'pending_approval', child: Text('Pending Approval')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Common States & Pagination
  // =========================================================================

  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required String itemName,
    required ValueChanged<int> onPageChanged,
  }) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: Key('pagination_prev_$itemName'),
            icon: const Icon(Icons.chevron_left_rounded),
            color: canPrev ? _royalBlue : const Color(0xFFB0BEC5),
            onPressed: canPrev ? () => onPageChanged(currentPage - 1) : null,
          ),
          Text(
            'Page $currentPage of $totalPages ($totalItems $itemName)',
            style: const TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            key: Key('pagination_next_$itemName'),
            icon: const Icon(Icons.chevron_right_rounded),
            color: canNext ? _royalBlue : const Color(0xFFB0BEC5),
            onPressed: canNext ? () => onPageChanged(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView({
    required String message,
    required VoidCallback onReset,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 48, color: Color(0xFF90A4AE)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF607D8B), fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
