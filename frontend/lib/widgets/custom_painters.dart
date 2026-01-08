import 'package:flutter/material.dart';
import 'dart:math' as math;

class CircularGaugePainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final Color activeColor;
  final Color inactiveColor;

  CircularGaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final sweepAngle = 270.0; // 270 degrees arc (updated from 240)
    final startAngle = (270 - sweepAngle / 2) * math.pi / 180;

    // Draw background arc
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * math.pi / 180,
      false,
      bgPaint,
    );

    // Draw active arc with gradient effect
    final progress = (value - minValue) / (maxValue - minValue);
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress * math.pi / 180,
      false,
      activePaint,
    );

    // Draw glow effect
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress * math.pi / 180,
      false,
      glowPaint,
    );

    // Draw scale labels
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final scaleValues = [minValue, maxValue * 0.25, maxValue * 0.5, maxValue * 0.75, maxValue];
    final scalePositions = [0.0, 0.25, 0.5, 0.75, 1.0];

    for (int i = 0; i < scaleValues.length; i++) {
      final angle = startAngle + (sweepAngle * scalePositions[i] * math.pi / 180);
      final labelRadius = radius + 15;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: scaleValues[i].toInt().toString(),
        style: TextStyle(
          color: const Color(0xFF737373).withOpacity(0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(CircularGaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class WaterTankPainter extends CustomPainter {
  final double percentage;
  final double wavePhase;

  WaterTankPainter({required this.percentage, this.wavePhase = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final tankWidth = size.width * 0.5;
    final tankHeight = size.height;
    final tankLeft = (size.width - tankWidth) / 2;

    // Draw tank outline with glass effect
    final outlinePath = Path()
      ..moveTo(tankLeft, 20)
      ..lineTo(tankLeft, tankHeight - 20)
      ..quadraticBezierTo(
        tankLeft,
        tankHeight,
        tankLeft + 20,
        tankHeight,
      )
      ..lineTo(tankLeft + tankWidth - 20, tankHeight)
      ..quadraticBezierTo(
        tankLeft + tankWidth,
        tankHeight,
        tankLeft + tankWidth,
        tankHeight - 20,
      )
      ..lineTo(tankLeft + tankWidth, 20)
      ..quadraticBezierTo(
        tankLeft + tankWidth,
        0,
        tankLeft + tankWidth - 20,
        0,
      )
      ..lineTo(tankLeft + 20, 0)
      ..quadraticBezierTo(
        tankLeft,
        0,
        tankLeft,
        20,
      )
      ..close();

    final outlinePaint = Paint()
      ..color = const Color(0xFF3D3D3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(outlinePath, outlinePaint);

    // Draw water level with wave
    final waterHeight = (tankHeight - 40) * (percentage / 100);
    final waterTop = tankHeight - 20 - waterHeight;

    // Create wave path
    final wavePath = Path();
    wavePath.moveTo(tankLeft + 2, waterTop);
    
    // Wave effect
    const waveCount = 3;
    final waveWidth = (tankWidth - 4) / waveCount;
    for (int i = 0; i < waveCount; i++) {
      final x1 = tankLeft + 2 + (i * waveWidth);
      final x2 = x1 + waveWidth / 2;
      final x3 = x1 + waveWidth;
      final phase = wavePhase + (i * math.pi / 4);
      final waveHeight = 4 * math.sin(phase);
      
      wavePath.quadraticBezierTo(
        x2,
        waterTop + waveHeight,
        x3,
        waterTop,
      );
    }
    
    wavePath.lineTo(tankLeft + tankWidth - 2, waterTop);
    wavePath.lineTo(tankLeft + tankWidth - 2, tankHeight - 20);
    wavePath.quadraticBezierTo(
      tankLeft + tankWidth - 2,
      tankHeight - 2,
      tankLeft + tankWidth - 20,
      tankHeight - 2,
    );
    wavePath.lineTo(tankLeft + 20, tankHeight - 2);
    wavePath.quadraticBezierTo(
      tankLeft + 2,
      tankHeight - 2,
      tankLeft + 2,
      tankHeight - 20,
    );
    wavePath.close();

    // Color based on percentage
    Color waterColor;
    if (percentage >= 70) {
      waterColor = const Color(0xFF4AB08B);
    } else if (percentage >= 30) {
      waterColor = const Color(0xFFE8A54C);
    } else {
      waterColor = const Color(0xFFD84040);
    }

    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          waterColor.withOpacity(0.6),
          waterColor.withOpacity(0.3),
        ],
      ).createShader(Rect.fromLTWH(tankLeft, waterTop, tankWidth, waterHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(wavePath, waterPaint);

    // Draw glow effect
    final glowPaint = Paint()
      ..color = waterColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(wavePath, glowPaint);

    // Draw scale marks
    final markPaint = Paint()
      ..color = const Color(0xFF3D3D3D)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = 20 + (tankHeight - 40) * i / 4;
      canvas.drawLine(
        Offset(tankLeft + tankWidth + 4, y),
        Offset(tankLeft + tankWidth + 12, y),
        markPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaterTankPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.wavePhase != wavePhase;
  }
}
