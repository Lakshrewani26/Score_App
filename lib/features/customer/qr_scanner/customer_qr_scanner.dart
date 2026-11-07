import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/models/qr_scan_models.dart';
import '../../../core/services/customer_session_manager.dart';
import '../../../core/services/partner_session_manager.dart';
import '../../../core/services/qr_api.dart';

enum ScannerMode {
  scan,
  transferPoints,
}

class CustomerQrScannerSheet extends StatefulWidget {
  final ScannerMode mode;
  final ValueChanged<String>? onScanned;
  final ValueChanged<QrScanResult>? onScanSuccess;
  final QrScanApi? qrApi;
  final String? authToken;
  final bool? autoSubmit;

  const CustomerQrScannerSheet({
    super.key,
    this.mode = ScannerMode.scan,
    this.onScanned,
    this.onScanSuccess,
    this.qrApi,
    this.authToken,
    this.autoSubmit,
  });

  /// Helper static method to open the scanner modal bottom sheet
  static Future<dynamic> show(
    BuildContext context, {
    ScannerMode mode = ScannerMode.scan,
    ValueChanged<String>? onScanned,
    ValueChanged<QrScanResult>? onScanSuccess,
    QrScanApi? qrApi,
    String? authToken,
    bool? autoSubmit,
  }) {
    return showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => CustomerQrScannerSheet(
        mode: mode,
        onScanned: onScanned,
        onScanSuccess: onScanSuccess,
        qrApi: qrApi,
        authToken: authToken,
        autoSubmit: autoSubmit,
      ),
    );
  }

  @override
  State<CustomerQrScannerSheet> createState() => _CustomerQrScannerSheetState();
}

class _CustomerQrScannerSheetState extends State<CustomerQrScannerSheet> {
  static const _royalBlue = Color(0xFF083FA5);
  static const _darkNavy = Color(0xFF071D49);
  static const _skyBorder = Color(0xFFCBEBFF);

  late final MobileScannerController _scannerController;
  late final QrScanApi _api;

  bool _isScanned = false;
  bool _isProcessing = false;
  String? _processingStatus;

  QrScanResult? _scanSuccessResult;
  String? _errorMessage;
  int? _errorStatusCode;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _api = widget.qrApi ?? QrScanApi();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  bool _hasActiveSession() {
    if (widget.authToken != null && widget.authToken!.isNotEmpty) return true;
    if (CustomerSessionManager.instance.isAuthenticated) return true;
    if (PartnerSessionManager.instance.isAuthenticated) return true;
    return false;
  }

  bool _shouldAutoSubmit() {
    if (widget.mode == ScannerMode.transferPoints) return false;
    if (widget.autoSubmit != null) return widget.autoSubmit!;
    if (widget.qrApi != null || widget.onScanSuccess != null) return true;
    if (widget.onScanned == null && _hasActiveSession()) return true;
    return false;
  }

