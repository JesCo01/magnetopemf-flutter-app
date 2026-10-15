import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 30,
                offset: Offset(0, 10),
              )
            ]),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sliding Background Pill
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment(-1.0 + (currentIndex * (2.0 / 3.0)), 0),
              child: FractionallySizedBox(
                widthFactor: 0.25, // Maps to 1 out of 4 Expanded widgets
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.slate100.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            // Navigation Items
            Row(
              children: [
                Expanded(
                    child: _buildNavItem(
                        context, 0, Icons.dashboard_rounded, 'Panel', '/')),
                Expanded(
                    child: _buildNavItem(
                        context, 1, Icons.tune_rounded, 'Manual', '/manual')),
                Expanded(
                    child: _buildNavItem(context, 2, Icons.bluetooth_rounded,
                        'Equipos', '/devices')),
                Expanded(
                    child: _buildNavItem(context, 3, Icons.people_alt_rounded,
                        'Pacientes', '/config')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon,
      String label, String route) {
    final isActive = currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isActive) context.go(route);
      },
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'MaterialIcons',
                fontSize: 22,
                color: isActive ? AppColors.textMain : AppColors.textMuted,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isActive ? AppColors.textMain : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isActive ? AppColors.textMain : AppColors.textMuted,
              ),
              child: Text(label.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
