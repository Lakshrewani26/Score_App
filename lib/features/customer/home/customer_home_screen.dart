import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../catalogue/customer_catalogue_screen.dart';
import '../profile/customer_profile_screen.dart';
import '../qr_scanner/customer_qr_scanner.dart';
import '../transfer_history/customer_transfer_history_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _royalBlue = Color(0xFF083FA5);

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
                              const Text(
                                'Welcome, Customer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _royalBlue,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Thank you for being a valued customer!',
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
                              const SizedBox(height: 16),
                              _buildPointsSummaryCard(),
                              const SizedBox(height: 14),
                              _buildPromotionalBanner(),
                              const SizedBox(height: 14),
                              _buildQuickActionCardsRow(),
                              const SizedBox(height: 14),
                              _buildBottomActionCardsRow(),
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeaderRow(BuildContext context, double width) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Image.asset(
            'assets/images/app_logo_blended.png',
            width: math.min(width * 0.44, 160.0),
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.96),
          ),
        ),
        Positioned(
          right: 4,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: _royalBlue,
                    size: 32,
                  ),
                  Positioned(
                    top: 5,
                    right: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF1725),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPointsSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.5),
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
              height: 60,
              child: CustomPaint(
                painter: _SummaryCardBottomWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryColumn(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFF0755C7),
                        bgColor: const Color(0xFFD4F0FF),
                        label: 'Points Earned',
                        value: '—',
                      ),
                    ),
                    const _VerticalDivider(),
                    Expanded(
                      child: _buildSummaryColumn(
                        icon: Icons.layers_rounded,
                        iconColor: const Color(0xFF00897B),
                        bgColor: const Color(0xFFD2F5EC),
                        label: 'Points Spent',
                        value: '—',
                      ),
                    ),
                    const _VerticalDivider(),
                    Expanded(
                      child: _buildSummaryColumn(
                        icon: Icons.percent_rounded,
                        iconColor: const Color(0xFF673AB7),
                        bgColor: const Color(0xFFEADBFF),
                        label: 'Point Rebate Status',
                        value: '—',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionalBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0058CB),
            Color(0xFF0084E3),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D0058CB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BannerCornerSwooshPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const SizedBox(
                    width: 70,
                    height: 65,
                    child: CustomPaint(
                      painter: _GiftBoxPainter(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1.2,
                    height: 52,
                    color: Colors.white.withAlpha(90),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          fontFamily: 'Arial',
                        ),
                        children: [
                          TextSpan(
                            text: 'Rewards details are not available yet.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF0058CB),
                      size: 28,
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

  Widget _buildQuickActionCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFF0755C7),
            iconBgColor: const Color(0xFFD4F0FF),
            label: "Scan Partner's QR Code",
            accentColor: const Color(0xFF00B0FF),
            height: 128,
            onTap: () {
              CustomerQrScannerSheet.show(context);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF7E57C2),
            iconBgColor: const Color(0xFFEDE7F6),
            label: 'Product Catalogue',
            accentColor: const Color(0xFF7C4DFF),
            height: 128,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerCatalogueScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildHorizontalActionCard(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFEF3C7),
            label: 'Transfer History',
            accentColor: const Color(0xFFF59E0B),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CustomerTransferHistoryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildHorizontalActionCard(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBgColor: const Color(0xFFCCFBF1),
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
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required Color accentColor,
    required double height,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBEBFF), width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140755B5),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 38,
                  child: CustomPaint(
                    painter: _CardAccentWavePainter(color: accentColor),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 23,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _royalBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _royalBlue,
                            size: 16,
                          ),
                        ],
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

  Widget _buildHorizontalActionCard({
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBEBFF), width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140755B5),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 28,
                  child: CustomPaint(
                    painter: _CardAccentWavePainter(color: accentColor),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconBgColor,
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: _royalBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: _royalBlue,
                        size: 22,
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CustomerProfileScreen(),
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

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.2,
      height: 65,
      color: const Color(0xFFD4EBF9),
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

class _SummaryCardBottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = const Color(0xFFD0F0FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFFE2CFFF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.2,
        size.width * 0.6,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.85,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.3,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..close();

    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
          size.width * 0.4, size.height * 0.2, size.width, size.height * 0.4)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BannerCornerSwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final redPaint = Paint()
      ..color = const Color(0xFFFF1725)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final bluePaint = Paint()
      ..color = const Color(0xFF003D99)
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.fill;

    final bluePath = Path()
      ..moveTo(size.width * 0.75, size.height)
      ..quadraticBezierTo(
          size.width * 0.88, size.height * 0.55, size.width, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..close();

    final whitePath = Path()
      ..moveTo(size.width * 0.68, size.height)
      ..quadraticBezierTo(
          size.width * 0.85, size.height * 0.45, size.width, size.height * 0.55)
      ..lineTo(size.width, size.height)
      ..close();

    final redLine = Path()
      ..moveTo(size.width * 0.7, size.height)
      ..quadraticBezierTo(size.width * 0.86, size.height * 0.48, size.width,
          size.height * 0.58);

    canvas.drawPath(whitePath, whitePaint);
    canvas.drawPath(bluePath, bluePaint);
    canvas.drawPath(redLine, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GiftBoxPainter extends CustomPainter {
  const _GiftBoxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.45, size.height * 0.55);

    // Sparkle rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFEA00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final rayOffsets = [
      [
        Offset(size.width * 0.1, size.height * 0.2),
        Offset(size.width * 0.22, size.height * 0.3)
      ],
      [
        Offset(size.width * 0.35, size.height * 0.05),
        Offset(size.width * 0.4, size.height * 0.18)
      ],
      [
        Offset(size.width * 0.65, size.height * 0.12),
        Offset(size.width * 0.6, size.height * 0.24)
      ],
      [
        Offset(size.width * 0.05, size.height * 0.5),
        Offset(size.width * 0.16, size.height * 0.52)
      ],
    ];

    for (final ray in rayOffsets) {
      canvas.drawLine(ray[0], ray[1], rayPaint);
    }

    // Gift box main body (3D angled box)
    final boxPaint = Paint()
      ..color = const Color(0xFF00B0FF)
      ..style = PaintingStyle.fill;

    final boxDarkPaint = Paint()
      ..color = const Color(0xFF0080FF)
      ..style = PaintingStyle.fill;

    final boxPath = Path()
      ..moveTo(center.dx - 22, center.dy - 10)
      ..lineTo(center.dx + 18, center.dy - 18)
      ..lineTo(center.dx + 22, center.dy + 16)
      ..lineTo(center.dx - 18, center.dy + 24)
      ..close();

    final sidePath = Path()
      ..moveTo(center.dx + 18, center.dy - 18)
      ..lineTo(center.dx + 27, center.dy - 14)
      ..lineTo(center.dx + 30, center.dy + 18)
      ..lineTo(center.dx + 22, center.dy + 16)
      ..close();

    canvas.drawPath(boxPath, boxPaint);
    canvas.drawPath(sidePath, boxDarkPaint);

    // Ribbon vertical & horizontal
    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final vRibbon = Path()
      ..moveTo(center.dx - 3, center.dy - 14)
      ..lineTo(center.dx + 4, center.dy - 15)
      ..lineTo(center.dx + 5, center.dy + 20)
      ..lineTo(center.dx - 2, center.dy + 21)
      ..close();

    final hRibbon = Path()
      ..moveTo(center.dx - 20, center.dy + 4)
      ..lineTo(center.dx + 20, center.dy - 4)
      ..lineTo(center.dx + 21, center.dy + 3)
      ..lineTo(center.dx - 19, center.dy + 11)
      ..close();

    canvas.drawPath(vRibbon, ribbonPaint);
    canvas.drawPath(hRibbon, ribbonPaint);

    // Box lid
    final lidPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final lidPath = Path()
      ..moveTo(center.dx - 26, center.dy - 18)
      ..lineTo(center.dx + 16, center.dy - 26)
      ..lineTo(center.dx + 28, center.dy - 20)
      ..lineTo(center.dx - 14, center.dy - 12)
      ..close();

    canvas.drawPath(lidPath, lidPaint);

    // Star icon on box front
    final starPaint = Paint()
      ..color = const Color(0xFF0058CB)
      ..style = PaintingStyle.fill;

    final starPath = Path();
    final starCenter = Offset(center.dx + 1, center.dy + 3);
    for (int i = 0; i < 5; i++) {
      double outerAngle = (i * 72 - 90) * math.pi / 180;
      double innerAngle = ((i * 72 + 36) - 90) * math.pi / 180;
      Offset p1 = Offset(starCenter.dx + 7 * math.cos(outerAngle),
          starCenter.dy + 7 * math.sin(outerAngle));
      Offset p2 = Offset(starCenter.dx + 3 * math.cos(innerAngle),
          starCenter.dy + 3 * math.sin(innerAngle));
      if (i == 0) {
        starPath.moveTo(p1.dx, p1.dy);
      } else {
        starPath.lineTo(p1.dx, p1.dy);
      }
      starPath.lineTo(p2.dx, p2.dy);
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
