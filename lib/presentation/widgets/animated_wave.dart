import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/constants/app_colors.dart';

class WavePainter extends CustomPainter {
  final double animationValue;
  final int pwm;

  WavePainter({required this.animationValue, required this.pwm});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.neonTeal, AppColors.electricBlue],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Simulación de onda PEMF (Pulso Electromagnético)
    const period = 80.0; // Ancho total del ciclo visual
    final offset = animationValue * period * 2; // Velocidad de desplazamiento

    // Asegurar que el ratio tenga límites visuales sanos
    final highRatio = (pwm / 100.0).clamp(0.05, 0.95);
    final highWidth = period * highRatio;
    final lowWidth = period * (1 - highRatio);

    path.moveTo(0, height);
    for (double x = -period * 2; x <= width + period * 2; x += period) {
      final curX = x - (offset % period);

      path.lineTo(curX, height); // Base

      // 1. Ataque inductivo (Spike hacia arriba)
      path.lineTo(curX + (highWidth * 0.1), height * 0.15);

      // 2. Mantenimiento (Sustain según PWM)
      path.lineTo(curX + highWidth, height * 0.15);

      // 3. Caída/Descarga inductiva (Decay curvo) simulando des-energización de bobina
      path.quadraticBezierTo(
          curX + highWidth + (lowWidth * 0.3), height, curX + period, height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class AnimatedWave extends StatefulWidget {
  final bool isRunning;
  final int hz;
  final int pwm;

  const AnimatedWave(
      {super.key,
      required this.isRunning,
      required this.hz,
      required this.pwm});

  @override
  State<AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<AnimatedWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _updateSpeed();
  }

  @override
  void didUpdateWidget(covariant AnimatedWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning || widget.hz != oldWidget.hz) {
      _updateSpeed();
    }
  }

  void _updateSpeed() {
    if (widget.isRunning) {
      // Mapear Hz a una duración de animación más rápida
      // A mayor Hz, la onda viaja mucho más veloz
      double animSpeedSeconds = max(0.1, 2.5 / sqrt(widget.hz));
      int durationMs = (animSpeedSeconds * 1000).toInt();
      _controller.duration = Duration(milliseconds: durationMs);
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isRunning ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 300),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(double.infinity, 35),
            painter: WavePainter(
              animationValue: _controller.value,
              pwm: widget.pwm,
            ),
          );
        },
      ),
    );
  }
}
