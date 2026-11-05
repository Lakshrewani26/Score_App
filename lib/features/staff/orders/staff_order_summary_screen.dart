import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_order_models.dart';
import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import 'staff_orders_screen.dart';

class StaffOrderSummaryScreen extends StatefulWidget {
  const StaffOrderSummaryScreen({
    super.key,
    this.partner,
    this.partnerId,
    this.cartItems,
    this.orderApi,
    this.sessionManager,
    this.onCartUpdated,
    this.onOrderSuccess,
  });

  final StaffAssignedPartner? partner;
  final int? partnerId;
  final List<CartItem>? cartItems;
  final StaffApi? orderApi;
  final StaffSessionManager? sessionManager;
  final ValueChanged<Map<int, int>>? onCartUpdated;
  final VoidCallback? onOrderSuccess;

  int? get effectivePartnerId => partner?.id ?? partnerId;

  @override
  State<StaffOrderSummaryScreen> createState() =>
      _StaffOrderSummaryScreenState();
}

class _StaffOrderSummaryScreenState extends State<StaffOrderSummaryScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _buttonBlue = Color(0xFF0755C7);
  static const _cardBorderBlue = Color(0xFFCBEBFF);
  static const _lightBlueBg = Color(0xFFEBF5FF);
  static const _subtitleColor = Color(0xFF4A6B94);

  late final StaffApi _api;
  late final StaffSessionManager _sessionManager;
  late List<CartItem> _items;
  bool _isSubmitting = false;

  bool get _isDynamicMode => widget.cartItems != null;

  num get _grandTotal =>
      _items.fold<num>(0, (sum, item) => sum + (item.lineTotal ?? 0));
  int get _totalQuantity =>
      _items.fold<int>(0, (sum, item) => sum + item.quantity);

  String get _displayGrandTotal {
    final rounded = _grandTotal.toStringAsFixed(2);
    final integerPart = rounded.split('.').first;
    final decimalPart = rounded.split('.').last;
    final thousands = integerPart.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
    return '₹ $thousands.$decimalPart';
  }

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? StaffSessionManager.instance;
    _api = widget.orderApi ?? StaffApi(sessionManager: _sessionManager);
    _items = widget.cartItems != null ? List<CartItem>.from(widget.cartItems!) : [];
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
    if (!_isDynamicMode) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placement will be available soon.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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

    final partnerId = widget.effectivePartnerId;
    if (partnerId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an assigned dealer to place an order.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final idempotencyKey =
          'staff-order-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(999999)}';
      final orderResponse = await _api.createOrder(
        partnerId: partnerId,
        items: _items,
        notes: 'Placed by Staff for Dealer #$partnerId',
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _items.clear();
      });

      widget.onOrderSuccess?.call();
      _showOrderConfirmationDialog(orderResponse);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showOrderConfirmationDialog(PartnerOrderResponse order) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00897B), size: 28),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Order Placed!',
                  style: TextStyle(
                    color: _royalBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.orderNumber}',
                style: const TextStyle(
                  color: _royalBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dealer: ${widget.partner?.businessName ?? order.businessName ?? order.partnerName}',
                style: const TextStyle(
                  color: Color(0xFF4A6B94),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Status: Pending Approval',
                style: const TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total: ${order.displayGrandTotal}',
                style: const TextStyle(
                  color: _royalBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Order has been submitted on behalf of the Dealer and is now visible in the Dealer\'s Partner account.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                Navigator.of(context).pop(); // pop summary screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _buttonBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
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
                        builder: (_) => const StaffOrdersScreen(),
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
                    width: 90,
                    height: 90,
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
                            size: 46,
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
                                size: 20,
                                color: _royalBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 1.2,
                    height: 72,
                    color: _cardBorderBlue,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Order\nSummary',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: _royalBlue,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.partner != null
                              ? 'Dealer: ${widget.partner!.businessName}'
                              : 'Review your selected items',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            if (!_isDynamicMode)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Staff order placement is not available yet.',
                  key: Key('staff-order-summary-empty-state'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _subtitleColor),
                ),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No items in order summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _subtitleColor),
                ),
              )
            else ...[
              for (int i = 0; i < _items.length; i++) ...[
                _buildDynamicItemRow(_items[i], i),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            width: 76,
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
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDynamicItemRow(CartItem item, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _royalBlue,
                  ),
                ),
                if (item.product.productCode.isNotEmpty)
                  Text(
                    item.product.productCode,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.quantity}',
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _royalBlue,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFE53935)),
              onPressed: () => _removeItem(index),
              tooltip: 'Remove',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Units',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  '$_totalQuantity units',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _royalBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Grand Total (MRP)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  _displayGrandTotal,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _royalBlue,
                  ),
                ),
              ],
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
        onPressed: _isSubmitting ? null : _handlePlaceOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: _buttonBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: const Color(0x330755C7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
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
