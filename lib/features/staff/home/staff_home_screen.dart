import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import '../catalogue/staff_three_wheeler_catalogue_screen.dart';
import '../catalogue/staff_two_wheeler_catalogue_screen.dart';
import '../dealers/staff_dealers_associated_screen.dart';
import '../orders/staff_order_status_screen.dart';
import '../payment_status/staff_payment_status_screen.dart';
import '../points_history/staff_points_history_screen.dart';
import '../profile/staff_profile_screen.dart';
import 'services/staff_new_arrivals_service.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({
    super.key,
    this.sessionManager,
    this.api,
    this.newArrivalsDataSource,
  });

  final StaffSessionManager? sessionManager;
  final StaffApi? api;
  final StaffNewArrivalsDataSource? newArrivalsDataSource;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  late final StaffSessionManager _sessionManager;
  late final StaffApi _api;
  late final StaffNewArrivalsDataSource _newArrivalsDataSource;
  StaffDashboardStats? _stats;

  List<CatalogueProduct> _newArrivals = [];
  bool _isLoadingArrivals = true;

  String get _greeting =>
      'Welcome, ${_sessionManager.currentUser?.name ?? 'Staff'}';
  final String _subtitle = 'Thank you for being our valuable staff';

  @visibleForTesting
  String get dealersValue =>
      _stats != null ? _stats!.dealersCount.toString() : '—';
  @visibleForTesting
  String get pendingOrdersValue =>
      _stats != null ? _stats!.pendingOrdersCount.toString() : '—';
  @visibleForTesting
  String get pendingPaymentsValue =>
      _stats != null ? _stats!.pendingPaymentsCount.toString() : '—';

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? StaffSessionManager.instance;
    _api = widget.api ?? StaffApi(sessionManager: _sessionManager);
    _newArrivalsDataSource = widget.newArrivalsDataSource ??
        const PlaceholderStaffNewArrivalsDataSource();
    _loadStats();
    _loadNewArrivals();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _api.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
      });
    } catch (_) {
      // Fallback preserves '—' placeholder
    }
  }

  Future<void> _loadNewArrivals() async {
    try {
      final items = await _newArrivalsDataSource.getNewArrivals();
      if (!mounted) return;
      setState(() {
        _newArrivals = items;
        _isLoadingArrivals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newArrivals = [];
        _isLoadingArrivals = false;
      });
    }
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
                    constraints: BoxConstraints(minHeight: height - 68),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 14),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 8),
                              Text(
                                _greeting,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _royalBlue,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _subtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _royalBlue,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const _AccentBars(),
                              const SizedBox(height: 14),
                              _buildNewArrivalsSection(),
                              const SizedBox(height: 14),
                              _buildSixActionButtonsGrid(context),
                              const SizedBox(height: 20),
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
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  /// Centered logo with notification bell completely removed.
  Widget _buildHeaderRow(BuildContext context, double width) {
    return Center(
      child: Image.asset(
        'assets/images/app_logo_blended.png',
        width: math.min(width * 0.44, 150.0),
        fit: BoxFit.contain,
        opacity: const AlwaysStoppedAnimation(0.96),
      ),
    );
  }

  Widget _buildNewArrivalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'New Arrivals',
                style: TextStyle(
                  color: _royalBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorderBlue, width: 1),
              ),
              child: const Text(
                'Newly Added',
                style: TextStyle(
                  color: _royalBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingArrivals)
          Container(
            height: 165,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cardBorderBlue, width: 1.2),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: _royalBlue,
                strokeWidth: 2.5,
              ),
            ),
          )
        else if (_newArrivals.isEmpty)
          _buildNewArrivalsEmptyState()
        else
          SizedBox(
            height: 165,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _newArrivals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildNewArrivalCard(_newArrivals[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNewArrivalsEmptyState() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF8A98A8),
              size: 28,
            ),
            SizedBox(height: 6),
            Text(
              'No new arrivals available at this time.',
              style: TextStyle(
                color: Color(0xFF4A6B94),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewArrivalCard(CatalogueProduct product) {
    return Container(
      width: 136,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180755B5),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showProductDetailsSheet(product),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: CustomPaint(
                    painter: _ProductCardWavePainter(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProductImageOrPlaceholder(product.imageUrl),
                      const SizedBox(height: 3),
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _royalBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                product.displayPrice,
                                style: const TextStyle(
                                  color: _royalBlue,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              'MRP',
                              style: TextStyle(
                                color: Color(0xFF5B7898),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _buildProductImageOrPlaceholder(String? imageUrl) {
    final hasValidImage = imageUrl != null && imageUrl.trim().isNotEmpty;
    if (!hasValidImage) {
      return Container(
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDCEBFE),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: _royalBlue,
          size: 28,
        ),
      );
    }

    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCEBFE),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.image_not_supported_rounded,
              color: _royalBlue,
              size: 26,
            );
          },
        ),
      ),
    );
  }

  void _showProductDetailsSheet(CatalogueProduct product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImageOrPlaceholder(product.imageUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${product.productCode}',
                          style: const TextStyle(
                            color: Color(0xFF5B7898),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.vehicleType,
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MRP',
                    style: TextStyle(
                      color: Color(0xFF5B7898),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    product.displayPrice,
                    style: const TextStyle(
                      color: _royalBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (product.description != null &&
                  product.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  product.description!,
                  style: const TextStyle(
                    color: Color(0xFF4A6B94),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSixActionButtonsGrid(BuildContext context) {
    return Column(
      children: [
        // Row 1: 2W and 3W
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const Icon(
                  Icons.two_wheeler_rounded,
                  color: Color(0xFF0755C7),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFD4F0FF),
                label: '2W',
                accentColor: const Color(0xFF00B0FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StaffTwoWheelerCatalogueScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const Icon(
                  Icons.local_shipping_rounded,
                  color: Color(0xFFD32F2F),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFFFEBEE),
                label: '3W',
                accentColor: const Color(0xFFFF5252),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StaffThreeWheelerCatalogueScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 2: Dealers Associated and Order Status
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const Icon(
                  Icons.handshake_rounded,
                  color: Color(0xFF0755C7),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFD4F0FF),
                label: 'Dealers\nAssociated',
                accentColor: const Color(0xFF00B0FF),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StaffDealersAssociatedScreen(
                        sessionManager: _sessionManager,
                      ),
                    ),
                  );
                  if (mounted) {
                    _loadStats();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const _DocumentClockIcon(
                  color: Color(0xFFE53935),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFFFDDE2),
                label: 'Order\nStatus',
                accentColor: const Color(0xFFFF4081),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StaffOrderStatusScreen(
                        api: _api,
                        sessionManager: _sessionManager,
                      ),
                    ),
                  );
                  if (mounted) {
                    _loadStats();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Row 3: Payment Status and Points History
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const _WalletRupeeIcon(
                  color: Color(0xFF673AB7),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFEADBFF),
                label: 'Payment\nStatus',
                accentColor: const Color(0xFF9C27B0),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StaffPaymentStatusScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadStats();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionCard(
                context: context,
                iconWidget: const _DocumentHistoryIcon(
                  color: Color(0xFF00897B),
                  size: 26,
                ),
                iconBgColor: const Color(0xFFD2F5EC),
                label: 'Points\nHistory',
                accentColor: const Color(0xFF14B8A6),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StaffPointsHistoryScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadStats();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required Widget iconWidget,
    required Color iconBgColor,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 114,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _cardBorderBlue, width: 1.3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140755B5),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 30,
                    child: CustomPaint(
                      painter: _CardAccentWavePainter(color: accentColor),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF083FA5).withAlpha(160),
                        size: 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: iconBgColor,
                            ),
                            child: Center(child: iconWidget),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Home Tab (Selected)
          Expanded(
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
          // Profile Tab (Unselected)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StaffProfileScreen(
                      sessionManager: _sessionManager,
                    ),
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

class _WalletRupeeIcon extends StatelessWidget {
  const _WalletRupeeIcon({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: color,
            size: size,
          ),
          Positioned(
            right: 2,
            bottom: 3,
            child: Text(
              '₹',
              style: TextStyle(
                color: color,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentClockIcon extends StatelessWidget {
  const _DocumentClockIcon({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            color: color,
            size: size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(0.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                color: color,
                size: size * 0.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentHistoryIcon extends StatelessWidget {
  const _DocumentHistoryIcon({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            color: color,
            size: size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(0.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restore_rounded,
                color: color,
                size: size * 0.45,
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

class _CardAccentWavePainter extends CustomPainter {
  final Color color;
  const _CardAccentWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = color.withAlpha(22)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = color.withAlpha(40)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.65,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.7,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.35,
        size.width * 0.7,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.75,
        size.width,
        size.height * 0.5,
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

class _ProductCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = const Color(0xFFDCEBFE).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.1,
        size.width * 0.7,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.7,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
