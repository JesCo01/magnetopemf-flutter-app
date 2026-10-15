import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GlowingRing extends StatelessWidget {
  final bool isRunning;

  const GlowingRing({super.key, required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isRunning
            ? const LinearGradient(
                colors: [
                  Color(0x662DD4BF), // Neon Teal / 40%
                  Color(0x66A855F7), // Neon Purple / 40%
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
      ),
      child: isRunning
          ? TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.95, end: 1.05),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOutBack,
              builder: (context, val, child) {
                // Sixtye FPS pulse trick. A real implementation might use an Explicit Animation Controller
                return Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: AppColors.neonTeal.withOpacity(0.4),
                        blurRadius: 40 * val,
                        spreadRadius: 10 * val)
                  ]),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}
