import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../providers/patient_provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _conditionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _savePatient() {
    final name = _nameController.text.trim();
    final ageStr = _ageController.text.trim();
    final condition = _conditionController.text.trim();

    if (name.isEmpty || ageStr.isEmpty || condition.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        headerAnimationLoop: false,
        title: 'Faltan Datos',
        desc: 'Completa todos los campos del nuevo paciente.',
        btnOkOnPress: () {},
        btnOkColor: Colors.orange,
      ).show();
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null || age <= 0 || age > 130) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        headerAnimationLoop: false,
        title: 'Edad Inválida',
        desc: 'Ingresa una edad válida en formato numérico.',
        btnOkOnPress: () {},
        btnOkColor: Colors.redAccent,
      ).show();
      return;
    }

    ref.read(patientProvider.notifier).addPatient(name, age, condition);
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.bottomSlide,
      headerAnimationLoop: false,
      title: 'Guardado',
      desc: 'Paciente registrado exitosamente.',
      btnOkOnPress: () {},
      btnOkColor: AppColors.neonTeal,
    ).show();

    _nameController.clear();
    _ageController.clear();
    _conditionController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pacientes',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain)),
                  SizedBox(height: 4),
                  Text('Registro y Configuración',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.textMain,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2))
                    ]),
                child: const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 16),
              )
            ],
          ),
          const SizedBox(height: 20),

          // Active Patient Box
          if (patientState.activePatient != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brand.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.brand, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PACIENTE ACTIVO',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: AppColors.brand)),
                        Text(patientState.activePatient!.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                                height: 1.1)),
                      ],
                    ),
                  ]),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.slate200),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.textMuted, size: 20),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Formulario Nuevo Paciente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate100),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 8,
                    offset: Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nuevo Registro Médico',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMain)),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.slate100, height: 1)),
                _inputField(
                    'NOMBRE COMPLETO', 'Ej. Carlos Mendoza', _nameController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _inputField('EDAD', 'Años', _ageController,
                            isNumber: true)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _inputField('PADECIMIENTO', 'Diagnóstico',
                            _conditionController)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _savePatient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                  ),
                  child: const Text('GUARDAR PACIENTE'),
                )
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('HISTORIAL CLÍNICO',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppColors.textMuted)),
          const SizedBox(height: 12),

          if (patientState.isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child:
                        CircularProgressIndicator(color: AppColors.neonTeal)))
          else if (patientState.patients.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        size: 48, color: AppColors.slate200),
                    const SizedBox(height: 12),
                    Text('No hay pacientes',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted.withOpacity(0.5))),
                  ],
                ),
              ),
            )
          else
            ...patientState.patients.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _historyCard(
                    p.name,
                    '${p.age} años • ${p.condition}',
                    p.id,
                    AppColors.textMuted,
                    1.0,
                    () =>
                        ref.read(patientProvider.notifier).deletePatient(p.id),
                    () => context.push('/patient-history', extra: p))))
        ],
      ),
    );
  }

  Widget _inputField(
      String label, String placeholder, TextEditingController controller,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 12),
            filled: true,
            fillColor: AppColors.bgApp,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.slate200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.slate200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.neonTeal)),
          ),
          style: const TextStyle(fontSize: 12, color: AppColors.textMain),
        ),
      ],
    );
  }

  Widget _historyCard(String name, String details, String id, Color accent,
      double opacity, VoidCallback onDelete, VoidCallback onTap) {
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 4)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(details,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
        ),
      ),
    );
  }
}
