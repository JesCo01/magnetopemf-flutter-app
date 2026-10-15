import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/models/preset.dart' as app_preset;
import '../../core/constants/app_colors.dart';
import '../widgets/circular_timer.dart';
import '../widgets/animated_wave.dart';
import '../widgets/block_ui_helper.dart';
import '../widgets/header_dropdown.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../widgets/patient_selection_sheet.dart';
import '../providers/ble_provider.dart';
import '../providers/patient_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final bleState = ref.watch(bleProvider);
    final patientState = ref.watch(patientProvider);

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: HeaderDropdown(),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildNeonTimerSection(dashboardState, notifier, bleState,
                      patientState, context, ref),
                  _buildLiveMonitorSection(dashboardState),
                  _buildQuickTreatmentsSection(dashboardState, notifier,
                      bleState, patientState, context, ref),
                  const SizedBox(height: 100), // Spacing for bottom nav bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeonTimerSection(
      DashboardState dashboardState,
      DashboardNotifier notifier,
      BleState bleState,
      PatientState patientState,
      BuildContext context,
      WidgetRef ref) {
    final progress = dashboardState.totalSeconds == 0
        ? 0.0
        : dashboardState.currentSeconds / dashboardState.totalSeconds;
    final mins = dashboardState.currentSeconds ~/ 60;
    final secs = dashboardState.currentSeconds % 60;
    final timeString = '$mins:${secs.toString().padLeft(2, '0')}';
    final activePreset = dashboardState.presetName;

    return Column(children: [
      // Padding removed in favor of less space
      const SizedBox(height: 32),
      // Circular Timer section
      Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: dashboardState.isRunning ? 0.3 : 0.0,
            child: SizedBox(
              width: 230,
              height: 230,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: AppColors.brand.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
          ),
          // Inner container
          Container(
            width: 230,
            height: 230,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0x05000000), blurRadius: 10)
              ],
              border: Border.all(color: AppColors.slate50),
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: CircularTimerPainter(
                      progress: progress,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(timeString,
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textMain,
                              height: 1.0,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.brand.withOpacity(0.2)),
                        ),
                        child: Text(
                            activePreset.isEmpty
                                ? 'Ajuste Manual'
                                : activePreset.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onDoubleTap: () {
                          if (dashboardState.isBusy) return;
                          if (dashboardState.isRunning) {
                            notifier.stopTherapy();
                          }
                        },
                        onTap: () async {
                          if (dashboardState.isBusy) return;
                          if (dashboardState.isRunning) {
                            await notifier.toggleTherapy();
                            return;
                          }
                          if (!bleState.isProtocolReady) {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.infoReverse,
                              animType: AnimType.bottomSlide,
                              headerAnimationLoop: false,
                              title: 'Sin conexión',
                              desc:
                                  'Debes conectar y emparejar un dispositivo antes de iniciar.',
                              btnOkOnPress: () {},
                              btnOkText: 'Entendido',
                              btnOkColor: AppColors.electricBlue,
                            ).show();
                            return;
                          }
                          if (patientState.activePatient == null) {
                            showPatientSelectionBottomSheet(context, ref,
                                () async {
                              await notifier.toggleTherapy();
                            });
                          } else {
                            await notifier.toggleTherapy();
                          }
                        },
                        child: Opacity(
                          opacity: dashboardState.isBusy ? 0.65 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: dashboardState.isRunning
                                  ? dashboardState.isPaused
                                      ? AppColors.brand.withOpacity(0.1)
                                      : Colors.orangeAccent.withOpacity(0.1)
                                  : AppColors.brand.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: dashboardState.isRunning
                                      ? dashboardState.isPaused
                                          ? AppColors.brand
                                          : Colors.orangeAccent
                                      : AppColors.brand,
                                  width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    dashboardState.isBusy
                                        ? Icons.hourglass_top_rounded
                                        : dashboardState.isRunning
                                            ? dashboardState.isPaused
                                                ? Icons.play_arrow_rounded
                                                : Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                    size: 14,
                                    color: dashboardState.isRunning
                                        ? dashboardState.isPaused
                                            ? AppColors.brand
                                            : Colors.orangeAccent
                                        : AppColors.brand),
                                const SizedBox(width: 6),
                                Text(
                                  dashboardState.isBusy
                                      ? 'ENVIANDO'
                                      : dashboardState.isRunning
                                          ? dashboardState.isPaused
                                              ? 'REANUDAR'
                                              : 'PAUSAR'
                                          : 'INICIAR',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                      fontSize: 9,
                                      color: dashboardState.isRunning
                                          ? dashboardState.isPaused
                                              ? AppColors.brand
                                              : Colors.orangeAccent
                                          : AppColors.brand),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (dashboardState.isRunning)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Doble toque para detener',
                              style: TextStyle(
                                  fontSize: 8, color: AppColors.textMuted)),
                        )
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildLiveMonitorSection(DashboardState dashboardState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate100),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.query_stats_rounded,
                        size: 14, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text('MONITOR',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: AppColors.textMuted)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dashboardState.isRunning
                        ? dashboardState.isPaused
                            ? Colors.orangeAccent.withOpacity(0.1)
                            : AppColors.neonTeal.withOpacity(0.1)
                        : AppColors.slate100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          dashboardState.isRunning
                              ? dashboardState.isPaused
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.monitor_heart_rounded
                              : Icons.monitor_heart_rounded,
                          size: 10,
                          color: dashboardState.isRunning
                              ? dashboardState.isPaused
                                  ? Colors.orangeAccent
                                  : AppColors.neonTeal
                              : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                          dashboardState.isRunning
                              ? (dashboardState.isPaused
                                  ? 'PAUSADO'
                                  : 'EMITIENDO')
                              : 'STANDBY',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: dashboardState.isRunning
                                  ? dashboardState.isPaused
                                      ? Colors.orangeAccent
                                      : AppColors.neonTeal
                                  : AppColors.textMuted)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),

            // Wave constrained properly
            ClipRect(
              child: SizedBox(
                height: 32, // More compact wave
                width: double.infinity,
                child: AnimatedWave(
                  isRunning:
                      dashboardState.isRunning && !dashboardState.isPaused,
                  hz: dashboardState.hz,
                  pwm: dashboardState.pwm,
                ),
              ),
            ),

            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FRECUENCIA',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppColors.textMuted)),
                      RichText(
                          text: TextSpan(children: [
                        TextSpan(
                            text: '${dashboardState.hz}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain)),
                        const TextSpan(
                            text: ' Hz',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted)),
                      ]))
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          dashboardState.waveform == 3
                              ? 'VENTANA DE RÁFAGA'
                              : 'CICLO PWM',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: AppColors.textMuted)),
                      RichText(
                          text: TextSpan(children: [
                        TextSpan(
                            text: dashboardState.waveform == 3
                                ? '5'
                                : '${dashboardState.pwm}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain)),
                        TextSpan(
                            text: dashboardState.waveform == 3 ? ' ms' : ' %',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted)),
                      ]))
                    ],
                  )
                ])
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTreatmentsSection(
      DashboardState dashboardState,
      DashboardNotifier notifier,
      BleState bleState,
      PatientState patientState,
      BuildContext context,
      WidgetRef ref) {
    // Formas de Onda Directas según requerimiento (sin presets médicos)
    final presets = [
      app_preset.Preset(
        name: 'Cuadrada',
        subtitle: 'PWM puro',
        details: '15Hz • 10% • 5m',
        hz: 15,
        pwm: 10,
        durationSeconds: 300,
        iconCodePoint: Icons.crop_square_rounded.codePoint,
        waveform: 0, // Square
      ),
      app_preset.Preset(
        name: 'Burst',
        subtitle: 'Ráfaga micropulsos',
        details: '15 Hz • ventana 5 ms • 5 min',
        hz: 15,
        pwm: 8,
        durationSeconds: 300,
        iconCodePoint: Icons.flash_on_rounded.codePoint,
        waveform: 3, // Burst
      ),
    ];

    return Column(
      children: [
        const SizedBox(height: 24),

        // Quick Treatments Scroll
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('CONFIGURACIONES DE ENSAYO',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140, // Compact height
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildPresetCard(
                        preset,
                        notifier,
                        bleState,
                        patientState,
                        dashboardState.isRunning,
                        dashboardState.isBusy,
                        context,
                        ref),
                  );
                },
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildPresetCard(
      app_preset.Preset preset,
      DashboardNotifier notifier,
      BleState bleState,
      PatientState patientState,
      bool isRunning,
      bool isBusy,
      BuildContext context,
      WidgetRef ref) {
    Color getNeonColor(String title) {
      if (title.contains('Articulaciones')) return AppColors.electricBlue;
      if (title.contains('Dolor')) return AppColors.neonPurple;
      return AppColors.brand;
    }

    final iconColor = getNeonColor(preset.name);

    return InkWell(
      onTap: () async {
        if (isBusy) return;
        if (BlockUIHelper.checkRunningBlock(context, isRunning)) return;
        if (!bleState.isProtocolReady) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.infoReverse,
            animType: AnimType.bottomSlide,
            headerAnimationLoop: false,
            title: 'Sin conexión',
            desc:
                'Debes conectar y emparejar un dispositivo antes de iniciar las rutinas automáticas.',
            btnOkOnPress: () {},
            btnOkText: 'Entendido',
            btnOkColor: AppColors.electricBlue,
          ).show();
          return;
        }

        if (patientState.activePatient == null) {
          showPatientSelectionBottomSheet(context, ref, () async {
            await notifier.applyPreset(preset);
          });
        } else {
          await notifier.applyPreset(preset);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate100),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(
                  IconData(preset.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: iconColor,
                  size: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preset.name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain,
                        height: 1.1)),
                Text(preset.subtitle,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted, height: 1.2)),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.center,
              child: RichText(
                  text: TextSpan(children: [
                TextSpan(
                    text: '${preset.hz}Hz',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
                TextSpan(
                    text: ' • ',
                    style: TextStyle(
                        fontSize: 8, color: iconColor.withOpacity(0.5))),
                TextSpan(
                    text: preset.waveform == 3 ? '5 ms' : '${preset.pwm}%',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
                TextSpan(
                    text: ' • ',
                    style: TextStyle(
                        fontSize: 8, color: iconColor.withOpacity(0.5))),
                TextSpan(
                    text: '${preset.durationSeconds ~/ 60}m',
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
              ])),
            )
          ],
        ),
      ),
    );
  }
}
