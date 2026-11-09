import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/models/partner_order_models.dart';
import '../../../core/services/partner_order_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../balance/partner_balance_screen.dart';
import '../catalogue/partner_three_wheeler_catalogue_screen.dart';
import '../catalogue/partner_two_wheeler_catalogue_screen.dart';
import '../orders/partner_my_orders_screen.dart';
import '../profile/partner_profile_screen.dart';
import '../transfer/partner_transfer_history_screen.dart';
import '../transfer/partner_transfer_points_screen.dart';
import 'services/partner_new_arrivals_service.dart';

class PartnerHomeScreen extends StatefulWidget {
  const PartnerHomeScreen({
    super.key,
    this.sessionManager,
    this.orderApi,
    this.newArrivalsDataSource,
  });

  final PartnerSessionManager? sessionManager;
  final PartnerOrderApi? orderApi;
  final PartnerNewArrivalsDataSource? newArrivalsDataSource;

  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  late final PartnerSessionManager _sessionManager;
  late final PartnerOrderApi _orderApi;
  late final PartnerNewArrivalsDataSource _arrivalsSource;

  PartnerDashboardStats? _stats;
  List<CatalogueProduct> _newArrivals = const [];
  bool _isLoadingArrivals = true;

  String get _welcomeName => _sessionManager.currentUser?.name.trim() ?? '';
  String get _totalPoints =>
      _stats != null ? _stats!.totalPoints.toString() : '—';
  String get _pointsUsed =>
      _stats != null ? _stats!.pointsUsed.toString() : '—';
  String get _remainingBalance =>
      _stats != null ? _stats!.remainingBalance.toString() : '—';

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _orderApi =
        widget.orderApi ?? PartnerOrderApi(sessionManager: _sessionManager);
    _arrivalsSource = widget.newArrivalsDataSource ??
        const PlaceholderPartnerNewArrivalsDataSource();
    _loadStats();
    _loadNewArrivals();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _orderApi.getDashboardStats();
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
      final items = await _arrivalsSource.getNewArrivals();
      if (mounted) {
        setState(() {
          _newArrivals = items;
          _isLoadingArrivals = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _newArrivals = const [];
          _isLoadingArrivals = false;
        });
      }
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
                    constraints: BoxConstraints(minHeight: height - 70),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 12),
                              _buildPartnerHeader(),
                              const SizedBox(height: 18),
                              _buildNewArrivalsSection(),
                              const SizedBox(height: 20),
                              _buildSixActionButtonsGrid(context),
                              const SizedBox(height: 24),
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

  Widget _buildHeaderRow(BuildContext context, double width) {
    return Center(
      child: Image.asset(
        'assets/images/app_logo_blended.png',
        width: math.min(width * 0.44, 160.0),
        fit: BoxFit.contain,
        opacity: const AlwaysStoppedAnimation(0.96),
      ),
    );
  }

  Widget _buildPartnerHeader() {
    final welcomeText = _welcomeName.isNotEmpty
        ? 'Welcome, $_welcomeName'
        : 'Welcome, Partner';

    return Column(
      children: [
        Text(
          welcomeText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Thanks for being our valuable partner!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royalBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const _AccentBars(),
      ],
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
                  fontSize: 18,
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
        const SizedBox(height: 10),
        if (_isLoadingArrivals)
          Container(
            height: 182,
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
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _newArrivals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
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
      height: 130,
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
              size: 32,
            ),
            SizedBox(height: 8),
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
      width: 142,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180755B5),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, 4),
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
                  height: 44,
                  child: CustomPaint(
                    painter: _ProductCardWavePainter(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProductImageOrPlaceholder(product.imageUrl),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _royalBlue,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                product.displayPrice,
                                style: const TextStyle(
                                  color: _royalBlue,
                                  fontSize: 12,
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
                                fontSize: 9,
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
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDCEBFE),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: _royalBlue,
          size: 32,
        ),
      );
    }

    return Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCEBFE),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.image_not_supported_rounded,
              color: _royalBlue,
              size: 30,
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
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _cardBorderBlue, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x290755B5),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Product Details',
                        style: TextStyle(
                          color: _royalBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _royalBlue),
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProductImageOrPlaceholder(product.imageUrl),
                const SizedBox(height: 14),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _royalBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Code: ${product.productCode}',
                    style: const TextStyle(
                      color: _royalBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vehicle Type: ${product.vehicleType}',
                  style: const TextStyle(
                    color: Color(0xFF5B7898),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (product.categoryName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${product.categoryName}',
                    style: const TextStyle(
                      color: Color(0xFF5B7898),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${product.displayPrice} MRP',
                    style: const TextStyle(
                      color: _royalBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSixActionButtonsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.two_wheeler_rounded,
                iconColor: const Color(0xFF0755C7),
                iconBgColor: const Color(0xFFD4F0FF),
                label: '2 Wheeler',
                accentColor: const Color(0xFF00B0FF),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PartnerTwoWheelerCatalogueScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFFD32F2F),
                iconBgColor: const Color(0xFFFFEBEE),
                label: '3 Wheeler',
                accentColor: const Color(0xFFFF5252),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const PartnerThreeWheelerCatalogueScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.shopping_cart_rounded,
                iconColor: const Color(0xFFE53935),
                iconBgColor: const Color(0xFFFFDDE2),
                label: 'My Orders',
                accentColor: const Color(0xFFFF4081),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PartnerMyOrdersScreen(
                        api: _orderApi,
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.swap_horiz_rounded,
                iconColor: const Color(0xFF00897B),
                iconBgColor: const Color(0xFFD2F5EC),
                label: 'Transfer Points',
                accentColor: const Color(0xFF14B8A6),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PartnerTransferPointsScreen(),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
                label: 'Points History',
                accentColor: const Color(0xFFF59E0B),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PartnerTransferHistoryScreen(
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF673AB7),
                iconBgColor: const Color(0xFFEADBFF),
                label: 'Balance',
                accentColor: const Color(0xFF9C27B0),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PartnerBalanceScreen(
                        sessionManager: _sessionManager,
                        orderApi: _orderApi,
                        pointsEarned: _totalPoints,
                        pointsSpent: _pointsUsed,
                        remainingBalance: _remainingBalance,
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
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 122,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cardBorderBlue, width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140755B5),
                blurRadius: 10,
                offset: Offset(0, 4),
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
                  height: 34,
                  child: CustomPaint(
                    painter: _CardAccentWavePainter(color: accentColor),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconBgColor,
                          ),
                          child: Icon(
                            icon,
                            color: iconColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 14.5,
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
                    builder: (_) => const PartnerProfileScreen(),
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
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFA5D7FE).withAlpha(150)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.1,
        size.width * 0.58,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.82,
        size.width,
        size.height * 0.38,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.35,
        size.width * 0.68,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.88,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
