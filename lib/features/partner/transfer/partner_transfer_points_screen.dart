import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/models/partner_transfer_models.dart';
import '../../../core/services/partner_api.dart';
import '../../../core/services/partner_session_manager.dart';
import '../../customer/qr_scanner/customer_qr_scanner.dart';
import '../home/partner_home_screen.dart';
import '../profile/partner_profile_screen.dart';

class PartnerTransferPointsScreen extends StatefulWidget {
  const PartnerTransferPointsScreen({
    super.key,
    this.partnerApi,
    this.sessionManager,
    this.initialBalance,
  });

  final PartnerApi? partnerApi;
  final PartnerSessionManager? sessionManager;
  final int? initialBalance;

  @override
  State<PartnerTransferPointsScreen> createState() =>
      _PartnerTransferPointsScreenState();
}

class _PartnerTransferPointsScreenState
    extends State<PartnerTransferPointsScreen> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _cardBorderBlue = Color(0xFFCBEBFF);
  static const _subtitleColor = Color(0xFF4A6B94);

  late final PartnerSessionManager _sessionManager;
  late final PartnerApi _partnerApi;

  final TextEditingController _pointsController = TextEditingController();

  int? _availableBalance;
  bool _isLoadingBalance = false;
  String? _balanceError;

  StaffQrRecipient? _resolvedRecipient;
  String? _scannedPayload;
  bool _isResolving = false;
  String? _resolutionError;

  String? _pointsError;

  bool _isSubmitting = false;
  String? _currentTransferIdempotencyKey;
  bool _isHandlingScan = false;

  @override
  void initState() {
    super.initState();
    _sessionManager = widget.sessionManager ?? PartnerSessionManager.instance;
    _partnerApi = widget.partnerApi ??
        PartnerApi(sessionManager: _sessionManager);

    _availableBalance = widget.initialBalance;
    _pointsController.addListener(_onPointsChanged);

    _loadAvailableBalance();
  }

  @override
  void dispose() {
    _pointsController.removeListener(_onPointsChanged);
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableBalance() async {
    if (!mounted) return;
    setState(() {
      _isLoadingBalance = true;
      _balanceError = null;
    });

    try {
      final balance = await _partnerApi.getAvailableBalance();
      if (!mounted) return;
      setState(() {
        _availableBalance = balance;
        _isLoadingBalance = false;
        _validatePoints(silent: true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
        _balanceError = e is PartnerApiException ? e.message : e.toString();
      });
    }
  }

  void _onPointsChanged() {
    // If the transfer amount changes, invalidate the idempotency key so that
    // a new logical transfer request receives its own unique idempotency key.
    _currentTransferIdempotencyKey = null;
    setState(() {
      _validatePoints(silent: true);
    });
  }

  bool _validatePoints({bool silent = false}) {
    final pointsText = _pointsController.text.trim();
    String? pError;

    if (pointsText.isNotEmpty) {
      final points = int.tryParse(pointsText);
      if (points == null || points <= 0) {
        pError = 'Points must be greater than zero';
      } else if (_availableBalance != null && points > _availableBalance!) {
        pError =
            'Insufficient points balance (available: $_availableBalance points)';
      }
    }

    if (!silent) {
      _pointsError = pError;
    } else {
      _pointsError = pError;
    }

    return pError == null && pointsText.isNotEmpty;
  }

  bool get _isValid {
    if (_resolvedRecipient == null || _scannedPayload == null) return false;
    final pointsText = _pointsController.text.trim();
    if (pointsText.isEmpty) return false;
    final points = int.tryParse(pointsText);
    if (points == null || points <= 0) return false;
    if (_availableBalance != null && points > _availableBalance!) return false;
    if (_isSubmitting || _isResolving) return false;
    return true;
  }

  void _clearRecipient() {
    setState(() {
      _resolvedRecipient = null;
      _scannedPayload = null;
      _resolutionError = null;
      _currentTransferIdempotencyKey = null;
    });
  }

  Future<void> _resolveStaffQr(String rawCode) async {
    final clean = rawCode.trim();
    if (clean.isEmpty) return;

    // Fast-path client validation for wrong QR types
    if (clean.contains('type=product') || clean.contains('type=invoice')) {
      setState(() {
        _resolvedRecipient = null;
        _scannedPayload = null;
        _resolutionError =
            "Inappropriate QR code type: Product and Invoice QR codes cannot be used for Staff point transfers.";
      });
      return;
    }

    setState(() {
      _isResolving = true;
      _resolutionError = null;
      _currentTransferIdempotencyKey = null;
    });

    try {
      final recipient = await _partnerApi.resolveStaffQr(codeData: clean);
      if (!mounted) return;
      setState(() {
        _resolvedRecipient = recipient;
        _scannedPayload = clean;
        _isResolving = false;
        _resolutionError = null;
      });
    } on PartnerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedRecipient = null;
        _scannedPayload = null;
        _isResolving = false;
        _resolutionError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvedRecipient = null;
        _scannedPayload = null;
        _isResolving = false;
        _resolutionError = 'Failed to resolve Staff QR code: ${e.toString()}';
      });
    }
  }

  Future<void> _handleScannedCode(String code) async {
    if (_isHandlingScan) return;
    _isHandlingScan = true;
    try {
      await _resolveStaffQr(code);
    } finally {
      _isHandlingScan = false;
    }
  }

  Future<void> _openQrScanner() async {
    String? capturedCode;
    await CustomerQrScannerSheet.show(
      context,
      mode: ScannerMode.transferPoints,
      onScanned: (code) {
        capturedCode = code;
      },
    );

    if (capturedCode != null && capturedCode!.trim().isNotEmpty) {
      await _handleScannedCode(capturedCode!.trim());
    }
  }

  void _showManualEntryDialog() {
    final tempController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Enter Staff ID',
          style: TextStyle(
            color: _royalBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Staff QR token to resolve the recipient. Staff ID alone without a valid QR token is not supported.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tempController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter Staff ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _cardBorderBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _royalBlue, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8A98A8),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = tempController.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                _resolveStaffQr(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getOrCreateIdempotencyKey() {
    _currentTransferIdempotencyKey ??=
        'trf_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
    return _currentTransferIdempotencyKey!;
  }

  Future<void> _handleTransfer() async {
    if (!_validatePoints(silent: false)) {
      setState(() {});
      return;
    }
    if (_resolvedRecipient == null || _scannedPayload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan a valid Staff QR code first.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    final points = int.parse(_pointsController.text.trim());
    await _showConfirmDialog(points);
  }

  Future<void> _showConfirmDialog(int amount) async {
    final recipient = _resolvedRecipient;
    final payload = _scannedPayload;
    if (recipient == null || payload == null) return;

    final recipientName = recipient.staffName;
    final recipientStaffId = recipient.staffId;
    final idempotencyKey = _getOrCreateIdempotencyKey();
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, color: _royalBlue, size: 24),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Confirm Transfer',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _royalBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmRow('Recipient', recipientName),
                  if (recipientStaffId != null)
                    _buildConfirmRow('Staff ID', recipientStaffId),
                  _buildConfirmRow('Points', '$amount Points', isBold: true),
                  if (_availableBalance != null) ...[
                    const Divider(height: 18),
                    _buildConfirmRow(
                        'Current Balance', '$_availableBalance Points'),
                    _buildConfirmRow(
                      'Balance After',
                      '${_availableBalance! - amount} Points',
                      color: const Color(0xFF2E7D32),
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF9A9A)),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF8A98A8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setDialogState(() {
                          _isSubmitting = true;
                          dialogError = null;
                        });
                        setState(() {
                          _isSubmitting = true;
                        });

                        try {
                          final response = await _partnerApi.transferPoints(
                            codeData: payload,
                            amount: amount,
                            idempotencyKey: idempotencyKey,
                          );

                          if (!mounted) return;
                          if (!dialogContext.mounted) return;

                          Navigator.of(dialogContext).pop();

                          setState(() {
                            _isSubmitting = false;
                            _availableBalance = response.senderBalance;
                            _pointsController.clear();
                            _pointsError = null;
                            _resolvedRecipient = null;
                            _scannedPayload = null;
                            _currentTransferIdempotencyKey = null;
                          });

                          _showSuccessFeedback(response, amount);
                          _loadAvailableBalance();
                        } on PartnerApiException catch (e) {
                          if (!mounted) return;
                          setDialogState(() {
                            _isSubmitting = false;
                            dialogError = e.message;
                          });
                          setState(() {
                            _isSubmitting = false;
                          });
                        } catch (e) {
                          if (!mounted) return;
                          setDialogState(() {
                            _isSubmitting = false;
                            dialogError =
                                'Transfer failed: ${e.toString()}';
                          });
                          setState(() {
                            _isSubmitting = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _royalBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF90CAF9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        dialogError != null ? 'Retry Transfer' : 'Confirm',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSuccessFeedback(PartnerTransferResponse response, int amount) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Successfully transferred $amount points to ${response.recipientName ?? "staff"}. New balance: ${response.senderBalance}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildConfirmRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? _royalBlue,
                fontSize: 15,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
                              const SizedBox(height: 18),
                              _buildTitleArea(),
                              const SizedBox(height: 18),
                              _buildTransferCard(context),
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
                    border: Border.all(color: _cardBorderBlue, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0755B5),
                        blurRadius: 10,
                        offset: Offset(0, 3),
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

  Widget _buildTitleArea() {
    return const Column(
      children: [
        Text(
          'Transfer Points',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royalBlue,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Transfer points to staff securely',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _royalBlue,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        SizedBox(height: 10),
        _AccentBars(),
      ],
    );
  }

  Widget _buildTransferCard(BuildContext context) {
    final hasRecipient = _resolvedRecipient != null;

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
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 50,
              child: CustomPaint(
                painter: _CardBottomWavePainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header with Icon and Explanatory Text
                  const Row(
                    children: [
                      _TransferIcon(),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer Points',
                              style: TextStyle(
                                color: _royalBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Scan the staff QR code to resolve the recipient and transfer points.',
                              style: TextStyle(
                                color: _subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Available Points Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorderBlue, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF0755C7),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Available Points',
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isLoadingBalance && _availableBalance == null)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _royalBlue,
                            ),
                          )
                        else if (_balanceError != null &&
                            _availableBalance == null)
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                size: 18, color: _royalBlue),
                            tooltip: 'Retry loading balance: $_balanceError',
                            onPressed: _loadAvailableBalance,
                          )
                        else
                          Text(
                            _availableBalance != null
                                ? _availableBalance.toString()
                                : '—',
                            style: const TextStyle(
                              color: _royalBlue,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Recipient Display or Selection Options
                  if (_isResolving) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _cardBorderBlue),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _royalBlue,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Resolving Staff QR code...',
                            style: TextStyle(
                              color: _royalBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasRecipient) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF90CAF9), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _royalBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Staff Recipient',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFFA5D6A7)),
                                      ),
                                      child: const Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _resolvedRecipient!.staffName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _royalBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_resolvedRecipient!.staffId != null)
                                  Text(
                                    'Staff ID: ${_resolvedRecipient!.staffId}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF4A6B94),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFFFF1725)),
                            tooltip: 'Clear Recipient',
                            onPressed: _clearRecipient,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Option A: Scan Staff QR Code Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openQrScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _royalBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        icon:
                            const Icon(Icons.qr_code_scanner_rounded, size: 22),
                        label: const Text(
                          'Scan Staff QR Code',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Option B: Enter Staff ID Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showManualEntryDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _royalBlue,
                          side: const BorderSide(color: _royalBlue, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.keyboard_outlined, size: 22),
                        label: const Text(
                          'Enter Staff ID',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_resolutionError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF5C2C7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFB02A37), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resolutionError!,
                              style: const TextStyle(
                                color: Color(0xFF842029),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _resolutionError = null;
                              });
                            },
                            child: const Icon(Icons.close,
                                color: Color(0xFF842029), size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Points Amount Input
                  const Text(
                    'Points to Transfer',
                    style: TextStyle(
                      color: _royalBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter points',
                      errorText: _pointsError,
                      prefixIcon: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFF0755C7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _cardBorderBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _royalBlue, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFDFF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Transfer Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isValid ? _handleTransfer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _royalBlue,
                        disabledBackgroundColor: const Color(0xFF90CAF9),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: _isValid ? 3 : 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Transfer Points',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
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
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

class _TransferIcon extends StatelessWidget {
  const _TransferIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD4F0FF),
      ),
      child: const Icon(
        Icons.compare_arrows_rounded,
        color: Color(0xFF0755C7),
        size: 28,
      ),
    );
  }
}

class _AccentBars extends StatelessWidget {
  const _AccentBars();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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

class _CardBottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = const Color(0xFFD0F0FF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.6,
        size.height * 0.6,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.9,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
