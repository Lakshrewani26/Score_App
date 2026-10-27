import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScannerMode {
  scan,
  transferPoints,
}

class CustomerQrScannerSheet extends StatefulWidget {
  final ScannerMode mode;
  final ValueChanged<String>? onScanned;

  const CustomerQrScannerSheet({
    super.key,
    this.mode = ScannerMode.scan,
    this.onScanned,
  });

  /// Helper static method to open the scanner modal bottom sheet
  static Future<String?> show(
    BuildContext context, {
    ScannerMode mode = ScannerMode.scan,
    ValueChanged<String>? onScanned,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(128),
      builder: (context) => CustomerQrScannerSheet(
        mode: mode,
        onScanned: onScanned,
      ),
    );
  }

  @override
  State<CustomerQrScannerSheet> createState() => _CustomerQrScannerSheetState();
}

class _CustomerQrScannerSheetState extends State<CustomerQrScannerSheet> {
  static const _royalBlue = Color(0xFF083FA5);

  late final MobileScannerController _scannerController;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue ?? barcode.displayValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        setState(() {
          _isScanned = true;
        });
        _scannerController.stop();
        if (widget.onScanned != null) {
          widget.onScanned!(rawValue);
          Navigator.of(context).pop(rawValue);
        } else {
          _showQrDetectedDialog(rawValue);
        }
        break;
      }
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
                if (widget.onScanned != null) {
                  widget.onScanned!(code);
                  Navigator.of(context).pop(code);
                } else {
                  _showQrDetectedDialog(code);
                }
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
                border: Border.all(color: const Color(0xFFCBEBFF), width: 1.5),
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
                            _buildScannerArea(scannerSize),
                            const SizedBox(height: 16),
                            const Text(
                              'Position the QR code inside the frame',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _royalBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.mode == ScannerMode.scan) ...[
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
              onTap: () => Navigator.of(context).pop(),
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
        color: const Color(0xFF071D49),
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
          ],
        ),
      ),
    );
  }

  Widget _buildScannerError(BuildContext context, MobileScannerException error) {
    String message = 'Camera permission is required to scan QR codes.';
    if (error.errorCode != MobileScannerErrorCode.permissionDenied) {
      message = 'Camera permission is required to scan QR codes.';
    }

    return Container(
      color: const Color(0xFF071D49),
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
    const left = padding;
    const top = padding;
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
