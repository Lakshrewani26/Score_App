import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_order_models.dart';
import '../../../core/services/partner_order_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../../customer/qr_scanner/customer_qr_scanner.dart';
import '../home/partner_home_screen.dart';
import '../profile/partner_profile_screen.dart';

class PartnerBalanceScreen extends StatefulWidget {
  const PartnerBalanceScreen({
    super.key,
    this.sessionManager,
    this.orderApi,
    this.pointsEarned,
    this.pointsSpent,
    this.remainingBalance,
  });

  final PartnerSessionManager? sessionManager;
  final PartnerOrderApi? orderApi;
  final String? pointsEarned;
  final String? pointsSpent;
  final String? remainingBalance;

  @override
  State<PartnerBalanceScreen> createState() => _PartnerBalanceScreenState();
}

class _PartnerBalanceScreenState extends State<PartnerBalanceScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  late final PartnerSessionManager _sessionManager;
  late final PartnerOrderApi _orderApi;
  PartnerDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _orderApi =
        widget.orderApi ?? PartnerOrderApi(sessionManager: _sessionManager);
    if (widget.pointsEarned == null ||
        widget.pointsSpent == null ||
        widget.remainingBalance == null) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _orderApi.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
      });
    } catch (_) {
      // Preserve fallback placeholder
    }
  }

  String get _displayEarned {
    if (widget.pointsEarned != null) return widget.pointsEarned!;
    if (_stats != null) return _stats!.totalPoints.toString();
    return '—';
  }

  String get _displaySpent {
    if (widget.pointsSpent != null) return widget.pointsSpent!;
    if (_stats != null) return _stats!.pointsUsed.toString();
    return '—';
  }

  String get _displayBalance {
    if (widget.remainingBalance != null) return widget.remainingBalance!;
    if (_stats != null) return _stats!.remainingBalance.toString();
    final earned = num.tryParse(_displayEarned);
    final spent = num.tryParse(_displaySpent);
    if (earned != null && spent != null) {
      final balance = earned - spent;
      return balance % 1 == 0
          ? balance.toInt().toString()
          : balance.toStringAsFixed(2);
    }
    return '—';
  }

  void _navigateBackToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PartnerHomeScreen(
            sessionManager: _sessionManager,
            orderApi: _orderApi,
          ),
        ),
      );
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
                              const SizedBox(height: 14),
                              const Text(
                                'Balance',
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
                                'Points Earned, Points Spent & Balance',
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
                              const SizedBox(height: 20),
                              _buildPointsSummaryCard(),
                              const SizedBox(height: 14),
                              _buildScanProductQrButton(),
                              const SizedBox(height: 16),
                              _buildDetailedBreakdownCard(),
                              const SizedBox(height: 16),
                              _buildNoticeCard(),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _navigateBackToHome,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
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
    );
  }

  Widget _buildScanProductQrButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        key: const Key('partner_scan_product_qr_button'),
        onPressed: _openProductQrScanner,
        style: ElevatedButton.styleFrom(
          backgroundColor: _royalBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
        label: const Text(
          'Scan Product QR Code',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Future<void> _openProductQrScanner() async {
    final token = await _sessionManager.getToken();
    if (!mounted) return;
    await CustomerQrScannerSheet.show(
      context,
      mode: ScannerMode.scan,
      autoSubmit: true,
      authToken: token,
      onScanSuccess: (scanResult) {
        if (mounted) {
          _loadStats();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Awarded ${scanResult.pointsAwarded} partner loyalty points! Updated balance: ${scanResult.newBalance}',
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildPointsSummaryCard() {
    return Container(
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
                        value: _displayEarned,
                      ),
                    ),
                    const _VerticalDivider(),
                    Expanded(
                      child: _buildSummaryColumn(
                        icon: Icons.layers_rounded,
                        iconColor: const Color(0xFF00897B),
                        bgColor: const Color(0xFFD2F5EC),
                        label: 'Points Spent',
                        value: _displaySpent,
                      ),
                    ),
                    const _VerticalDivider(),
                    Expanded(
                      child: _buildSummaryColumn(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: const Color(0xFF673AB7),
                        bgColor: const Color(0xFFEADBFF),
                        label: 'Remaining Balance',
                        value: _displayBalance,
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

  Widget _buildDetailedBreakdownCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderBlue, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140755B5),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points Breakdown',
            style: TextStyle(
              color: _royalBlue,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _buildBreakdownRow(
            label: 'Points Earned / Total Points',
            value: _displayEarned,
            color: const Color(0xFF0755C7),
            icon: Icons.star_outline_rounded,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            label: 'Points Spent / Points Used',
            value: _displaySpent,
            color: const Color(0xFF00897B),
            icon: Icons.layers_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFE2E8F0), height: 1),
          ),
          _buildBreakdownRow(
            label: 'Remaining Balance',
            value: _displayBalance,
            color: const Color(0xFF673AB7),
            icon: Icons.account_balance_wallet_outlined,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _royalBlue,
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isTotal ? 18 : 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCE4FF), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF0755C7),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Points balances reflect verified partner activity. Points can be redeemed for catalogue orders or transferred to staff members.',
              style: TextStyle(
                color: Color(0xFF4A6B94),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
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
      ..color = const Color(0xFFD0F0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFFBCE6FF).withAlpha(160)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.3,
        size.width * 0.65,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.65,
        size.width,
        size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width * 0.7,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.78,
        size.width,
        size.height * 0.65,
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
