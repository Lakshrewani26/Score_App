import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/services/admin_api.dart';
import '../../../core/services/admin_session_manager.dart';
import '../../../core/services/auth_api.dart';
import '../../../core/services/customer_session_manager.dart';
import '../../../core/services/partner_session_manager.dart';
import '../../../core/services/staff_session_manager.dart';
import '../../../core/widgets/score_logo.dart';
import '../../admin/home/admin_home_screen.dart';
import '../../customer/create_account/create_account_screen.dart';
import '../../customer/home/customer_home_screen.dart';
import '../../partner/home/partner_home_screen.dart';
import '../../staff/home/staff_home_screen.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({
    super.key,
    this.authApi,
    this.customerSessionManager,
    this.partnerSessionManager,
    this.staffSessionManager,
    this.adminSessionManager,
  });

  final AuthApi? authApi;
  final CustomerSessionManager? customerSessionManager;
  final PartnerSessionManager? partnerSessionManager;
  final StaffSessionManager? staffSessionManager;
  final AdminSessionManager? adminSessionManager;

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _fieldBorderBlue = Color(0xFF9CDFFF);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AuthApi _api;
  late final CustomerSessionManager _customerSession;
  late final PartnerSessionManager _partnerSession;
  late final StaffSessionManager _staffSession;
  late final AdminSessionManager _adminSession;

  @override
  void initState() {
    super.initState();
    _api = widget.authApi ?? AuthApi();
    _customerSession =
        widget.customerSessionManager ?? CustomerSessionManager.instance;
    _partnerSession =
        widget.partnerSessionManager ?? PartnerSessionManager.instance;
    _staffSession = widget.staffSessionManager ?? StaffSessionManager.instance;
    _adminSession = widget.adminSessionManager ?? AdminSessionManager.instance;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Phone Number and Password'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = await _api.login(mobile: phone, password: password);

      if (!auth.isActive) {
        throw const AuthApiException(
          'Account is deactivated',
          statusCode: 403,
        );
      }

      final role = auth.role.toLowerCase();

      switch (role) {
        case 'customer':
          final customerUser = CustomerUser.fromJson(auth.rawUser);
          await _customerSession.saveSession(
            token: auth.accessToken,
            user: customerUser,
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => CustomerHomeScreen(
                sessionManager: _customerSession,
              ),
            ),
            (route) => false,
          );
          break;

        case 'partner':
          final partnerUser = PartnerUser.fromJson(auth.rawUser);
          await _partnerSession.saveSession(
            token: auth.accessToken,
            user: partnerUser,
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => PartnerHomeScreen(
                sessionManager: _partnerSession,
              ),
            ),
            (route) => false,
          );
          break;

        case 'staff':
          final staffUser = StaffUser.fromJson(auth.rawUser);
          await _staffSession.saveSession(
            token: auth.accessToken,
            user: staffUser,
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => StaffHomeScreen(
                sessionManager: _staffSession,
              ),
            ),
            (route) => false,
          );
          break;

        case 'admin':
          final adminUser = AdminUser.fromJson(auth.rawUser);
          await _adminSession.saveSession(
            token: auth.accessToken,
            user: adminUser,
          );
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => AdminHomeScreen(
                adminUser: adminUser,
                sessionManager: _adminSession,
                adminApi: AdminApi(sessionManager: _adminSession),
              ),
            ),
            (route) => false,
          );
          break;

        default:
          throw const AuthApiException(
            'Access denied: Unrecognized user role',
            statusCode: 403,
          );
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An unexpected error occurred. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            final cardWidth = math.min(width * 0.88, 380.0);

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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: height * 0.05),
                          const ScoreLogo.large(),
                          const SizedBox(height: 16),
                          const Text(
                            'Login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: SizedBox(
                              width: cardWidth,
                              child: Column(
                                children: [
                                  _buildFormCard(context),
                                  const SizedBox(height: 22),
                                  _buildSubmitButton(),
                                  const SizedBox(height: 20),
                                  _buildCreateAccountFooter(context),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: height * 0.05),
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

  Widget _buildFormCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0755B5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 70,
              child: CustomPaint(
                painter: _CardBottomWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPhoneField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldContainer({required Widget child}) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _fieldBorderBlue, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0755B5),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: child,
    );
  }

  Widget _buildIconCircle(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFB8EAFF)],
          radius: 0.78,
        ),
      ),
      child: Icon(
        icon,
        size: 24,
        color: const Color(0xFF073CA2),
      ),
    );
  }

  Widget _buildPhoneField() {
    return _buildFieldContainer(
      child: Row(
        children: [
          _buildIconCircle(Icons.smartphone_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('unified_phone_field'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Phone Number',
                labelText: 'Phone Number',
                hintStyle: TextStyle(
                  color: _royalBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                labelStyle: TextStyle(
                  color: _royalBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildFieldContainer(
      child: Row(
        children: [
          _buildIconCircle(Icons.lock_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('unified_password_field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Password',
                labelText: 'Password',
                hintStyle: TextStyle(
                  color: _royalBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                labelStyle: TextStyle(
                  color: _royalBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            key: const Key('unified_password_visibility_toggle'),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: const Color(0xFF073CA2),
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0755C7),
            Color(0xFF0087D4),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D0755C7),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('unified_login_button'),
          borderRadius: BorderRadius.circular(14),
          onTap: _isLoading ? null : _handleLogin,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountFooter(BuildContext context) {
    return GestureDetector(
      key: const Key('unified_create_account_link'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CreateAccountScreen(),
          ),
        );
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'Arial',
          ),
          children: [
            TextSpan(
              text: "Don't have an account? ",
              style: TextStyle(color: _royalBlue),
            ),
            TextSpan(
              text: 'Create Account',
              style: TextStyle(
                color: Color(0xFF0755C7),
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBottomWavePainter extends CustomPainter {
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
