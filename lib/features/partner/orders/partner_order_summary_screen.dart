import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_order_models.dart';
import '../../../core/services/partner_order_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class PartnerOrderSummaryScreen extends StatefulWidget {
  const PartnerOrderSummaryScreen({
    super.key,
    this.cartItems,
    this.onCartUpdated,
    this.onOrderSuccess,
    this.api,
    this.sessionManager,
    this.orderId,
    this.existingOrder,
  });

  final List<CartItem>? cartItems;
  final ValueChanged<Map<int, int>>? onCartUpdated;
  final VoidCallback? onOrderSuccess;
  final PartnerOrderApi? api;
  final PartnerSessionManager? sessionManager;
  final int? orderId;
  final PartnerOrderResponse? existingOrder;

  @override
  State<PartnerOrderSummaryScreen> createState() =>
      _PartnerOrderSummaryScreenState();
}

class _PartnerOrderSummaryScreenState extends State<PartnerOrderSummaryScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _buttonBlue = Color(0xFF0755C7);
  static const _cardBorderBlue = Color(0xFFCBEBFF);
  static const _lightBlueBg = Color(0xFFEBF5FF);
  static const _subtitleColor = Color(0xFF4A6B94);

  late final PartnerOrderApi _api;
  late final PartnerSessionManager _sessionManager;
  late List<CartItem> _items;
  bool _isSubmitting = false;

  PartnerOrderResponse? _loadedOrder;
  bool _isLoadingOrder = false;
  String? _loadOrderErrorMessage;
  bool _isCancelling = false;
  bool _isDownloadingPdf = false;
  PartnerOrderPreviewResponse? _orderPreview;

  bool get _isDynamicMode => widget.cartItems != null;
  bool get _isViewMode => widget.orderId != null || widget.existingOrder != null;

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _api = widget.api ?? PartnerOrderApi(sessionManager: _sessionManager);
    _items =
        widget.cartItems != null ? List<CartItem>.from(widget.cartItems!) : [];

    if (widget.existingOrder != null) {
      _loadedOrder = widget.existingOrder;
    } else if (widget.orderId != null) {
      _loadExistingOrder(widget.orderId!);
    } else if (_items.isNotEmpty) {
      _fetchPreview();
    }
  }

  Future<void> _fetchPreview() async {
    if (_items.isEmpty) {
      if (mounted) setState(() => _orderPreview = null);
      return;
    }
    try {
      final preview = await _api.previewOrder(_items);
      if (!mounted) return;
      setState(() {
        _orderPreview = preview;
      });
    } catch (_) {
      // preview is best-effort fallback
    }
  }

  Future<void> _loadExistingOrder(int orderId) async {
    setState(() {
      _isLoadingOrder = true;
      _loadOrderErrorMessage = null;
    });

    try {
      final order = await _api.getOrder(orderId);
      if (!mounted) return;
      setState(() {
        _loadedOrder = order;
        _isLoadingOrder = false;
      });
    } on PartnerOrderApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadOrderErrorMessage = e.message;
        _isLoadingOrder = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadOrderErrorMessage = 'Failed to load order: $e';
        _isLoadingOrder = false;
      });
    }
  }

  Future<void> _handleCancelLoadedOrder() async {
    if (_loadedOrder == null || _isCancelling) return;

    if (_loadedOrder!.status != 'pending_approval') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Orders in ${_formatStatus(_loadedOrder!.status)} status cannot be cancelled.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel order ${_loadedOrder!.orderNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1725),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      final updatedOrder = await _api.cancelOrder(_loadedOrder!.id);
      if (!mounted) return;
      setState(() {
        _loadedOrder = updatedOrder;
        _isCancelling = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order ${updatedOrder.orderNumber} has been cancelled successfully.',
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
        ),
      );
    } on PartnerOrderApiException catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCancelling = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _downloadPdfForOrder(PartnerOrderResponse order) async {
    setState(() => _isDownloadingPdf = true);

    try {
      final pdfBytes = await _api.downloadOrderPdf(order.id);

      if (!mounted) return;

      final fileName = 'Score_Order_${order.orderNumber}.pdf';

      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: pdfBytes,
          fileName: fileName,
        ),
      );

      if (!mounted) return;

      setState(() => _isDownloadingPdf = false);

      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF save cancelled.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully: $savedPath'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDownloadingPdf = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _formatStatus(String status) {
    return switch (status) {
      'pending_approval' => 'Pending Approval',
      'approved_processing' => 'Approved / Processing',
      'dispatched' => 'Dispatched',
      'delivered' => 'Delivered',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status,
    };
  }

  num? get _grandTotal {
    if (_items.any((item) => item.lineTotal == null)) return null;
    return _items.fold<num>(0, (sum, item) => sum + item.lineTotal!);
  }

  int get _totalQuantity {
    return _items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  String get _displayGrandTotal {
    final total = _grandTotal;
    if (total == null) return 'Price unavailable';
    final rounded = total.toStringAsFixed(2);
    final integerPart = rounded.split('.').first;
    final decimalPart = rounded.split('.').last;
    final thousands = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '₹ $thousands.$decimalPart';
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    final updatedQuantities = <int, int>{};
    for (final item in _items) {
      updatedQuantities[item.product.id] = item.quantity;
    }
    widget.onCartUpdated?.call(updatedQuantities);
    _fetchPreview();
  }

  Future<void> _handlePlaceOrder() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('empty-order-summary-snackbar'),
          content: Text('No items in order summary to place.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check for invalid price
    for (final item in _items) {
      if (item.product.price == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product "${item.product.name}" has no authorized price. Cannot place order.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final idempotencyKey =
        'order-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(999999)}';

    try {
      final orderResponse = await _api.createOrder(
        items: _items,
        idempotencyKey: idempotencyKey,
      );

      // Successfully saved on server! Clear cart
      widget.onOrderSuccess?.call();

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Trigger WhatsApp delivery and show order confirmation dialog
      final waFuture = _api.sendOrderWhatsApp(orderResponse.id);
      _showOrderConfirmationDialog(orderResponse, waFuture);
    } on PartnerOrderApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorDialog(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showErrorDialog('Failed to place order: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Order Submission Error',
                style: TextStyle(
                    color: _royalBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK',
                style:
                    TextStyle(color: _royalBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationDialog(
    PartnerOrderResponse order,
    Future<WhatsAppDeliveryResult> initialWhatsAppFuture,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _OrderSuccessDialog(
          order: order,
          initialWhatsAppFuture: initialWhatsAppFuture,
          api: _api,
          onReturnToCatalogue: () {
            Navigator.of(dialogCtx).pop(); // pop dialog
            if (Navigator.of(context).canPop()) {
              Navigator.of(context)
                  .pop(); // pop summary screen back to catalogue
            }
          },
        );
      },
    );
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
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context),
                              const SizedBox(height: 18),
                              _buildHeaderCard(),
                              if (_isDynamicMode || (_isViewMode && _loadedOrder != null)) ...[
                                const SizedBox(height: 14),
                                _buildPartnerDetailsCard(),
                              ],
                              const SizedBox(height: 18),
                              _buildOrderSummaryCard(context),
                              const SizedBox(height: 28),
                            ],
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
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            const PartnerTwoWheelerCatalogueScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardBorderBlue, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0755B5),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _royalBlue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            'assets/images/app_logo_blended.png',
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              'ScorE',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _royalBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderBlue, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0755B5),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 45,
              child: CustomPaint(
                painter: _HeaderCardWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _lightBlueBg,
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 42,
                            color: _royalBlue,
                          ),
                          Positioned(
                            right: 2,
                            top: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: _royalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 1.2,
                    height: 64,
                    color: _cardBorderBlue,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _royalBlue,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isViewMode
                              ? (_loadedOrder != null
                                  ? 'Invoice #${_loadedOrder!.orderNumber}'
                                  : 'Review order details')
                              : 'Review your selected items',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerDetailsCard() {
    final sessionPartner = _sessionManager.currentUser;
    final partnerName = _loadedOrder?.businessName ??
        _loadedOrder?.partnerName ??
        sessionPartner?.businessName ??
        sessionPartner?.name ??
        'Partner';
    final partnerCode = _loadedOrder != null
        ? _loadedOrder!.orderNumber
        : (sessionPartner?.partnerCode ?? 'Partner');
    final mobile = _loadedOrder?.partnerMobile ?? sessionPartner?.mobile ?? '';
    final orderDate = _loadedOrder != null
        ? '${_loadedOrder!.createdAt.day} ${_monthName(_loadedOrder!.createdAt.month)} ${_loadedOrder!.createdAt.year}'
        : '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 20, color: _royalBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  partnerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _royalBlue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _lightBlueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  partnerCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _royalBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              if (mobile.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 15, color: _subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      mobile,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: _subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    orderDate,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          if (_loadedOrder != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                _buildStatusPill(_loadedOrder!.status),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (status) {
      case 'delivered':
        bgColor = const Color(0xFFDCFCE7);
        borderColor = const Color(0xFFBBF7D0);
        textColor = const Color(0xFF15803D);
        break;
      case 'approved_processing':
      case 'dispatched':
        bgColor = const Color(0xFFE0F2FE);
        borderColor = const Color(0xFFBAE6FD);
        textColor = const Color(0xFF0369A1);
        break;
      case 'cancelled':
      case 'rejected':
        bgColor = const Color(0xFFFEE2E2);
        borderColor = const Color(0xFFFECACA);
        textColor = const Color(0xFFDC2626);
        break;
      case 'pending_approval':
      default:
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFDE68A);
        textColor = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Text(
        _formatStatus(status),
        key: const Key('view-order-status-pill'),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildOrderSummaryCard(BuildContext context) {
    if (_isViewMode) {
      if (_isLoadingOrder) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorderBlue, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0755B5),
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: CircularProgressIndicator(key: Key('order-detail-loading')),
          ),
        );
      }

      if (_loadOrderErrorMessage != null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorderBlue, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0755B5),
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 36),
              const SizedBox(height: 10),
              Text(
                _loadOrderErrorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _royalBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  if (widget.orderId != null) {
                    _loadExistingOrder(widget.orderId!);
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      if (_loadedOrder != null) {
        final order = _loadedOrder!;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorderBlue, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0755B5),
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _buildTableHeader(),
                if (order.items.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No items in this order',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _subtitleColor,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  for (int i = 0; i < order.items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEBF4FA),
                      ),
                    _buildViewOrderItemRow(order.items[i], i),
                  ],
                  const Divider(
                      height: 1, thickness: 1.5, color: _cardBorderBlue),
                  _buildViewGrandTotalFooter(order),
                ],
                _buildViewModeActions(order),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderBlue, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0755B5),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildTableHeader(),
            if (_items.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                child: Center(
                  child: Text(
                    'No items in order summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _subtitleColor,
                    ),
                  ),
                ),
              ),
            ] else ...[
              for (int i = 0; i < _items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEBF4FA),
                  ),
                _buildDynamicItemRow(_items[i], i),
              ],
              const Divider(height: 1, thickness: 1.5, color: _cardBorderBlue),
              _buildGrandTotalFooter(),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 16, top: 4),
              child: _buildPlaceOrderButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      width: double.infinity,
      color: _lightBlueBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: const [
          Expanded(
            flex: 4,
            child: Text(
              'ITEM',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _royalBlue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Center(
              child: Text(
                'QUANTITY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _royalBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'MRP',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _royalBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildDynamicItemRow(CartItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _royalBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.product.productCode} · ${item.displayUnitPrice}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _lightBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.quantity}',
                  key: Key('order-item-qty-$index'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _royalBlue,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                item.displayLineTotal,
                key: Key('order-item-total-$index'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _royalBlue,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                key: Key('order-item-remove-$index'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _removeItem(index),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _lightBlueBg,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _royalBlue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalFooter() {
    final preview = _orderPreview;
    final hasDiscount = preview != null &&
        (preview.totalDiscount != null && preview.totalDiscount! > 0);

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          if (hasDiscount) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal Before Discount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _subtitleColor,
                    ),
                  ),
                ),
                Text(
                  '₹ ${(preview.subtotalBeforeDiscount ?? _grandTotal ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Partner Discount (${(preview.discountPercentage ?? 0).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ),
                Text(
                  '-₹ ${(preview.totalDiscount ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _royalBlue,
                      ),
                    ),
                    Text(
                      '${_items.length} items · $_totalQuantity units',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hasDiscount && preview.finalTotal != null
                    ? '₹ ${preview.finalTotal!.toStringAsFixed(2)}'
                    : _displayGrandTotal,
                key: const Key('order-grand-total-text'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _royalBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        key: const Key('place-order-button'),
        onPressed: _isSubmitting ? null : _handlePlaceOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: _buttonBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF90B4E8),
          elevation: 4,
          shadowColor: const Color(0x330755C7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Placing Order...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Place Order',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 22,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildViewOrderItemRow(PartnerOrderItemResponse item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _royalBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.productCode} · ₹ ${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _subtitleColor,
                  ),
                ),
                if (item.discountPercentage != null &&
                    item.discountPercentage! > 0) ...[
                  const SizedBox(height: 1),
                  Text(
                    'MRP: ₹ ${item.originalPrice?.toStringAsFixed(2) ?? ''} (-${item.discountPercentage!.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _lightBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.quantity}',
                  key: Key('view-order-item-qty-$index'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _royalBlue,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '₹ ${item.subtotal.toStringAsFixed(2)}',
                key: Key('view-order-item-total-$index'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _royalBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewGrandTotalFooter(PartnerOrderResponse order) {
    final hasDiscount =
        order.totalDiscount != null && order.totalDiscount! > 0;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          if (hasDiscount) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Subtotal Before Discount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _subtitleColor,
                    ),
                  ),
                ),
                Text(
                  '₹ ${(order.subtotalBeforeDiscount ?? order.orderTotal).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Partner Discount (${(order.discountPercentage ?? 0).toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ),
                Text(
                  '-₹ ${(order.totalDiscount ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _royalBlue,
                      ),
                    ),
                    Text(
                      '${order.itemCount} items · ${order.totalQuantity} units',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                order.displayGrandTotal,
                key: const Key('order-grand-total-text'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _royalBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeActions(PartnerOrderResponse order) {
    final canCancel =
        _sessionManager.isAuthenticated && order.status == 'pending_approval';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('download-pdf-button'),
              onPressed:
                  _isDownloadingPdf ? null : () => _downloadPdfForOrder(order),
              icon: _isDownloadingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                _isDownloadingPdf ? 'Downloading PDF...' : 'Download Order PDF',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('cancel-order-button'),
                onPressed: _isCancelling ? null : _handleCancelLoadedOrder,
                icon: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined,
                        color: Color(0xFFFF1725), size: 20),
                label: Text(
                  _isCancelling ? 'Cancelling...' : 'Cancel Order',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF1725),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF1725), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order is ${_formatStatus(order.status)} and cannot be cancelled.',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderSuccessDialog extends StatefulWidget {
  const _OrderSuccessDialog({
    required this.order,
    required this.initialWhatsAppFuture,
    required this.api,
    required this.onReturnToCatalogue,
  });

  final PartnerOrderResponse order;
  final Future<WhatsAppDeliveryResult> initialWhatsAppFuture;
  final PartnerOrderApi api;
  final VoidCallback onReturnToCatalogue;

  @override
  State<_OrderSuccessDialog> createState() => _OrderSuccessDialogState();
}

class _OrderSuccessDialogState extends State<_OrderSuccessDialog> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _buttonBlue = Color(0xFF0755C7);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  bool _waLoading = true;
  WhatsAppDeliveryResult? _waResult;
  bool _pdfDownloading = false;

  @override
  void initState() {
    super.initState();
    _handleWhatsAppFuture(widget.initialWhatsAppFuture);
  }

  void _handleWhatsAppFuture(Future<WhatsAppDeliveryResult> future) {
    setState(() => _waLoading = true);
    future.then((result) {
      if (mounted) {
        setState(() {
          _waLoading = false;
          _waResult = result;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _waLoading = false;
          _waResult = WhatsAppDeliveryResult(
            success: false,
            status: 'error',
            message: 'Failed to dispatch WhatsApp: $error',
            provider: 'cloud_api',
          );
        });
      }
    });
  }

  void _retryWhatsApp() {
    final future = widget.api.sendOrderWhatsApp(widget.order.id);
    _handleWhatsAppFuture(future);
  }


  Future<void> _downloadPdf() async {
    setState(() => _pdfDownloading = true);

    try {
      final pdfBytes = await widget.api.downloadOrderPdf(widget.order.id);

      if (!mounted) return;

      final fileName =
          'Score_Order_${widget.order.orderNumber}.pdf';

      final savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: pdfBytes,
          fileName: fileName,
        ),
      );

      if (!mounted) return;

      setState(() => _pdfDownloading = false);

      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF save cancelled.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully: $savedPath'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _pdfDownloading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 42,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _royalBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Order #: ${widget.order.orderNumber}',
              key: const Key('success-order-number'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
              ),
              child: const Text(
                'Status: Pending Approval',
                key: Key('success-order-status'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Total: ${widget.order.displayGrandTotal}',
              key: const Key('success-order-total'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _royalBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your order has been recorded and submitted for Staff / Admin approval.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            const Divider(color: _cardBorderBlue, height: 1),
            const SizedBox(height: 12),

            // PDF Generation Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFF0284C7), size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order PDF Ready',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _royalBlue,
                          ),
                        ),
                        Text(
                          'Verified server-side snapshot',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const Key('download-pdf-button'),
                    onPressed: _pdfDownloading ? null : _downloadPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 32),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: _pdfDownloading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Download'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // WhatsApp Delivery Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_rounded,
                          color: Color(0xFF22C55E), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'WhatsApp Delivery',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _royalBlue,
                          ),
                        ),
                      ),
                      if (_waLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_waLoading)
                    const Text(
                      'Dispatching PDF document via WhatsApp...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    )
                  else if (_waResult != null && _waResult!.success) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF16A34A), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _waResult!.message,
                            key: const Key('whatsapp-success-message'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFEAB308), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _waResult?.message ?? 'Delivery status pending',
                            key: const Key('whatsapp-failure-message'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('retry-whatsapp-button'),
                        onPressed: _retryWhatsApp,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry WhatsApp',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Return to Catalogue Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                key: const Key('return-to-catalogue-button'),
                onPressed: widget.onReturnToCatalogue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _buttonBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done & Return to Catalogue',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFDED0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.15,
        size.width * 0.65,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.8,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.25,
        size.width,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
