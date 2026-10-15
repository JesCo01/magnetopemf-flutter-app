import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../providers/app_alert_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/block_ui_helper.dart';
import '../widgets/patient_selection_sheet.dart';

class ManualScreen extends ConsumerWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final bleState = ref.watch(bleProvider);
    final patientState = ref.watch(patientProvider);
    final isRunning = dashboardState.isRunning;
    final isBusy = dashboardState.isBusy;
    final isPaused = dashboardState.isPaused;
    final isLockedForLiveEdit = isRunning && !isPaused;
    final actionLabel = isBusy
        ? 'ENVIANDO...'
        : isPaused
            ? 'ACTUALIZAR TRATAMIENTO'
            : isLockedForLiveEdit
                ? 'PAUSA DESDE PANEL'
                : 'INICIAR TRATAMIENTO';
    final actionIcon = isBusy
        ? Icons.hourglass_top_rounded
        : isPaused
            ? Icons.sync_rounded
            : isLockedForLiveEdit
                ? Icons.pause_circle_outline_rounded
                : Icons.send_rounded;
    final actionColors = isLockedForLiveEdit
        ? const [Color(0xFF94A3B8), Color(0xFF64748B)]
        : isPaused
            ? const [AppColors.electricBlue, AppColors.neonTeal]
            : const [Color(0xFF111827), AppColors.textMain];
    final actionShadowColor = isLockedForLiveEdit
        ? const Color(0x1464748B)
        : isPaused
            ? AppColors.electricBlue.withOpacity(0.24)
            : AppColors.textMain.withOpacity(0.20);

    void showPauseRequiredAlert() {
      ref.read(appAlertProvider.notifier).warning(
            'Pausa requerida',
            'Pausa la terapia desde Panel para modificar frecuencia o intensidad.',
          );
    }

    Future<void> showMissingConnectionDialog() async {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.infoReverse,
        animType: AnimType.bottomSlide,
        headerAnimationLoop: false,
        title: 'Sin conexion',
        desc:
            'Debes conectar y emparejar un dispositivo antes de iniciar la terapia manual.',
        btnOkOnPress: () {},
        btnOkText: 'Entendido',
        btnOkColor: AppColors.electricBlue,
      ).show();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 58, 20, 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderStatus(
            title: 'Terapia Manual',
            subtitle: isPaused
                ? 'Sesion pausada lista para actualizar'
                : 'Ajuste de parametros',
            isConnected: bleState.isProtocolReady,
          ),
          _PremiumSliderCard(
            label: 'FRECUENCIA',
            value: dashboardState.manualHz,
            unit: 'Hz',
            min: 10,
            max: 100,
            icon: Icons.graphic_eq_rounded,
            iconColor: AppColors.neonTeal,
            gradientColors: const [
              AppColors.neonTeal,
              AppColors.electricBlue,
            ],
            isBusy: isBusy,
            isDimmed: isLockedForLiveEdit,
            onDecrease: () {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(
                hz: (dashboardState.manualHz - 1).clamp(10, 100),
              );
            },
            onIncrease: () {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(
                hz: (dashboardState.manualHz + 1).clamp(10, 100),
              );
            },
            onChanged: (value) {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(hz: value.toInt());
            },
          ),
          const SizedBox(height: 14),
          _PremiumSliderCard(
            label: 'CICLO DE TRABAJO PWM',
            value: dashboardState.manualPwm.clamp(10, 90),
            unit: '%',
            min: 10,
            max: 90,
            icon: Icons.bolt_rounded,
            iconColor: AppColors.electricBlue,
            gradientColors: const [
              AppColors.electricBlue,
              AppColors.neonPurple,
            ],
            isBusy: isBusy,
            isDimmed: isLockedForLiveEdit,
            onDecrease: () {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(
                pwm: (dashboardState.manualPwm - 1).clamp(10, 90),
              );
            },
            onIncrease: () {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(
                pwm: (dashboardState.manualPwm + 1).clamp(10, 90),
              );
            },
            onChanged: (value) {
              if (isBusy) return;
              if (isLockedForLiveEdit) {
                showPauseRequiredAlert();
                return;
              }
              notifier.updateParams(pwm: value.toInt());
            },
          ),
          const SizedBox(height: 14),
          _PremiumSliderCard(
            label: 'TIEMPO TOTAL',
            value: dashboardState.timeMinutes,
            unit: 'min',
            min: 1,
            max: 10,
            icon: Icons.schedule_rounded,
            iconColor: AppColors.brand,
            gradientColors: const [
              AppColors.brand,
              Color(0xFFF59E0B),
            ],
            isBusy: isBusy,
            isDimmed: isRunning,
            onDecrease: () {
              if (isBusy) return;
              if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                return;
              }
              notifier.updateParams(
                timeMinutes: (dashboardState.timeMinutes - 1).clamp(1, 10),
              );
            },
            onIncrease: () {
              if (isBusy) return;
              if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                return;
              }
              notifier.updateParams(
                timeMinutes: (dashboardState.timeMinutes + 1).clamp(1, 10),
              );
            },
            onChanged: (value) {
              if (isBusy) return;
              if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                return;
              }
              notifier.updateParams(timeMinutes: value.toInt());
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: _ManualActionButton(
              label: actionLabel,
              icon: actionIcon,
              colors: actionColors,
              shadowColor: actionShadowColor,
              enabled: !isBusy,
              onPressed: isBusy
                  ? null
                  : () async {
                      if (isLockedForLiveEdit) {
                        showPauseRequiredAlert();
                        return;
                      }

                      if (!bleState.isProtocolReady) {
                        await showMissingConnectionDialog();
                        return;
                      }

                      if (isPaused) {
                        final updated =
                            await notifier.updateTreatmentAndResume();
                        if (updated && context.mounted) {
                          context.go('/');
                        }
                        return;
                      }

                      if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                        return;
                      }

                      if (patientState.activePatient == null) {
                        showPatientSelectionBottomSheet(context, ref, () async {
                          final started = await notifier.startTherapy();
                          if (started && context.mounted) {
                            context.go('/');
                          }
                        });
                      } else {
                        final started = await notifier.startTherapy();
                        if (started && context.mounted) {
                          context.go('/');
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isConnected;

  const _HeaderStatus({
    required this.title,
    required this.subtitle,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textMain,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isConnected ? AppColors.green50 : AppColors.brandLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isConnected
                    ? AppColors.green500.withOpacity(0.12)
                    : AppColors.brandDark.withOpacity(0.10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? AppColors.green500 : AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'CONECTADO' : 'SIN ENLACE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color:
                        isConnected ? AppColors.green500 : AppColors.brandDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullWidthTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 42.0;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    return Rect.fromLTWH(offset.dx, trackTop, parentBox.size.width, trackHeight);
  }
}

class _PremiumSliderCard extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final bool isBusy;
  final bool isDimmed;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<double> onChanged;

  const _PremiumSliderCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.isBusy,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
    this.isDimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final percent = max == min ? 0.0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDimmed ? 0.62 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.slate100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate100),
                  ),
                  child: Icon(icon, size: 19, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMuted,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDimmed
                              ? AppColors.slate400
                              : AppColors.textMain,
                          letterSpacing: -0.8,
                        ),
                      ),
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: isBusy ? null : onDecrease,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.slate100.withOpacity(0.86),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.slate200.withOpacity(0.70),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0AFFFFFF),
                                  offset: Offset(0, 1),
                                ),
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const knobSize = 22.0;
                              final trackWidth = constraints.maxWidth;
                              final knobLeft = (trackWidth - knobSize) * percent;
                              final fillWidth = (knobLeft + knobSize).clamp(18.0, trackWidth);
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      height: 18,
                                      width: fillWidth,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        gradient: LinearGradient(
                                          colors: gradientColors,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: gradientColors.last.withOpacity(
                                                isDimmed ? 0.10 : 0.22),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                            spreadRadius: -5,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: knobLeft,
                                    child: Container(
                                      width: knobSize,
                                      height: knobSize,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(
                                            isDimmed ? 0.82 : 0.98),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x20000000),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 4,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppColors.slate300,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          IgnorePointer(
                            ignoring: isBusy,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 42,
                                activeTrackColor: Colors.transparent,
                                inactiveTrackColor: Colors.transparent,
                                overlayColor: Colors.transparent,
                                thumbColor: Colors.transparent,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 0),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 0),
                                trackShape: const _FullWidthTrackShape(),
                              ),
                              child: Slider(
                                value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
                                min: min.toDouble(),
                                max: max.toDouble(),
                                onChanged: onChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: isBusy ? null : onIncrease,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: isEnabled ? 1 : 0.60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: AppColors.slate200.withOpacity(0.24),
          highlightColor: AppColors.slate200.withOpacity(0.16),
          child: Ink(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isEnabled
                    ? const [Colors.white, AppColors.slate50]
                    : [
                        AppColors.slate100,
                        AppColors.slate100.withOpacity(0.94)
                      ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isEnabled
                    ? AppColors.slate200.withOpacity(0.85)
                    : AppColors.slate100,
              ),
              boxShadow: isEnabled
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                        spreadRadius: -5,
                      ),
                      BoxShadow(
                        color: Color(0x80FFFFFF),
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [],
            ),
            child: Icon(
              icon,
              size: 18,
              color: isEnabled ? AppColors.textMain : AppColors.slate300,
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color shadowColor;
  final bool enabled;
  final VoidCallback? onPressed;

  const _ManualActionButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.shadowColor,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.74,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.12),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