  void _resetScanner() {
    setState(() {
      _isScanned = false;
      _isProcessing = false;
      _processingStatus = null;
      _scanSuccessResult = null;
      _errorMessage = null;
      _errorStatusCode = null;
    });
    try {
      _scannerController.start();
    } catch (_) {
      // Ignored if scanner is already started
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned || _isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue ?? barcode.displayValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _handleCodeSubmission(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _handleCodeSubmission(String rawCode) async {
    if (_isProcessing) return;

    // Concurrency lock: mark scanned & stop camera to ignore further frames
    setState(() {
      _isScanned = true;
      _isProcessing = true;
      _processingStatus = 'Verifying QR code...';
      _errorMessage = null;
      _scanSuccessResult = null;
    });

    try {
      _scannerController.stop();
    } catch (_) {}

    // If transferPoints mode or autoSubmit is disabled:
    if (!_shouldAutoSubmit()) {
      setState(() {
        _isProcessing = false;
      });
      if (widget.onScanned != null) {
        widget.onScanned!(rawCode);
        Navigator.of(context).pop(rawCode);
      } else {
        _showQrDetectedDialog(rawCode);
      }
      return;
    }

    // Auto-submit to backend /api/v1/qr/scan
    final idempotencyKey =
        'scan_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';

    try {
      setState(() {
        _processingStatus = 'Redeeming loyalty points...';
      });

      final result = await _api.scanQrCode(
        codeData: rawCode,
        idempotencyKey: idempotencyKey,
        authToken: widget.authToken,
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _scanSuccessResult = result;
      });

      if (widget.onScanSuccess != null) {
        widget.onScanSuccess!(result);
      }
    } on QrScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
        _errorStatusCode = e.statusCode;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'An unexpected error occurred: $e';
        _errorStatusCode = 0;
      });
    }
  }

  void _showQrDetectedDialog(String qrValue) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'QR Code Detected',
          style: TextStyle(
            color: _royalBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SelectableText(
          qrValue,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: _royalBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Enter Code Manually',
          style: TextStyle(
            color: _royalBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter product code',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBEBFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _royalBlue, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
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
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                _handleCodeSubmission(code);
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
              'Submit',
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final contentWidth = math.min(screenWidth * 0.92, 420.0);
    final scannerSize = math.min(contentWidth * 0.72, 230.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom,
        ),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                  bottom: Radius.circular(24),
                ),
                border: Border.all(color: _skyBorder, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x290755B5),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                  bottom: Radius.circular(24),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 60,
                      child: CustomPaint(
                        painter: _SheetBottomWavePainter(),
                      ),
                    ),
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 20),
                            if (_scanSuccessResult != null)
                              _buildSuccessView(_scanSuccessResult!)
                            else if (_errorMessage != null)
                              _buildErrorView(_errorMessage!, _errorStatusCode)
                            else ...[
                              _buildScannerArea(scannerSize),
                              const SizedBox(height: 16),
                              if (_isProcessing)
                                Column(
                                  children: [
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: _royalBlue,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _processingStatus ?? 'Processing...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _royalBlue,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Text(
                                  'Position the QR code inside the frame',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _royalBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (widget.mode == ScannerMode.scan && !_isProcessing) ...[
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: () => _showManualEntryDialog(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _royalBlue,
                                    side: const BorderSide(color: Color(0xFF0755C7), width: 1.5),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.keyboard_outlined, size: 20),
                                  label: const Text(
                                    'Enter Code Manually',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Scan QR Code',
            style: TextStyle(
              color: _royalBlue,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Close',
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(_scanSuccessResult),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F7FF),
                  border: Border.all(color: const Color(0xFFD0E6FF), width: 1),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _royalBlue,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerArea(double scannerSize) {
    return Container(
      width: scannerSize,
      height: scannerSize,
      decoration: BoxDecoration(
        color: _darkNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00B0FF).withAlpha(153),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300B0FF),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return _buildScannerError(context, error);
                },
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _QrCornerBracketsPainter(),
              ),
            ),
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00B0FF),
                    strokeWidth: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(QrScanResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1416A34A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDCFCE7),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Points Awarded!',
            style: TextStyle(
              color: Color(0xFF14532D),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF166534),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '+${result.pointsAwarded} Points',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Updated Balance: ${result.newBalance} pts',
            style: const TextStyle(
              color: _royalBlue,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rule: ${result.ruleName} (v${result.ruleVersion})',
            style: const TextStyle(
              color: Color(0xFF4A6B94),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.isIdempotentReplay) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCD34D), width: 1),
              ),
              child: const Text(
                'Replay: Points already credited for this scan',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _royalBlue,
                    side: const BorderSide(color: Color(0xFF0755C7), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Scan Another',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(result),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message, int? statusCode) {
    final isDuplicate = statusCode == 409;
    final isExpired = statusCode == 400 && message.toLowerCase().contains('expired');
    final isInvalidType = statusCode == 400 &&
        (message.toLowerCase().contains('inappropriate') || message.toLowerCase().contains('type'));
    final isNotFound = statusCode == 404;

    String title = 'Scan Unsuccessful';
    IconData iconData = Icons.error_outline_rounded;
    Color iconColor = const Color(0xFFDC2626);
    Color bgColor = const Color(0xFFFEF2F2);
    Color borderColor = const Color(0xFFFECACA);

    if (isDuplicate) {
      title = 'Already Redeemed';
      iconData = Icons.history_rounded;
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
    } else if (isExpired) {
      title = 'QR Code Expired';
      iconData = Icons.timer_off_outlined;
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
    } else if (isInvalidType) {
      title = 'Invalid QR Type';
      iconData = Icons.block_flipped;
      iconColor = const Color(0xFFDC2626);
    } else if (isNotFound) {
      title = 'QR Code Not Found';
      iconData = Icons.search_off_rounded;
      iconColor = const Color(0xFFDC2626);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withAlpha(25),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 44,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: iconColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetScanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _royalBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerError(BuildContext context, MobileScannerException error) {
    String message = 'Camera permission is required to scan QR codes.';
    if (error.errorCode != MobileScannerErrorCode.permissionDenied) {
      message = 'Camera permission is required to scan QR codes.';
    }

    return Container(
      color: _darkNavy,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Color(0xFF9CDFFF),
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00B0FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const padding = 20.0;
    const cornerLength = 24.0;
    final left = padding;
    final top = padding;
    final right = size.width - padding;
    final bottom = size.height - padding;

    // Top-Left corner
    final pathTL = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top)
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(pathTL, paint);

    // Top-Right corner
    final pathTR = Path()
      ..moveTo(right - cornerLength, top)
      ..lineTo(right, top)
      ..lineTo(right, top + cornerLength);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left corner
    final pathBL = Path()
      ..moveTo(left, bottom - cornerLength)
      ..lineTo(left, bottom)
      ..lineTo(left + cornerLength, bottom);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right corner
    final pathBR = Path()
      ..moveTo(right - cornerLength, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right, bottom - cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SheetBottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint1 = Paint()
      ..color = const Color(0xFFDFF4FF).withAlpha(150)
      ..style = PaintingStyle.fill;

    final wavePaint2 = Paint()
      ..color = const Color(0xFFCBEBFF).withAlpha(120)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.65,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.8,
        size.width,
        size.height * 0.3,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(size.width * 0.35, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.2,
        size.width,
        size.height * 0.5,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..close();

    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
