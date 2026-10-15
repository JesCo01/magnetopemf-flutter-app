import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class OscilloscopePainter extends CustomPainter {
  final double animationValue;
  final bool isRunning;
  final int hz;
  final int pwm;
  final int waveform;

  OscilloscopePainter({
    required this.animationValue,
    required this.isRunning,
    required this.hz,
    required this.pwm,
    required this.waveform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Fondo del osciloscopio (CRT Deep Black/Navy)
    final bgPaint = Paint()..color = const Color(0xFF050B12);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Retícula / Graticule Grid
    _drawGraticule(canvas, size);

    // 3. Cálculo de Parámetros Físicos
    final safeHz = max(1, hz);
    final periodSec = 1.0 / safeHz;
    final dutyRatio = (pwm / 100.0).clamp(0.05, 0.95);
    final timePerDivSec = _getTimePerDivSec(safeHz);
    final totalTimeSpanSec = timePerDivSec * 8.0; // 8 divisiones horizontales

    // Nivel 0V (GND) y Nivel +Vpeak (Vmax)
    final yGround = height * 0.78;
    final yPeak = height * 0.22;
    final deltaY = yGround - yPeak;

    // Desplazamiento temporal para simular barrido en tiempo real
    final phaseOffset = isRunning ? (animationValue * periodSec * 2.0) : 0.0;

    // 4. Muestreo de la función matemática real
    final path = Path();
    bool hasMoved = false;

    // Muestreo con paso fino para máxima nitidez
    for (double x = 0; x <= width; x += 1.2) {
      final t = (x / width) * totalTimeSpanSec;
      final tTotal = t + phaseOffset;
      final tCycle = tTotal % periodSec;

      final double v = _calcVoltage(tCycle, periodSec, dutyRatio, waveform);
      final double y = (yGround - (v * deltaY)).clamp(4.0, height - 4.0);

      if (!hasMoved) {
        path.moveTo(x, y);
        hasMoved = true;
      } else {
        path.lineTo(x, y);
      }
    }

    // 5. Trazo con Resplandor Fósforo (Phosphor Glow)
    if (isRunning) {
      final glowPaint = Paint()
        ..color = AppColors.neonTeal.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawPath(path, glowPaint);
    }

    // 6. Haz de electrones central (Sharp Beam)
    final beamPaint = Paint()
      ..color = isRunning ? const Color(0xFFE0F7FA) : const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRunning ? 1.8 : 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, beamPaint);
  }

  void _drawGraticule(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    const hDivisions = 8;
    const vDivisions = 6;

    final gridPaint = Paint()
      ..color = const Color(0xFF132B3B)
      ..strokeWidth = 0.8;

    final centerAxisPaint = Paint()
      ..color = const Color(0xFF1B3D54)
      ..strokeWidth = 1.0;

    final tickPaint = Paint()
      ..color = const Color(0xFF1B3D54)
      ..strokeWidth = 1.0;

    // Líneas verticales
    for (int i = 0; i <= hDivisions; i++) {
      final x = width * (i / hDivisions);
      final isCenter = (i == hDivisions ~/ 2);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, height),
        isCenter ? centerAxisPaint : gridPaint,
      );
    }

    // Líneas horizontales
    for (int j = 0; j <= vDivisions; j++) {
      final y = height * (j / vDivisions);
      final isCenter = (j == vDivisions ~/ 2);
      canvas.drawLine(
        Offset(0, y),
        Offset(width, y),
        isCenter ? centerAxisPaint : gridPaint,
      );
    }

    // Submarcas (Tick marks) en los ejes centrales
    final centerX = width / 2;
    final centerY = height / 2;

    // Ticks horizontales sobre el eje X central
    const subTicksX = hDivisions * 5;
    for (int k = 0; k <= subTicksX; k++) {
      final tx = width * (k / subTicksX);
      canvas.drawLine(
        Offset(tx, centerY - 2),
        Offset(tx, centerY + 2),
        tickPaint,
      );
    }

    // Ticks verticales sobre el eje Y central
    const subTicksY = vDivisions * 5;
    for (int m = 0; m <= subTicksY; m++) {
      final ty = height * (m / subTicksY);
      canvas.drawLine(
        Offset(centerX - 2, ty),
        Offset(centerX + 2, ty),
        tickPaint,
      );
    }
  }

  // --- MODELADO MATEMÁTICO REAL DE LA SEÑAL ESP32 / PEMF ---
  double _calcVoltage(double tCycle, double T, double duty, int wf) {
    switch (wf) {
      // 0: Cuadrada (SQUARE) / 4: PWM PURO
      case 0:
      case 4:
        final tOn = T * duty;
        if (tCycle < tOn) {
          // Fase ON: Frente de onda rápido con ligera respuesta inductiva
          final riseRatio = (tCycle / (tOn * 0.05)).clamp(0.0, 1.0);
          return 1.0 * riseRatio;
        } else {
          // Fase OFF: Pequeña oscilación de desenergización de la bobina (Flyback)
          final tOff = tCycle - tOn;
          final kickWindow = T * 0.04;
          if (tOff < kickWindow) {
            return -0.15 * (1.0 - (tOff / kickWindow));
          }
          return 0.0;
        }

      // 1: Triangular (Protocolo IGEA / Faldini)
      case 1:
        final tPeak = T * duty.clamp(0.15, 0.85);
        if (tCycle < tPeak) {
          return tCycle / tPeak;
        } else {
          return (1.0 - ((tCycle - tPeak) / (T - tPeak))).clamp(0.0, 1.0);
        }

      // 2: Trapezoidal (Protocolo Orthofix / EBI)
      case 2:
        final tActive = T * duty.clamp(0.20, 0.90);
        final tRise = tActive * 0.28;
        final tSustain = tActive * 0.44;
        final tFall = tActive * 0.28;

        if (tCycle < tRise) {
          return tCycle / tRise;
        } else if (tCycle < tRise + tSustain) {
          return 1.0;
        } else if (tCycle < tActive) {
          return 1.0 - ((tCycle - tRise - tSustain) / tFall);
        } else {
          return 0.0;
        }

      // 3: Burst (Ráfagas de micropulsos de 250 µs en ventana de 5 ms)
      case 3:
        const burstWindowSec = 0.005; // 5.0 ms
        if (tCycle < burstWindowSec) {
          const microPulsePeriod = 0.00025; // 250 µs
          final microT = tCycle % microPulsePeriod;
          return microT < (microPulsePeriod * 0.5) ? 1.0 : 0.0;
        } else {
          return 0.0;
        }

      default:
        final tOn = T * duty;
        return tCycle < tOn ? 1.0 : 0.0;
    }
  }

  double _getTimePerDivSec(int hz) {
    if (hz <= 20) return 0.010; // 10 ms/div
    if (hz <= 50) return 0.005; // 5 ms/div
    if (hz <= 80) return 0.0025; // 2.5 ms/div
    return 0.002; // 2 ms/div
  }

  @override
  bool shouldRepaint(covariant OscilloscopePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.hz != hz ||
        oldDelegate.pwm != pwm ||
        oldDelegate.waveform != waveform;
  }
}

