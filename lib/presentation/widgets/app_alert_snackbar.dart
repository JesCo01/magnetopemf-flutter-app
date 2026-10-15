import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../providers/app_alert_provider.dart';

SnackBar buildAppAlertSnackBar(BuildContext context, AppAlertEvent alert) {
  final palette = _paletteFor(alert.severity);

  return SnackBar(
    behavior: SnackBarBehavior.fixed,
    backgroundColor: Colors.transparent,
    elevation: 0,
    dismissDirection: DismissDirection.horizontal,
    duration: alert.persistent
        ? const Duration(seconds: 12)
        : const Duration(seconds: 5),
    padding: EdgeInsets.zero,
    content: Builder(
      builder: (snackContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.badge,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      palette.icon,
                      size: 16,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: palette.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    iconSize: 18,
                    color: palette.foreground,
                    onPressed: () {
                      ScaffoldMessenger.of(
                        snackContext,
                      ).hideCurrentSnackBar();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

_AlertPalette _paletteFor(AppAlertSeverity severity) {
  switch (severity) {
    case AppAlertSeverity.success:
      return const _AlertPalette(
        background: Color(0xFFF3FCF8),
        border: Color(0xFFB7E7CF),
        badge: Color(0x1A22C55E),
        foreground: AppColors.green500,
        icon: Icons.check_rounded,
      );
    case AppAlertSeverity.warning:
      return const _AlertPalette(
        background: Color(0xFFFFF8EE),
        border: Color(0xFFF6D7A8),
        badge: Color(0x1AF59E0B),
        foreground: Color(0xFFB45309),
        icon: Icons.battery_alert_rounded,
      );
    case AppAlertSeverity.critical:
      return const _AlertPalette(
        background: Color(0xFFFFF1F2),
        border: Color(0xFFFBC0C6),
        badge: Color(0x1AE11D48),
        foreground: Color(0xFFBE123C),
        icon: Icons.error_outline_rounded,
      );
    case AppAlertSeverity.info:
      return const _AlertPalette(
        background: Color(0xFFF3F8FF),
        border: Color(0xFFBBD3F7),
        badge: Color(0x1A3B82F6),
        foreground: AppColors.electricBlue,
        icon: Icons.bluetooth_searching_rounded,
      );
  }
}

class _AlertPalette {
  final Color background;
  final Color border;
  final Color badge;
  final Color foreground;
  final IconData icon;

  const _AlertPalette({
    required this.background,
    required this.border,
    required this.badge,
    required this.foreground,
    required this.icon,
  });
}
