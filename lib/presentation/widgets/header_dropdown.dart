import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/ble_provider.dart';
import '../../domain/models/ble_device_model.dart';
import '../providers/patient_provider.dart';
import 'package:go_router/go_router.dart';

class HeaderDropdown extends ConsumerWidget {
  const HeaderDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final patientState = ref.watch(patientProvider);

    final savedDevices = bleState.savedDevices;

    return PopupMenuButton<BLEDeviceModel?>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      onSelected: (device) {
        if (device == null) {
          context.go('/devices');
        } else {
          // We're already connected if it's the active one
          if (device.id != bleState.connectedDevice?.id) {
            if (!bleState.isScanning) {
              bleNotifier.connect(device);
            }
          }
        }
      },
      itemBuilder: (context) {
        List<PopupMenuEntry<BLEDeviceModel?>> items = [
          PopupMenuItem(
            enabled: false,
            height: 32,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('LISTA RÁPIDA DE EQUIPOS',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/devices');
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: 14, color: AppColors.electricBlue),
                        Text('AÑADIR',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.electricBlue,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  )
                ]),
          ),
          const PopupMenuDivider(),
        ];

        if (savedDevices.isEmpty) {
          items.add(const PopupMenuItem(
            enabled: false,
            child: Center(
                child: Text('No hay equipos vinculados',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.textMuted))),
          ));
        } else {
          for (var dev in savedDevices) {
            final isActive = dev.id == bleState.connectedDevice?.id;
            items.add(PopupMenuItem(
              value: dev,
              height: 48,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppColors.neonTeal
                                : AppColors.slate300),
                      ),
                      const SizedBox(width: 8),
                      Text(dev.name,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain)),
                    ]),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.neonTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('CONECTADO',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.neonTeal,
                                letterSpacing: 1)),
                      )
                    else
                      const Text('CONECTAR',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 1)),
                  ]),
            ));
          }
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: AppColors.slate100, shape: BoxShape.circle),
                  child: Icon(Icons.bluetooth_rounded,
                      size: 16,
                      color: bleState.connectedDevice != null
                          ? AppColors.neonTeal
                          : AppColors.brand),
                ),
                if (bleState.connectedDevice != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: AppColors.slate400, // Dot matching reference
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                  ),
              ]),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      bleState.connectedDevice != null
                          ? 'ACTIVO'
                          : 'SIN EQUIPO',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: bleState.connectedDevice != null
                              ? AppColors.neonTeal
                              : AppColors.textMuted)),
                  Row(
                    children: [
                      Text(bleState.connectedDevice?.name ?? 'Seleccionar...',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain,
                              height: 1.1)),
                      const Icon(Icons.expand_more_rounded,
                          size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ],
              )
            ]),

            // Active Patient Info
            if (patientState.activePatient != null)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.brand.withOpacity(0.1))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 12, color: AppColors.brand),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          patientState.activePatient!.name.split(' ').first,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMain),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                ),
              ),

            // Battery (Real data from ESP32)
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.slate200))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  bleState.connectedDevice != null &&
                          bleState.batteryPercentage >= 0
                      ? '${bleState.batteryPercentage}%'
                      : '--',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: bleState.batteryPercentage < 0
                        ? AppColors.textMuted
                        : bleState.batteryPercentage < 5
                            ? Colors.redAccent
                            : bleState.batteryPercentage < 20
                                ? Colors.orangeAccent
                                : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  bleState.connectedDevice != null &&
                          bleState.batteryPercentage >= 0
                      ? (bleState.batteryPercentage > 80
                          ? Icons.battery_full_rounded
                          : bleState.batteryPercentage > 20
                              ? Icons.battery_3_bar_rounded
                              : Icons.battery_1_bar_rounded)
                      : Icons.battery_unknown_rounded,
                  size: 16,
                  color: bleState.batteryPercentage < 0
                      ? AppColors.textMuted
                      : bleState.batteryPercentage < 5
                          ? Colors.redAccent
                          : bleState.batteryPercentage < 20
                              ? Colors.orangeAccent
                              : AppColors.neonTeal,
                ),
              ]),
            )
          ],
        ),
      ),
    );
  }
}
