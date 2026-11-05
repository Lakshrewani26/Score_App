import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import '../home/staff_home_screen.dart';
import '../profile/staff_profile_screen.dart';
import '../orders/staff_orders_screen.dart';


class StaffDealersAssociatedScreen extends StatefulWidget {
  const StaffDealersAssociatedScreen({
    super.key,
    this.api,
    this.sessionManager,
  });

  final StaffApi? api;
  final StaffSessionManager? sessionManager;

  @override
  State<StaffDealersAssociatedScreen> createState() =>
      _StaffDealersAssociatedScreenState();
}

class _StaffDealersAssociatedScreenState
    extends State<StaffDealersAssociatedScreen> {
  static const _royalBlue = Color(0xFF083FA5);

  final TextEditingController _searchController = TextEditingController();
  late final StaffSessionManager _sessionManager =
      widget.sessionManager ?? StaffSessionManager.instance;
  late final StaffApi _api;
  List<StaffAssignedPartner> _allPartners = [];
  List<StaffAssignedPartner> _filteredPartners = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? StaffApi(sessionManager: _sessionManager);
    _loadPartners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredPartners = List.from(_allPartners);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredPartners = _allPartners
            .where((partner) =>
                partner.name.toLowerCase().contains(lowerQuery) ||
                partner.businessName.toLowerCase().contains(lowerQuery))
            .toList();
      }
    });
  }

  Future<void> _loadPartners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final partners = await _api.getAssignedPartners();
      if (!mounted) return;
      setState(() {
        _allPartners = partners;
        _isLoading = false;
      });
      _onSearchChanged(_searchController.text);
    } on StaffApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: height * 0.055),
                          _buildHeaderRow(context, width),
                          const SizedBox(height: 12),
                          const Text(
                            'Dealers Associated',
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your partner details',
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildSearchField(),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: _royalBlue,
                                    ),
                                  )
                                : _errorMessage != null
                                    ? _buildErrorState()
                                    : _filteredPartners.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.builder(
                                            padding: const EdgeInsets.only(
                                              bottom: 24,
                                            ),
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: _filteredPartners.length,
                                            itemBuilder: (context, index) {
                                              return _buildPartnerCard(
                                                _filteredPartners[index],
                                              );
                                            },
                                          ),
                          ),
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
          Center(
            child: Image.asset(
              'assets/images/app_logo_blended.png',
              width: math.min(width * 0.44, 160.0),
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation(0.96),
            ),
          ),
          Positioned(
            right: 0,
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
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBEBFF), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: _royalBlue,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: 'Search dealers',
          hintStyle: TextStyle(
            color: Color(0xFF8A98A8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Color(0xFF0068B9),
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _allPartners.isEmpty
        ? 'No Partners have been assigned to your account yet.'
        : 'No Partners match your search.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _royalBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _royalBlue,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadPartners,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerCard(StaffAssignedPartner partner) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffOrdersScreen(
                partner: partner,
                sessionManager: _sessionManager,
                orderApi: _api,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCBEBFF), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140755B5),
                blurRadius: 12,
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
                  height: 36,
                  child: CustomPaint(
                    painter: const _DealerCardWavePainter(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD4F0FF),
                        ),
                        child: const Icon(
                          Icons.domain_rounded,
                          color: Color(0xFF0755C7),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              partner.businessName,
                              style: const TextStyle(
                                color: _royalBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              partner.name,
                              style: const TextStyle(
                                color: Color(0xFF6782A0),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${partner.businessAddress} • ${partner.mobile}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6782A0),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF083FA5),
                        size: 24,
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
          // Home Tab (Active)
          Expanded(
            child: InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => StaffHomeScreen(
                        sessionManager: _sessionManager,
                      ),
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
          // Profile Tab (Inactive)
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

class _DealerCardWavePainter extends CustomPainter {
  const _DealerCardWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = const Color(0xFFD0F0FF).withAlpha(140)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFFBCE6FF).withAlpha(180)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.65,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.7,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.45,
        size.width * 0.7,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.75,
        size.width,
        size.height * 0.55,
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
