import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import '../home/staff_home_screen.dart';
import '../profile/staff_profile_screen.dart';

class PaymentStatusItem {
  final String dealerName;
  final String invoiceNumber;

  const PaymentStatusItem({
    required this.dealerName,
    required this.invoiceNumber,
  });
}

class StaffPaymentStatusScreen extends StatefulWidget {
  const StaffPaymentStatusScreen({
    super.key,
    this.api,
    this.sessionManager,
  });

  final StaffApi? api;
  final StaffSessionManager? sessionManager;

  @override
  State<StaffPaymentStatusScreen> createState() =>
      _StaffPaymentStatusScreenState();
}

class _StaffPaymentStatusScreenState extends State<StaffPaymentStatusScreen> {
  static const _royalBlue = Color(0xFF083FA5);

  final TextEditingController _searchController = TextEditingController();

  late final StaffApi _api;
  late final StaffSessionManager _sessionManager;

  List<StaffPaymentRecordItem> _allPayments = [];
  List<StaffPaymentRecordItem> _filteredPayments = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _actionPaymentId;
  String _selectedFilter = 'all'; // 'all', 'recorded', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ??
        widget.api?.sessionManager ??
        StaffSessionManager.instance;
    _api = widget.api ?? StaffApi(sessionManager: _sessionManager);
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments({bool isRefresh = false}) async {
    final token = await _sessionManager.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _allPayments = [];
        _filteredPayments = [];
        _errorMessage = null;
      });
      return;
    }

    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final statusParam = _selectedFilter == 'all' ? null : _selectedFilter;
      final res = await _api.getPayments(
        page: 1,
        pageSize: 50,
        status: statusParam,
      );
      if (!mounted) return;
      setState(() {
        _allPayments = res.items;
        _isLoading = false;
        _errorMessage = null;
        _applySearch();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is StaffApiException
            ? e.message
            : 'Unable to load payment records. Please try again.';
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _applySearch();
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<StaffPaymentRecordItem> base = _allPayments;

    if (_selectedFilter != 'all') {
      base = base.where((p) => p.status.toLowerCase() == _selectedFilter);
    }

    if (query.isEmpty) {
      _filteredPayments = base.toList();
    } else {
      _filteredPayments = base.where((item) {
        final dealer = item.displayDealerName.toLowerCase();
        final ref = item.displayReference.toLowerCase();
        final method = item.paymentMethod.toLowerCase();
        final notes = (item.notes ?? '').toLowerCase();
        return dealer.contains(query) ||
            ref.contains(query) ||
            method.contains(query) ||
            notes.contains(query);
      }).toList();
    }
  }

  void _onFilterSelected(String filterKey) {
    setState(() {
      _selectedFilter = filterKey;
    });
    _loadPayments();
  }

  void _navigateBackToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const StaffHomeScreen(),
        ),
      );
    }
  }

  Future<void> _handleApprovePayment(StaffPaymentRecordItem payment) async {
    if (_actionPaymentId != null) return;

    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Approve Payment',
          style: TextStyle(color: _royalBlue, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve payment of ₹${payment.amount.toStringAsFixed(2)} from ${payment.displayDealerName} (${payment.displayReference})?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Remarks (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Verified in bank account',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm-approve-payment-button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _actionPaymentId = payment.id);

    try {
      await _api.approvePayment(
        payment.id,
        remarks: remarksController.text.trim().isNotEmpty
            ? remarksController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment ${payment.displayReference} approved successfully.'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadPayments(isRefresh: true);
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve payment: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actionPaymentId = null);
      }
    }
  }

  Future<void> _handleRejectPayment(StaffPaymentRecordItem payment) async {
    if (_actionPaymentId != null) return;

    final reasonController = TextEditingController();
    String? validationError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Reject Payment',
            style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject payment of ₹${payment.amount.toStringAsFixed(2)} from ${payment.displayDealerName} (${payment.displayReference})?',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason *',
                  errorText: validationError,
                  border: const OutlineInputBorder(),
                  hintText: 'e.g. Cheque bounced / incorrect amount',
                ),
                maxLines: 2,
                onChanged: (_) {
                  if (validationError != null) {
                    setDialogState(() => validationError = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('confirm-reject-payment-button'),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() {
                    validationError = 'Rejection reason is required';
                  });
                  return;
                }
                Navigator.of(dialogCtx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _actionPaymentId = payment.id);

    try {
      await _api.rejectPayment(payment.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment ${payment.displayReference} rejected.'),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadPayments(isRefresh: true);
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject payment: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _actionPaymentId = null);
      }
    }
  }

  String _formatDate(DateTime dt) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final contentWidth = math.min(width * 0.92, 420.0);

            return Stack(
              fit: StackFit.expand,
              children: [
                const SizedBox.expand(),
                RefreshIndicator(
                  color: _royalBlue,
                  onRefresh: () => _loadPayments(isRefresh: true),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height - 68),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: SizedBox(
                            width: contentWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: height * 0.055),
                                _buildHeaderRow(context, width),
                                const SizedBox(height: 12),
                                const Text(
                                  'Payment Status',
                                  style: TextStyle(
                                    color: _royalBlue,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const _AccentBars(),
                                const SizedBox(height: 16),
                                _buildFilterTabs(),
                                const SizedBox(height: 14),
                                _buildSearchField(),
                                const SizedBox(height: 16),
                                if (_isLoading)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 40),
                                      child: CircularProgressIndicator(
                                        color: _royalBlue,
                                      ),
                                    ),
                                  )
                                else if (_errorMessage != null)
                                  _buildErrorState()
                                else if (_filteredPayments.isEmpty)
                                  _buildEmptyState()
                                else
                                  ..._filteredPayments.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _buildPaymentCard(item),
                                    ),
                                  ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'recorded', 'label': 'Pending'},
      {'key': 'approved', 'label': 'Approved'},
      {'key': 'rejected', 'label': 'Rejected'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              key: Key('filter-tab-${f['key']}'),
              onTap: () => _onFilterSelected(f['key']!),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _royalBlue : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? _royalBlue
                        : const Color(0xFFCBEBFF),
                    width: 1.4,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _royalBlue.withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x0A0755B5),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _royalBlue,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, double width) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateBackToHome,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _royalBlue,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Image.asset(
              'assets/images/app_logo_blended.png',
              width: math.min(width * 0.44, 160.0),
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation(0.96),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: _royalBlue,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Search Dealer or Invoice',
          hintStyle: const TextStyle(
            color: Color(0xFF8A98A8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8A98A8),
            size: 24,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(StaffPaymentRecordItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              width: 120,
              height: 48,
              child: CustomPaint(
                painter: const _PaymentCardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Dealer Name & Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayDealerName,
                              style: const TextStyle(
                                color: _royalBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.displayReference,
                              style: const TextStyle(
                                color: Color(0xFF007BCE),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(item.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Middle Row: Amount & Payment Method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: Color(0xFF8A98A8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFBCE6FF),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          item.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF0875BF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date Row
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Color(0xFF8A98A8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(item.recordedAt),
                        style: const TextStyle(
                          color: Color(0xFF8A98A8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Review remarks if present
                  if (item.latestReview?.remarks != null &&
                      item.latestReview!.remarks!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.isRejected
                            ? const Color(0xFFFFF0F0)
                            : const Color(0xFFF4F9F4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.isRejected
                              ? const Color(0xFFFFCDD2)
                              : const Color(0xFFC8E6C9),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Review Note: ${item.latestReview!.remarks}',
                        style: TextStyle(
                          color: item.isRejected
                              ? const Color(0xFFC62828)
                              : const Color(0xFF2E7D32),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  // Review Action Buttons for 'recorded' status
                  if (item.isRecorded) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE2EDF8)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: Key('reject-payment-button-${item.id}'),
                            onPressed: _actionPaymentId == item.id
                                ? null
                                : () => _handleRejectPayment(item),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC62828),
                              side: const BorderSide(
                                  color: Color(0xFFFFCDD2), width: 1.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            key: Key('approve-payment-button-${item.id}'),
                            onPressed: _actionPaymentId == item.id
                                ? null
                                : () => _handleApprovePayment(item),
                            icon: _actionPaymentId == item.id
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String rawStatus) {
    final status = rawStatus.toLowerCase();
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      case 'voided':
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF616161);
        icon = Icons.block_rounded;
        label = 'Voided';
        break;
      case 'recorded':
      default:
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        icon = Icons.access_time_rounded;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFC62828),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A98A8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadPayments(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _royalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Payment history is not available yet.',
          style: TextStyle(
            color: Color(0xFF8A98A8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Home Tab (Active)
          Expanded(
            child: InkWell(
              onTap: _navigateBackToHome,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(
                    Icons.home_rounded,
                    color: _royalBlue,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Home',
                    style: TextStyle(
                      color: _royalBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 46,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: _royalBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Profile Tab (Inactive)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StaffProfileScreen(),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Spacer(),
                  Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF8A98A8),
                    size: 26,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: Color(0xFF8A98A8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  SizedBox(height: 3.5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentBars extends StatelessWidget {
  const _AccentBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _AccentBar(color: Color(0xFF0755B5)),
        SizedBox(width: 5),
        _AccentBar(color: Color(0xFFFF1B28)),
        SizedBox(width: 5),
        _AccentBar(color: Color(0xFF0875BF)),
      ],
    );
  }
}

class _AccentBar extends StatelessWidget {
  const _AccentBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _PaymentCardWavePainter extends CustomPainter {
  const _PaymentCardWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = const Color(0xFFD0F0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFFBCE6FF).withAlpha(160)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.65,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.7,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.45,
        size.width * 0.7,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.75,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
