import 'package:flutter/material.dart';

import '../../../../core/models/admin_order_models.dart';
import '../../../../core/services/admin_api.dart';
import '../../../../core/services/admin_orders_api.dart';

class AdminOrderDetailSheet extends StatefulWidget {
  const AdminOrderDetailSheet({
    super.key,
    required this.order,
    this.ordersApi,
    this.onOrderUpdated,
  });

  final AdminOrderSummary order;
  final AdminOrdersApi? ordersApi;
  final ValueChanged<AdminOrderDetail>? onOrderUpdated;

  @override
  State<AdminOrderDetailSheet> createState() => _AdminOrderDetailSheetState();
}

class _AdminOrderDetailSheetState extends State<AdminOrderDetailSheet> {
  static const _deepBlue = Color(0xFF072763);
  static const _royalBlue = Color(0xFF083FA5);

  late AdminOrderSummary _summary;
  AdminOrderDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _summary = widget.order;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    if (widget.ordersApi == null) {
      setState(() {
        _isLoading = false;
      });
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
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load order details.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleStatusUpdate(String targetStatus, String actionLabel) async {
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm $actionLabel',
          style: const TextStyle(
            color: _deepBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to change order #${_summary.orderNumber} status to ${formatStatus(targetStatus)}?',
          style: const TextStyle(color: Color(0xFF37474F), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            key: const Key('confirm_dialog_action_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirm $actionLabel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      final updated = await widget.ordersApi!.updateOrderStatus(
        _summary.id,
        status: targetStatus,
      );

      if (!mounted) return;
      setState(() {
        _detail = updated;
        _summary = updated;
        _isSubmitting = false;
      });

      widget.onOrderUpdated?.call(updated);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Order #${_summary.orderNumber} updated to ${formatStatus(targetStatus)}'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } on AdminApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE51B24),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update order status. Please try again.'),
          backgroundColor: Color(0xFFE51B24),
        ),
      );
    }
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
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBg = _getStatusBgColor(_summary.status);
    final statusFg = _getStatusTextColor(_summary.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD8DC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _summary.orderNumber,
                            style: const TextStyle(
                              color: _deepBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Created: ${_summary.displayDate}',
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusFg.withAlpha(80), width: 1),
                      ),
                      child: Text(
                        _summary.displayStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF78909C)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE0E0E0)),

              // Content Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _royalBlue),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      size: 48, color: Colors.redAccent),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF37474F),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchDetail,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            children: [
                              _buildPartnerInfoSection(),
                              const SizedBox(height: 18),
                              _buildItemsSection(),
                              const SizedBox(height: 18),
                              _buildOrderSummarySection(),
                              const SizedBox(height: 18),
                              if (_detail != null &&
                                  _detail!.statusHistory.isNotEmpty) ...[
                                _buildStatusHistorySection(),
                                const SizedBox(height: 18),
                              ],
                              _buildActionsSection(),
                              const SizedBox(height: 24),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartnerInfoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partner Information',
            style: TextStyle(
              color: _deepBlue,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Contact Name', _summary.partnerName),
          if (_summary.businessName != null && _summary.businessName!.isNotEmpty)
            _buildInfoRow('Business', _summary.businessName!),
          _buildInfoRow('Mobile', _summary.partnerMobile),
          if (_summary.approvedByName != null)
            _buildInfoRow('Approved By', _summary.approvedByName!),
          if (_summary.notes != null && _summary.notes!.isNotEmpty)
            _buildInfoRow('Notes', _summary.notes!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final items = _detail?.items ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ordered Items',
              style: TextStyle(
                color: _deepBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${items.length} items',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No items found in this order.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          )
        else
          ...items.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(AdminOrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: _deepBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code: ${item.productCode} • ${item.vehicleType}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.discountPercentage != null &&
                  item.discountPercentage! > 0) ...[
                Text(
                  'MRP: ${item.displayOriginalPrice} (-${item.discountPercentage!.toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
              ],
              Text(
                '${item.quantity} × ${item.displayUnitPrice}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.displaySubtotal,
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummarySection() {
    final hasDiscount = (_detail?.totalDiscount != null &&
            _detail!.totalDiscount! > 0) ||
        (_summary.totalDiscount != null && _summary.totalDiscount! > 0);
    final subtotalBefore = _detail?.subtotalBeforeDiscount ??
        _summary.subtotalBeforeDiscount;
    final discountPct =
        _detail?.discountPercentage ?? _summary.discountPercentage;
    final totalDiscount =
        _detail?.totalDiscount ?? _summary.totalDiscount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Ordered Quantity',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              Text(
                '${_summary.totalQuantity} pcs',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (hasDiscount && subtotalBefore != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotal Before Discount',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                Text(
                  formatCurrency(subtotalBefore),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Partner Discount (${(discountPct ?? 0).toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '-${formatCurrency(totalDiscount)}',
                  style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Grand Total',
                style: TextStyle(
                  color: _deepBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _summary.displayOrderTotal,
                style: const TextStyle(
                  color: _deepBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHistorySection() {
    final history = _detail?.statusHistory ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status Audit Trail',
          style: TextStyle(
            color: _deepBlue,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...history.map((h) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.history_toggle_off_rounded,
                    size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${h.displayNewStatus}${h.changedByName != null ? ' by ${h.changedByName}' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (h.remarks != null && h.remarks!.isNotEmpty)
                        Text(
                          h.remarks!,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        h.displayDate,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionsSection() {
    if (_isSubmitting) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(color: _royalBlue),
        ),
      );
    }

    if (_summary.canDispatch) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          key: const Key('admin_order_dispatch_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF512DA8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _handleStatusUpdate('dispatched', 'Dispatch Order'),
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text(
            'Dispatch Order',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (_summary.canDeliver) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          key: const Key('admin_order_deliver_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _handleStatusUpdate('delivered', 'Mark as Delivered'),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text(
            'Mark as Delivered',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (_summary.status == 'pending_approval') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This order is awaiting initial approval from assigned Staff. Admin cannot bypass the approval step.',
                style: TextStyle(color: Color(0xFF9A3412), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Order is in terminal status: ${_summary.displayStatus}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
