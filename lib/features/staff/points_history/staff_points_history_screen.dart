import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/services/staff_api.dart';
import '../../../core/services/staff_session_manager.dart';
import '../home/staff_home_screen.dart';
import '../profile/staff_profile_screen.dart';

class PointsHistoryItem {
  final String name;
  final String date;
  final String time;
  final String points;

  const PointsHistoryItem({
    required this.name,
    required this.date,
    required this.time,
    required this.points,
  });
}

class StaffPointsHistoryScreen extends StatefulWidget {
  const StaffPointsHistoryScreen({
    super.key,
    this.staffApi,
    this.sessionManager,
  });

  final StaffApi? staffApi;
  final StaffSessionManager? sessionManager;

  @override
  State<StaffPointsHistoryScreen> createState() =>
      _StaffPointsHistoryScreenState();
}

class _StaffPointsHistoryScreenState extends State<StaffPointsHistoryScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  late final StaffSessionManager _sessionManager;
  late final StaffApi _staffApi;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  StaffPointsHistoryResponse? _historyResponse;
  final List<StaffPointHistoryItem> _items = [];
  int _currentPage = 1;

  StaffBalance? _balance;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? StaffSessionManager.instance;
    _staffApi = widget.staffApi ?? StaffApi(sessionManager: _sessionManager);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadHistory(page: 1),
      _loadBalance(),
    ]);
  }

  Future<void> _loadBalance() async {
    final token = await _sessionManager.getToken();
    if (token == null || token.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingBalance = true;
      });
    }

    try {
      final bal = await _staffApi.getBalance();
      if (!mounted) return;
      setState(() {
        _balance = bal;
        _isLoadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _loadHistory({int page = 1}) async {
    final token = await _sessionManager.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _items.clear();
        _errorMessage = null;
      });
      return;
    }

    if (page == 1) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final res = await _staffApi.getPointsHistory(page: page);
      if (!mounted) return;
      setState(() {
        _historyResponse = res;
        _currentPage = page;
        if (page == 1) {
          _items.clear();
        }
        _items.addAll(res.items);
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = e is StaffApiException
            ? e.message
            : 'Unable to load points history. Please check your network.';
      });
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return '$day $month $year';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  void _navigateBackToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const StaffHomeScreen(),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: math.max(height * 0.035, 18.0)),
                          _buildHeaderRow(context, width),
                          const SizedBox(height: 8),
                          const Text(
                            'Points History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'View received points',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _AccentBars(),
                          const SizedBox(height: 12),
                          _buildBalanceCard(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _buildTransactionListContainer(),
                          ),
                          const SizedBox(height: 14),
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
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
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
              errorBuilder: (context, error, stackTrace) => const Text(
                'ScorE',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _royalBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final currentBalance = _balance?.currentBalance ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderBlue, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120755B5),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Points Balance',
                      style: TextStyle(
                        color: Color(0xFF4A6B94),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _isLoadingBalance && _balance == null
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _royalBlue,
                            ),
                          )
                        : Text(
                            '$currentBalance pts',
                            key: const Key('staff-balance-display'),
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD2F5EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Received points are retained in Score.',
            style: TextStyle(
              color: Color(0xFF4A6B94),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionListContainer() {
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
        child: RefreshIndicator(
          color: _royalBlue,
          onRefresh: () => _loadAll(),
          child: _buildContainerBody(),
        ),
      ),
    );
  }

  Widget _buildContainerBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('staff-points-history-loading-indicator'),
          color: _royalBlue,
        ),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        key: const Key('staff-points-history-error-state'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE02424),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9B1C1C),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _loadAll(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Points history is not available yet.',
            key: Key('staff-points-history-empty-state'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF4A6B94),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _items.length + ((_historyResponse?.hasNext ?? false) ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEBF3FB)),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(
                      color: _royalBlue,
                      strokeWidth: 2,
                    )
                  : TextButton(
                      key: const Key('staff-points-history-load-more'),
                      onPressed: () => _loadHistory(page: _currentPage + 1),
                      child: const Text(
                        'Load More',
                        style: TextStyle(
                          color: _royalBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          );
        }

        final item = _items[index];
        final deltaText = '+${item.amount}';
        const deltaColor = Color(0xFF00897B);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFD2F5EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: deltaColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: _royalBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(item.createdAt)} • ${_formatTime(item.createdAt)}',
                      style: const TextStyle(
                        color: Color(0xFF8A98A8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.senderName != null &&
                        item.senderName!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'From: ${item.senderName}',
                        style: const TextStyle(
                          color: Color(0xFF4A6B94),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.referenceId != null &&
                        item.referenceId!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Ref: ${item.referenceId}',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$deltaText pts',
                style: const TextStyle(
                  color: deltaColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        );
      },
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
          // Profile Tab (Inactive)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StaffProfileScreen(),
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
