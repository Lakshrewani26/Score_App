import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/catalogue_models.dart';
import '../../../core/services/customer_session_manager.dart';
import '../../../core/widgets/new_arrivals_section.dart';
import '../../../core/widgets/score_logo.dart';
import '../balance/customer_balance_screen.dart';
import '../catalogue/three_wheeler_parts_screen.dart';
import '../catalogue/two_wheeler_parts_screen.dart';
import '../profile/customer_profile_screen.dart';
import '../qr_scanner/customer_qr_scanner.dart';
import '../transfer_history/customer_transfer_history_screen.dart';
import 'services/new_arrivals_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.sessionManager,
    this.newArrivalsDataSource,
  });

  final CustomerSessionManager? sessionManager;
  final NewArrivalsDataSource? newArrivalsDataSource;
  static NewArrivalsDataSource? defaultDataSource;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  CustomerSessionManager get _session =>
      widget.sessionManager ?? CustomerSessionManager.instance;

  final GlobalKey<NewArrivalsSectionState> _newArrivalsKey =
      GlobalKey<NewArrivalsSectionState>();

  NewArrivalsDataSource get _effectiveArrivalsSource =>
      widget.newArrivalsDataSource ??
      CustomerHomeScreen.defaultDataSource ??
      ApiNewArrivalsDataSource();

  Future<void> _refreshHome() async {
    await _newArrivalsKey.currentState?.reload();
  }

  Future<void> _pushAndReload(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) {
      _newArrivalsKey.currentState?.reload();
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
                RefreshIndicator(
                  color: _royalBlue,
                  onRefresh: _refreshHome,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
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
                                _buildCustomerHeader(),
                                const SizedBox(height: 18),
                                _buildNewArrivalsSection(),
                                const SizedBox(height: 20),
                                _buildSixActionButtonsGrid(),
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeaderRow(BuildContext context, double width) {
    return const Center(
      child: ScoreLogo.medium(),
    );
  }

  Widget _buildCustomerHeader() {
    final customerName = _session.currentUser?.name.trim() ?? '';
    final welcomeText = customerName.isNotEmpty
        ? 'Welcome, $customerName'
        : 'Welcome, Customer';

    return Column(
      children: [
        Text(
          welcomeText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Thank you for being a valued customer!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royalBlue,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const _AccentBars(),
      ],
    );
  }

  Widget _buildNewArrivalsSection() {
    return NewArrivalsSection(
      key: _newArrivalsKey,
      role: NewArrivalsRole.customer,
      dataSource: _effectiveArrivalsSource,
      onProductTap: _showProductDetailsSheet,
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

  Widget _buildSixActionButtonsGrid() {
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
                  _pushAndReload(
                    const TwoWheelerPartsScreen(showCategoryList: true),
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
                  _pushAndReload(
                    const ThreeWheelerPartsScreen(showCategoryList: true),
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
                icon: Icons.qr_code_scanner_rounded,
                iconColor: const Color(0xFF0755C7),
                iconBgColor: const Color(0xFFD4F0FF),
                label: 'Scan QR',
                accentColor: const Color(0xFF00B0FF),
                onTap: () async {
                  await CustomerQrScannerSheet.show(
                    context,
                    autoSubmit: true,
                    onScanSuccess: (scanResult) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Awarded ${scanResult.pointsAwarded} loyalty points! New balance: ${scanResult.newBalance}',
                            ),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFEF3C7),
                label: 'Points History',
                accentColor: const Color(0xFFF59E0B),
                onTap: () {
                  _pushAndReload(
                    CustomerTransferHistoryScreen(
                      sessionManager: _session,
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
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF673AB7),
                iconBgColor: const Color(0xFFEADBFF),
                label: 'Balance',
                accentColor: const Color(0xFF9C27B0),
                onTap: () {
                  _pushAndReload(
                    CustomerBalanceScreen(
                      sessionManager: _session,
                    ),
                  );
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
                onTap: () {
                  CustomerQrScannerSheet.show(
                    context,
                    mode: ScannerMode.transferPoints,
                  );
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

  Widget _buildBottomNavigationBar() {
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
          Expanded(
            child: InkWell(
              onTap: () {
                _pushAndReload(
                  CustomerProfileScreen(sessionManager: _session),
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
  const _CardAccentWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color.withAlpha(35)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = color.withAlpha(20)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.6)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.2,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


