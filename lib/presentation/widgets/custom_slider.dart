import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final List<Color> activeColors;

  const CustomSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.activeColors,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: Colors
            .white, // Se usa un gradiente de fondo, el track activo es transparente o blanco
        inactiveTrackColor: AppColors.slate200,
        thumbColor: Colors.white,
        overlayColor: activeColors.first.withOpacity(0.2),
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gradient fill based on value
          LayoutBuilder(builder: (context, constraints) {
            final percentage = (safeValue - min) / (max - min);
            final fillWidth = constraints.maxWidth * percentage;
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 8,
                width: fillWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: activeColors),
                ),
              ),
            );
          }),
          Slider(
            value: safeValue,
            min: min,
            max: max,
            onChanged: onChanged,
            // Make the active track transparent so the gradient shows through
            activeColor: Colors.transparent,
          ),
        ],
      ),
    );
  }
}
