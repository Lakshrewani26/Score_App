import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScoreBackgroundVariant { standard, welcome }

class ScoreBrandedBackground extends StatelessWidget {
  const ScoreBrandedBackground({
    super.key,
    this.child,
    this.variant = ScoreBackgroundVariant.standard,
  });

  final Widget? child;
  final ScoreBackgroundVariant variant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: ScoreBrandedBackgroundPainter(variant: variant)),
        if (child != null) child!,
      ],
    );
  }
}

class ScoreBrandedBackgroundPainter extends CustomPainter {
  const ScoreBrandedBackgroundPainter({
    this.variant = ScoreBackgroundVariant.standard,
    this.paintGradient = true,
  });

  final ScoreBackgroundVariant variant;
  final bool paintGradient;

  static const _blue = Color(0xFF75BFF2);
  static const _red = Color(0xFFE51B24);

  bool get _isWelcome => variant == ScoreBackgroundVariant.welcome;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintGradient) {
      final bounds = Offset.zero & size;
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEAF6FF),
              Color(0xFFF8FCFF),
              Color(0xFFF0F8FF),
            ],
            stops: [0, 0.52, 1],
          ).createShader(bounds),
      );
    }

    _paintBlueprintPattern(canvas, size);
    if (_isWelcome) {
      _paintTopAccent(canvas, size);
      _paintDetailedMechanics(canvas, size);
    }
  }

  void _paintBlueprintPattern(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _blue.withValues(alpha: _isWelcome ? 0.08 : 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _isWelcome ? 0.9 : 0.8;
    final radius = size.width * (_isWelcome ? 0.046 : 0.035);

    for (final center in [
      Offset(size.width * 0.015, size.height * 0.23),
      Offset(size.width * 0.985, size.height * 0.34),
      Offset(size.width * 0.015, size.height * 0.57),
      Offset(size.width * 0.985, size.height * 0.59),
    ]) {
      canvas.drawCircle(center, radius, line);
      canvas.drawCircle(center, radius * 0.56, line);
      canvas.drawCircle(center, radius * 0.2, line);

      final spokeCount = _isWelcome ? 12 : 8;
      for (var spoke = 0; spoke < spokeCount; spoke++) {
        final angle = spoke * math.pi * 2 / spokeCount;
        final start = center +
            Offset(
              math.cos(angle) * radius * 0.67,
              math.sin(angle) * radius * 0.67,
            );
        final end = center +
            Offset(
              math.cos(angle) * radius * 0.92,
              math.sin(angle) * radius * 0.92,
            );
        canvas.drawLine(start, end, line);
      }
    }

    final waveCount = _isWelcome ? 5 : 2;
    for (var index = 0; index < waveCount; index++) {
      final y = size.height * (0.20 + index * 0.11);
      final path = Path()
        ..moveTo(size.width * 0.005, y)
        ..cubicTo(
          size.width * 0.06,
          y - 8,
          size.width * 0.10,
          y + 8,
          size.width * 0.16,
          y,
        );
      canvas.drawPath(path, line);
    }

    final rightEdge = Path()
      ..moveTo(size.width * 0.995, size.height * 0.19)
      ..cubicTo(
        size.width * 0.94,
        size.height * 0.195,
        size.width * 0.94,
        size.height * 0.22,
        size.width * 0.985,
        size.height * 0.23,
      )
      ..cubicTo(
        size.width * 0.95,
        size.height * 0.245,
        size.width * 0.95,
        size.height * 0.27,
        size.width * 0.995,
        size.height * 0.28,
      );
    canvas.drawPath(rightEdge, line);
  }

  void _paintDetailedMechanics(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _blue.withValues(alpha: 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _paintBrakeDisc(
      canvas,
      Offset(size.width * 0.015, size.height * 0.16),
      size.width * 0.12,
      line,
    );
    _paintBrakeDisc(
      canvas,
      Offset(size.width * 0.99, size.height * 0.24),
      size.width * 0.11,
      line,
    );
    _paintSpring(
      canvas,
      Offset(size.width * 0.015, size.height * 0.39),
      Offset(size.width * 0.14, size.height * 0.47),
      size.width * 0.015,
      line,
    );
    _paintEngine(
      canvas,
      Offset(size.width * 0.97, size.height * 0.53),
      size.width * 0.14,
      line,
    );
  }

  void _paintBrakeDisc(Canvas canvas, Offset center, double radius, Paint line) {
    canvas.drawCircle(center, radius, line);
    canvas.drawCircle(center, radius * 0.88, line);
    canvas.drawCircle(center, radius * 0.64, line);
    canvas.drawCircle(center, radius * 0.30, line);

    for (var hole = 0; hole < 12; hole++) {
      final angle = hole * math.pi / 6;
      final point = center +
          Offset(
            math.cos(angle) * radius * 0.75,
            math.sin(angle) * radius * 0.75,
          );
      canvas.drawCircle(point, radius * 0.035, line);
    }

    for (var spoke = 0; spoke < 6; spoke++) {
      final angle = spoke * math.pi / 3;
      canvas.drawLine(
        center +
            Offset(
              math.cos(angle) * radius * 0.31,
              math.sin(angle) * radius * 0.31,
            ),
        center +
            Offset(
              math.cos(angle + 0.18) * radius * 0.62,
              math.sin(angle + 0.18) * radius * 0.62,
            ),
        line,
      );
    }
  }

  void _paintSpring(
    Canvas canvas,
    Offset start,
    Offset end,
    double amplitude,
    Paint line,
  ) {
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    final path = Path()..moveTo(start.dx, start.dy);
    const turns = 9;
    for (var turn = 0; turn < turns; turn++) {
      final progress = (turn + 0.5) / turns;
      final direction = turn.isEven ? 1.0 : -1.0;
      final point = start +
          delta * progress +
          normal * amplitude * direction;
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(end.dx, end.dy);
    canvas.drawPath(path, line);
    canvas.drawLine(start - normal * amplitude, start + normal * amplitude, line);
    canvas.drawLine(end - normal * amplitude, end + normal * amplitude, line);
  }

  void _paintEngine(Canvas canvas, Offset center, double width, Paint line) {
    final bounds = Rect.fromCenter(
      center: center,
      width: width,
      height: width * 0.72,
    );
    final casing = Path()
      ..moveTo(bounds.left + width * 0.1, bounds.top)
      ..lineTo(bounds.right - width * 0.16, bounds.top + width * 0.04)
      ..lineTo(bounds.right, bounds.top + width * 0.22)
      ..lineTo(bounds.right - width * 0.06, bounds.bottom - width * 0.08)
      ..lineTo(bounds.left + width * 0.18, bounds.bottom)
      ..lineTo(bounds.left, center.dy)
      ..close();
    canvas.drawPath(casing, line);
    canvas.drawCircle(center, width * 0.19, line);
    canvas.drawCircle(center, width * 0.11, line);
    canvas.drawCircle(
      Offset(bounds.left + width * 0.18, bounds.top + width * 0.17),
      width * 0.055,
      line,
    );
    canvas.drawCircle(
      Offset(bounds.right - width * 0.17, bounds.bottom - width * 0.17),
      width * 0.045,
      line,
    );
  }

  void _paintTopAccent(Canvas canvas, Size size) {
    final blueBand = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.53, 0)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.024,
        0,
        size.height * 0.063,
      )
      ..close();
    canvas.drawPath(blueBand, Paint()..color = const Color(0xFF0755B8));

    final whiteBand = Path()
      ..moveTo(0, size.height * 0.039)
      ..quadraticBezierTo(
        size.width * 0.27,
        size.height * 0.011,
        size.width * 0.49,
        0,
      )
      ..lineTo(size.width * 0.535, 0)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.023,
        0,
        size.height * 0.049,
      )
      ..close();
    canvas.drawPath(whiteBand, Paint()..color = Colors.white);

    final redBand = Path()
      ..moveTo(0, size.height * 0.049)
      ..quadraticBezierTo(
        size.width * 0.27,
        size.height * 0.013,
        size.width * 0.49,
        0,
      )
      ..lineTo(size.width * 0.54, 0)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.027,
        0,
        size.height * 0.057,
      )
      ..close();
    canvas.drawPath(redBand, Paint()..color = _red);
  }

  @override
  bool shouldRepaint(covariant ScoreBrandedBackgroundPainter oldDelegate) =>
      variant != oldDelegate.variant ||
      paintGradient != oldDelegate.paintGradient;
}
