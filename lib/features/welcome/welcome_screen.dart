import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/widgets/score_branded_background.dart';
import '../../core/widgets/score_logo.dart';
import '../auth/login/unified_login_screen.dart';
import '../customer/create_account/create_account_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _royalBlue = Color(0xFF072763);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final contentWidth = math.min(width * 0.86, 360.0);
            final buttonHeight = math.min(width * 0.17, 66.0);
            final buttonGap = math.max(12.0, math.min(height * 0.02, 16.0));

            return Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(
                  painter: ScoreBrandedBackgroundPainter(
                    variant: ScoreBackgroundVariant.welcome,
                    paintGradient: false,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: math.min(width * 0.50, height * 0.32),
                  child: IgnorePointer(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                        ],
                        stops: [0, 0.34, 1],
                      ).createShader(bounds),
                      child: Image.asset(
                        'assets/images/welcome_vehicle_illustration.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(height: height * 0.065),
                          // Logo
                          const ScoreLogo.large(),
                          SizedBox(height: math.max(10.0, height * 0.016)),
                          // Title
                          Text(
                            'Welcome!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: math.min(width * 0.098, 36.0),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Subtitle
                          Text(
                            'Sign in to continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: math.min(width * 0.052, 19.0),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Accent bars
                          const _AccentBars(),
                          SizedBox(height: math.max(20.0, height * 0.038)),
                          // Buttons Column
                          SizedBox(
                            width: contentWidth,
                            child: Column(
                              children: [
                                _LoginChoice(
                                  label: 'Login',
                                  icon: Icons.login_rounded,
                                  height: buttonHeight,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const UnifiedLoginScreen(),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: buttonGap),
                                _LoginChoice(
                                  label: 'Create Account',
                                  icon: Icons.person_add_alt_1_rounded,
                                  height: buttonHeight,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateAccountScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: height * 0.15),
                        ],
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
}

class _AccentBars extends StatelessWidget {
  const _AccentBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _AccentBar(color: Color(0xFF0055B8)),
        SizedBox(width: 6),
        _AccentBar(color: Color(0xFFE51B24)),
        SizedBox(width: 6),
        _AccentBar(color: Color(0xFF0055B8)),
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
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _LoginChoice extends StatelessWidget {
  const _LoginChoice({
    required this.label,
    required this.icon,
    required this.height,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB0E1FF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0055B8),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _ChoiceIcon(icon: icon),
                const SizedBox(width: 14),
                Container(
                  width: 1.2,
                  height: 26,
                  color: const Color(0xFFA5DCFF),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF072763),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 30,
                  color: Color(0xFF072763),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceIcon extends StatelessWidget {
  const _ChoiceIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA5DCFF), width: 1),
        gradient: const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFC7EEFF)],
          radius: 0.8,
        ),
      ),
      child: Icon(icon, size: 26, color: const Color(0xFF072763)),
    );
  }
}
