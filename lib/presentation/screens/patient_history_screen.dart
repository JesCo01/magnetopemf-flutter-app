import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/patient.dart';
import '../../core/constants/app_colors.dart';
import '../providers/history_provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class PatientHistoryScreen extends ConsumerWidget {
  final Patient patient;

  const PatientHistoryScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsyncValue = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      appBar: AppBar(
        backgroundColor: AppColors.bgApp,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMain),
          onPressed: () => context.pop(),
        ),
        title: const Text('Historial del Paciente',
            style: TextStyle(color: AppColors.textMain, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.brand, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain)),
                    const SizedBox(height: 2),
                    Text('${patient.age} años • ${patient.condition}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                )
              ]),
              const SizedBox(height: 32),
              historyAsyncValue.when(
                data: (allSessions) {
                  final sessions = allSessions
                      .where((s) => s.patientName == patient.name)
                      .toList();

                  if (sessions.isEmpty) {
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Column(children: [
                              const Icon(Icons.history_rounded,
                                  size: 48, color: AppColors.slate200),
                              const SizedBox(height: 12),
                              Text('Sin tratamientos registrados',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted
                                          .withOpacity(0.5))),
                            ])));
                  }
                  return Stack(
                    children: [
                      // Timeline line
                      Positioned(
                        left: 5.5,
                        top: 16,
                        bottom: 0,
                        width: 2,
                        child: Container(color: AppColors.slate100),
                      ),
                      Column(
                        children: sessions
                            .map((s) =>
                                _buildTimelineItem(s, sessions.first == s))
                            .toList(),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.neonTeal)),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(session, bool isFirst) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final reasonColor = _reasonColor(session.stopReason);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isFirst ? AppColors.brand : AppColors.slate300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate100),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          session.presetName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(dateFormatter.format(session.date),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: reasonColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      session.stopReasonLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: reasonColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoCol(
                            'Duración', '${session.durationSeconds ~/ 60} min'),
                        Container(
                            width: 1, height: 24, color: AppColors.slate200),
                        _infoCol('Frec.', '${session.hz} Hz'),
                        Container(
                            width: 1, height: 24, color: AppColors.slate200),
                        _infoCol('Ciclo PWM', '${session.pwm}%'),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain)),
      ],
    );
  }

  Color _reasonColor(String reason) {
    switch (reason) {
      case 'completed':
        return AppColors.green500;
      case 'low_battery':
        return const Color(0xFFBE123C);
      case 'disconnected':
        return Colors.orangeAccent;
      default:
        return AppColors.textMuted;
    }
  }
}
