import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_order_models.dart';
import '../../../core/services/partner_order_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../catalogue/partner_two_wheeler_catalogue_screen.dart';

class PartnerOrderSummaryScreen extends StatefulWidget {
  const PartnerOrderSummaryScreen({
    super.key,
    this.cartItems,
    this.onCartUpdated,
    this.onOrderSuccess,
    this.api,
    this.sessionManager,
  });

  final List<CartItem>? cartItems;
  final ValueChanged<Map<int, int>>? onCartUpdated;
  final VoidCallback? onOrderSuccess;
  final PartnerOrderApi? api;
  final PartnerSessionManager? sessionManager;

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

  bool get _isDynamicMode => widget.cartItems != null;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? PartnerOrderApi();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _items =
        widget.cartItems != null ? List<CartItem>.from(widget.cartItems!) : [];
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
                              if (_isDynamicMode) ...[
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
                      children: const [
                        Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _royalBlue,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Review your selected items',
                          style: TextStyle(
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
    final partner = _sessionManager.currentUser;
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
                  partner?.businessName ?? partner?.name ?? 'Partner',
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
                  partner?.partnerCode ?? 'Partner',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 15, color: _subtitleColor),
                  const SizedBox(width: 4),
                  Text(
                    partner?.mobile ?? '',
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
                    '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
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
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
            _displayGrandTotal,
            key: const Key('order-grand-total-text'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _royalBlue,
            ),
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
      setState(() => _pdfDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order PDF downloaded successfully (${pdfBytes.length} bytes: Score_Order_${widget.order.orderNumber}.pdf)',
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pdfDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
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