class AnimatedWave extends StatefulWidget {
  final bool isRunning;
  final int hz;
  final int pwm;
  final int waveform;

  const AnimatedWave({
    super.key,
    required this.isRunning,
    required this.hz,
    required this.pwm,
    this.waveform = 0,
  });

  @override
  State<AnimatedWave> createState() => _AnimatedWaveState();
}

class _AnimatedWaveState extends State<AnimatedWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isRunning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTimebaseText(int hz) {
    if (hz <= 20) return '10ms/div';
    if (hz <= 50) return '5ms/div';
    if (hz <= 80) return '2.5ms/div';
    return '2ms/div';
  }

  String _getWaveformName(int wf) {
    switch (wf) {
      case 0:
        return 'SQUARE';
      case 1:
        return 'TRIANGULAR';
      case 2:
        return 'TRAPEZOIDAL';
      case 3:
        return 'BURST';
      case 4:
        return 'PWM PURO';
      default:
        return 'MANUAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timebaseText = _getTimebaseText(widget.hz);
    final waveName = _getWaveformName(widget.waveform);
    final dutyText = widget.waveform == 3 ? '5ms WIN' : '${widget.pwm}%';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050B12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF133246),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1800E5FF),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Stack(
          children: [
            // 1. Pantalla y Traza de Osciloscopio
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: OscilloscopePainter(
                      animationValue: _controller.value,
                      isRunning: widget.isRunning,
                      hz: widget.hz,
                      pwm: widget.pwm,
                      waveform: widget.waveform,
                    ),
                  );
                },
              ),
            ),

            // 2. OSD Superior (Estado RUN/STOP, Canal y Time/div)
            Positioned(
              top: 6,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isRunning
                              ? const Color(0xFF00FF88)
                              : const Color(0xFF64748B),
                          boxShadow: widget.isRunning
                              ? const [
                                  BoxShadow(
                                    color: Color(0xFF00FF88),
                                    blurRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isRunning ? 'RUN' : 'STOP',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: widget.isRunning
                              ? const Color(0xFF00FF88)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CH1 12V',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'T: $timebaseText',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // 3. OSD Inferior (Frecuencia, Modo y Duty/Ventana)
            Positioned(
              bottom: 6,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'f: ${widget.hz} Hz',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  Text(
                    '$waveName • $dutyText',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCBD5E1),
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
}
