import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../providers/patient_provider.dart';

void showPatientSelectionBottomSheet(
  BuildContext context,
  WidgetRef ref,
  FutureOr<void> Function() onSelected,
) {
  final state = ref.read(patientProvider);

  showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
            padding: EdgeInsets.fromLTRB(
                20, 24, 20, MediaQuery.of(context).padding.bottom + 90),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.slate200,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  const Text('Destinatario de la Terapia',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain)),
                  const SizedBox(height: 4),
                  const Text(
                      'Selecciona el paciente registrado para asignar los datos de esta sesión clínica.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 24),
                  if (state.patients.isEmpty)
                    Center(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(Icons.people_alt_rounded,
                              size: 48, color: AppColors.slate200),
                          const SizedBox(height: 12),
                          const Text('No hay pacientes',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close sheet
                              context.go('/config');
                            },
                            icon:
                                const Icon(Icons.person_add_rounded, size: 14),
                            label: const Text('AGREGAR PACIENTE',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5)),
                          )
                        ],
                      ),
                    ))
                  else
                    SizedBox(
                      height: 300, // Limit height
                      child: ListView.builder(
                          itemCount: state.patients.length,
                          itemBuilder: (context, index) {
                            final p = state.patients[index];
                            return InkWell(
                              onTap: () async {
                                ref
                                    .read(patientProvider.notifier)
                                    .setActivePatient(p);
                                Navigator.pop(context);
                                await onSelected();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    border:
                                        Border.all(color: AppColors.slate200),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color:
                                              AppColors.brand.withOpacity(0.1),
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.person_rounded,
                                          color: AppColors.brand),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(p.name,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textMain)),
                                          Text('${p.age} años • ${p.condition}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textMuted)),
                                        ])),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppColors.textMuted)
                                  ],
                                ),
                              ),
                            );
                          }),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(patientProvider.notifier)
                          .setOmittedPatient();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await onSelected();
                    },
                    icon: const Icon(Icons.skip_next_rounded,
                        color: AppColors.textMuted, size: 18),
                    label: const Text('Omitir Selección (Paciente Anónimo)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: AppColors.slate200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  )
                ]));
      });
}
