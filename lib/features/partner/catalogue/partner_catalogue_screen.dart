import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../home/partner_home_screen.dart';
import '../profile/partner_profile_screen.dart';
import 'partner_two_wheeler_catalogue_screen.dart';
import 'partner_three_wheeler_catalogue_screen.dart';

class PartnerProductCatalogueScreen extends StatefulWidget {
  const PartnerProductCatalogueScreen({super.key});

  @override
  State<PartnerProductCatalogueScreen> createState() =>
      _PartnerProductCatalogueScreenState();
}

class _PartnerProductCatalogueScreenState
    extends State<PartnerProductCatalogueScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

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
                              SizedBox(height: height * 0.055),
                              _buildHeaderRow(context, width),
                              const SizedBox(height: 16),
                              const Text(
                                'Product Catalogue',
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
                                'Explore our wide range of quality parts',
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
                              const SizedBox(height: 24),
                              _build2WheelerCard(),
                              const SizedBox(height: 18),
                              _build3WheelerCard(),
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
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const PartnerHomeScreen(),
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
      ),
    );
  }

  Widget _build2WheelerCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PartnerTwoWheelerCatalogueScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 165,
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
                height: 55,
                child: CustomPaint(
                  painter: _TwoWheelerCardWavePainter(),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 116,
                      height: 116,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEBF5FF),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 100,
                          height: 72,
                          child: CustomPaint(
                            painter: _MotorcycleIllustrationPainter(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 1.2,
                      height: 96,
                      color: const Color(0xFFCBEBFF),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '2-Wheeler\nParts',
                        style: TextStyle(
                          color: _royalBlue,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDCEBFE),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: _royalBlue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3WheelerCard() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PartnerThreeWheelerCatalogueScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 165,
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
                height: 55,
                child: CustomPaint(
                  painter: _ThreeWheelerCardWavePainter(),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 116,
                      height: 116,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFDE8E8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 100,
                          height: 72,
                          child: CustomPaint(
                            painter: _ThreeWheelerIllustrationPainter(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 1.2,
                      height: 96,
                      color: const Color(0xFFCBEBFF),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        '3-Wheeler\nParts',
                        style: TextStyle(
                          color: _royalBlue,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDCEBFE),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: _royalBlue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          Expanded(
            child: InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const PartnerHomeScreen(),
                    ),
                  );
                }
              },
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

class _TwoWheelerCardWavePainter extends CustomPainter {
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

class _ThreeWheelerCardWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = const Color(0xFFCBE8FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFFFCD6E5).withAlpha(130)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.2,
        size.width * 0.62,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.84,
        size.height * 0.85,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.38, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.28,
        size.width,
        size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.38, size.height)
      ..close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MotorcycleIllustrationPainter extends CustomPainter {
  const _MotorcycleIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final darkBlue = Paint()..color = const Color(0xFF0D357A);
    final brightRed = Paint()..color = const Color(0xFFE5232A);
    final lightBlue = Paint()..color = const Color(0xFFBBE0FF);
    final tireColor = Paint()..color = const Color(0xFF152A50);
    final whitePaint = Paint()..color = Colors.white;

    final strokeDark = Paint()
      ..color = const Color(0xFF0D357A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rearWheelCenter = Offset(width * 0.22, height * 0.68);
    final frontWheelCenter = Offset(width * 0.78, height * 0.68);
    final wheelRadius = width * 0.17;

    // Rear Wheel
    canvas.drawCircle(rearWheelCenter, wheelRadius, tireColor);
    canvas.drawCircle(rearWheelCenter, wheelRadius * 0.65, lightBlue);
    canvas.drawCircle(rearWheelCenter, wheelRadius * 0.3, darkBlue);
    for (int i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawLine(
        rearWheelCenter,
        Offset(
          rearWheelCenter.dx + math.cos(angle) * wheelRadius * 0.6,
          rearWheelCenter.dy + math.sin(angle) * wheelRadius * 0.6,
        ),
        strokeDark..strokeWidth = 1.5,
      );
    }

    // Front Wheel
    canvas.drawCircle(frontWheelCenter, wheelRadius, tireColor);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.65, lightBlue);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.3, darkBlue);
    for (int i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawLine(
        frontWheelCenter,
        Offset(
          frontWheelCenter.dx + math.cos(angle) * wheelRadius * 0.6,
          frontWheelCenter.dy + math.sin(angle) * wheelRadius * 0.6,
        ),
        strokeDark..strokeWidth = 1.5,
      );
    }

    // Front Fork
    final forkPath = Path()
      ..moveTo(frontWheelCenter.dx, frontWheelCenter.dy)
      ..lineTo(width * 0.68, height * 0.25)
      ..lineTo(width * 0.71, height * 0.25)
      ..lineTo(frontWheelCenter.dx + 2, frontWheelCenter.dy);
    canvas.drawPath(forkPath, darkBlue);

    // Handlebars & Mirror
    canvas.drawLine(
      Offset(width * 0.68, height * 0.25),
      Offset(width * 0.64, height * 0.18),
      strokeDark..strokeWidth = 2.5,
    );
    canvas.drawLine(
      Offset(width * 0.67, height * 0.23),
      Offset(width * 0.61, height * 0.22),
      strokeDark..strokeWidth = 2.5,
    );

    // Engine / Frame block
    final enginePath = Path()
      ..moveTo(width * 0.35, height * 0.68)
      ..lineTo(width * 0.60, height * 0.68)
      ..lineTo(width * 0.62, height * 0.45)
      ..lineTo(width * 0.35, height * 0.45)
      ..close();
    canvas.drawPath(enginePath, darkBlue);

    // Engine detailing
    canvas.drawCircle(Offset(width * 0.48, height * 0.56), 6, lightBlue);

    // Exhaust Pipe
    final exhaustPath = Path()
      ..moveTo(width * 0.45, height * 0.65)
      ..lineTo(width * 0.20, height * 0.72)
      ..lineTo(width * 0.18, height * 0.68)
      ..lineTo(width * 0.45, height * 0.60)
      ..close();
    canvas.drawPath(exhaustPath, darkBlue);

    // Fuel Tank (Red)
    final tankPath = Path()
      ..moveTo(width * 0.42, height * 0.42)
      ..quadraticBezierTo(
          width * 0.50, height * 0.20, width * 0.67, height * 0.32)
      ..quadraticBezierTo(
          width * 0.68, height * 0.42, width * 0.55, height * 0.46)
      ..close();
    canvas.drawPath(tankPath, brightRed);

    // Tank highlight stripe
    final tankStripe = Path()
      ..moveTo(width * 0.46, height * 0.36)
      ..quadraticBezierTo(
          width * 0.54, height * 0.27, width * 0.63, height * 0.35)
      ..quadraticBezierTo(
          width * 0.55, height * 0.38, width * 0.46, height * 0.36)
      ..close();
    canvas.drawPath(tankStripe, whitePaint);

    // Seat (Dark Blue)
    final seatPath = Path()
      ..moveTo(width * 0.25, height * 0.36)
      ..quadraticBezierTo(
          width * 0.35, height * 0.34, width * 0.45, height * 0.42)
      ..lineTo(width * 0.42, height * 0.46)
      ..lineTo(width * 0.24, height * 0.40)
      ..close();
    canvas.drawPath(seatPath, darkBlue);

    // Rear cowl/fender (Red)
    final rearCowl = Path()
      ..moveTo(width * 0.15, height * 0.37)
      ..lineTo(width * 0.27, height * 0.36)
      ..lineTo(width * 0.25, height * 0.42)
      ..lineTo(width * 0.14, height * 0.43)
      ..close();
    canvas.drawPath(rearCowl, brightRed);

    // Headlight / Front cowl
    final headlight = Path()
      ..moveTo(width * 0.68, height * 0.28)
      ..lineTo(width * 0.74, height * 0.28)
      ..lineTo(width * 0.71, height * 0.38)
      ..lineTo(width * 0.66, height * 0.35)
      ..close();
    canvas.drawPath(headlight, brightRed);

    canvas.drawCircle(Offset(width * 0.73, height * 0.32), 4, lightBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThreeWheelerIllustrationPainter extends CustomPainter {
  const _ThreeWheelerIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final darkBlue = Paint()..color = const Color(0xFF0D357A);
    final brightRed = Paint()..color = const Color(0xFFE5232A);
    final lightBlue = Paint()..color = const Color(0xFFC7E3FF);
    final tireColor = Paint()..color = const Color(0xFF152A50);
    final whitePaint = Paint()..color = Colors.white;

    final strokeDark = Paint()
      ..color = const Color(0xFF0D357A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rearWheelCenter = Offset(width * 0.24, height * 0.74);
    final frontWheelCenter = Offset(width * 0.78, height * 0.74);
    final wheelRadius = width * 0.14;

    // Rear Wheel
    canvas.drawCircle(rearWheelCenter, wheelRadius, tireColor);
    canvas.drawCircle(rearWheelCenter, wheelRadius * 0.6, lightBlue);
    canvas.drawCircle(rearWheelCenter, wheelRadius * 0.3, darkBlue);

    // Front Wheel
    canvas.drawCircle(frontWheelCenter, wheelRadius, tireColor);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.6, lightBlue);
    canvas.drawCircle(frontWheelCenter, wheelRadius * 0.3, darkBlue);

    // Main Body Cabin (Dark Blue lower)
    final cabinBody = Path()
      ..moveTo(width * 0.16, height * 0.42)
      ..lineTo(width * 0.72, height * 0.42)
      ..lineTo(width * 0.78, height * 0.62)
      ..lineTo(width * 0.68, height * 0.74)
      ..lineTo(width * 0.16, height * 0.74)
      ..close();
    canvas.drawPath(cabinBody, darkBlue);

    // Red Hood / Canopy (Top)
    final roofCanopy = Path()
      ..moveTo(width * 0.18, height * 0.44)
      ..quadraticBezierTo(
          width * 0.14, height * 0.20, width * 0.30, height * 0.18)
      ..lineTo(width * 0.65, height * 0.18)
      ..quadraticBezierTo(
          width * 0.76, height * 0.20, width * 0.74, height * 0.44)
      ..close();
    canvas.drawPath(roofCanopy, brightRed);

    // Side Door Opening / Window (Light Blue / Interior Cutout)
    final doorOpening = Path()
      ..moveTo(width * 0.36, height * 0.24)
      ..lineTo(width * 0.58, height * 0.24)
      ..lineTo(width * 0.58, height * 0.66)
      ..lineTo(width * 0.36, height * 0.66)
      ..close();
    canvas.drawPath(doorOpening, lightBlue);

    // Interior Seat
    final seat = Path()
      ..moveTo(width * 0.38, height * 0.48)
      ..lineTo(width * 0.46, height * 0.48)
      ..lineTo(width * 0.46, height * 0.66)
      ..lineTo(width * 0.38, height * 0.66)
      ..close();
    canvas.drawPath(seat, darkBlue);

    // Front Cowl & Windshield Frame
    final frontNose = Path()
      ..moveTo(width * 0.58, height * 0.22)
      ..lineTo(width * 0.72, height * 0.22)
      ..lineTo(width * 0.82, height * 0.54)
      ..lineTo(width * 0.76, height * 0.68)
      ..lineTo(width * 0.58, height * 0.68)
      ..close();
    canvas.drawPath(frontNose, brightRed);

    // Windshield (White frame & glass)
    final windshieldFrame = Path()
      ..moveTo(width * 0.62, height * 0.26)
      ..lineTo(width * 0.70, height * 0.26)
      ..lineTo(width * 0.74, height * 0.46)
      ..lineTo(width * 0.62, height * 0.46)
      ..close();
    canvas.drawPath(windshieldFrame, whitePaint);

    final windshieldGlass = Path()
      ..moveTo(width * 0.63, height * 0.28)
      ..lineTo(width * 0.69, height * 0.28)
      ..lineTo(width * 0.72, height * 0.44)
      ..lineTo(width * 0.63, height * 0.44)
      ..close();
    canvas.drawPath(windshieldGlass, lightBlue);

    // Headlight (Yellow/White circle on front)
    canvas.drawCircle(Offset(width * 0.80, height * 0.56), 4.5, whitePaint);
    canvas.drawCircle(Offset(width * 0.80, height * 0.56), 3.0, lightBlue);

    // Front Handlebar / Mudguard
    canvas.drawLine(
      Offset(width * 0.74, height * 0.64),
      Offset(width * 0.78, height * 0.74),
      strokeDark,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
