import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_transfer_models.dart';
import '../../../core/services/partner_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../home/partner_home_screen.dart';
import '../profile/partner_profile_screen.dart';

class PartnerTransferHistoryScreen extends StatefulWidget {
  const PartnerTransferHistoryScreen({
    super.key,
    this.partnerApi,
    this.sessionManager,
  });

  final PartnerApi? partnerApi;
  final PartnerSessionManager? sessionManager;

  @override
  State<PartnerTransferHistoryScreen> createState() =>
      _PartnerTransferHistoryScreenState();
}

class _PartnerTransferHistoryScreenState
    extends State<PartnerTransferHistoryScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);

  late final PartnerSessionManager _sessionManager;
  late final PartnerApi _partnerApi;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  PartnerPointsHistoryResponse? _historyResponse;
  final List<PartnerPointHistoryItem> _items = [];
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _partnerApi =
        widget.partnerApi ?? PartnerApi(sessionManager: _sessionManager);
    _loadHistory(page: 1);
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
      final res = await _partnerApi.getPointsHistory(page: page);
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
        _errorMessage = e is PartnerApiException
            ? e.message
            : 'Unable to load points history. Please check your network.';
      });
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _navigateBackToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PartnerHomeScreen(
            sessionManager: _sessionManager,
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
                            'Transfer History',
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
                            'View your recent transfer transactions',
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
          onRefresh: () => _loadHistory(page: 1),
          child: _buildContainerBody(),
        ),
      ),
    );
  }

  Widget _buildContainerBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('partner-history-loading-indicator'),
          color: _royalBlue,
        ),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        key: const Key('partner-history-error-state'),
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
                onPressed: () => _loadHistory(page: 1),
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
            'No points history available yet.',
            key: Key('partner-transfer-history-empty-state'),
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
        final isCredit = item.isCredit;
        final sign = isCredit ? '+' : '−';
        final deltaText = '$sign${item.amount}';
        final deltaColor = isCredit
            ? const Color(0xFF00897B)
            : const Color(0xFFE53935);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCredit
                      ? const Color(0xFFD2F5EC)
                      : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit
                      ? Icons.add_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
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
                    if (item.recipientName != null &&
                        item.recipientName!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        'To: ${item.recipientName}${item.recipientStaffId != null ? ' (${item.recipientStaffId})' : ''}',
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
                style: TextStyle(
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
          // Home Tab
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
          // Profile Tab
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
