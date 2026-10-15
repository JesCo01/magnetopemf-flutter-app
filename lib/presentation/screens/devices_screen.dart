import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/ble_provider.dart';
import '../../domain/models/ble_device_model.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/block_ui_helper.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final bleNotifier = ref.read(bleProvider.notifier);
    final isRunning =
        ref.watch(dashboardProvider).isRunning && bleState.isProtocolReady;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Equipos Bluetooth',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain)),
          const SizedBox(height: 4),
          const Text('Conecta y administra el equipo PEMF',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          const Text(
              'Primer vínculo: con el equipo en reposo, habilita PAIR desde su consola USB e introduce en Android el PIN temporal mostrado. Los vínculos guardados se reutilizan.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),

          // Scan Button
          ElevatedButton.icon(
            onPressed: bleState.isScanning
                ? null
                : () async {
                    if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                      return;
                    }
                    var status = await Permission.location.status;
                    if (status.isDenied) await Permission.location.request();
                    bleNotifier.startScan();
                  },
            icon: bleState.isScanning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppColors.neonTeal, strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching_rounded,
                    color: AppColors.neonTeal, size: 18),
            label: Text(
                bleState.isScanning ? 'BUSCANDO...' : 'BUSCAR NUEVO HARDWARE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.neonTeal,
              elevation: 2,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      const BorderSide(color: AppColors.neonTeal, width: 1.5)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10),
            ),
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('ESCANEADOS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted)),
          ),
          const SizedBox(height: 8),

          // Scanned List
          if (bleState.scannedDevices.isEmpty && !bleState.isScanning)
            _buildEmptyState(
                'Presiona "Buscar" para rastrear', Icons.bluetooth_rounded),

          ...bleState.scannedDevices.asMap().entries.map((entry) =>
              _buildScannedDeviceCard(entry.value, entry.key, bleNotifier,
                  bleState.savedDevices, isRunning, context)),

          const SizedBox(height: 24),

          // Saved Devices
          if (bleState.savedDevices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('MIS EQUIPOS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 8),
            ...bleState.savedDevices.map((d) => _buildSavedDeviceCard(
                d, bleState.connectedDevice, bleNotifier, isRunning, context)),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.slate300),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildScannedDeviceCard(
      BLEDeviceModel device,
      int index,
      BleNotifier notifier,
      List<BLEDeviceModel> savedDevices,
      bool isRunning,
      BuildContext context) {
    final isSaved = savedDevices.any((d) => d.id == device.id);

    return TweenAnimationBuilder<double>(
      key: ValueKey(device.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100).clamp(0, 600)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: AppColors.neonTeal.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.memory_rounded,
                        color: AppColors.neonTeal, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain),
                            overflow: TextOverflow.ellipsis),
                        Text(device.id,
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                                letterSpacing: 1.5),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isSaved)
              Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.neonTeal, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                      return;
                    }
                    notifier.forgetDevice(device.id);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.textMuted, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                )
              ])
            else
              ElevatedButton(
                onPressed: () {
                  if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                    return;
                  }
                  notifier.saveDevice(device);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('GUARDAR',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildSavedDeviceCard(
      BLEDeviceModel savedModel,
      BLEDeviceModel? connectedModel,
      BleNotifier notifier,
      bool isRunning,
      BuildContext context) {
    final isConnected = connectedModel?.id == savedModel.id;
    return TweenAnimationBuilder<double>(
      key: ValueKey('saved_${savedModel.id}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
            opacity: value,
            child: Transform.scale(scale: 0.95 + (0.05 * value), child: child));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.neonTeal.withOpacity(isConnected ? 0.3 : 0.0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: (isConnected
                                ? AppColors.neonTeal
                                : AppColors.textMuted)
                            .withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.memory_rounded,
                        color: isConnected
                            ? AppColors.neonTeal
                            : AppColors.textMuted,
                        size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(savedModel.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain),
                            overflow: TextOverflow.ellipsis),
                        Text(
                            isConnected
                                ? 'ACTIVO Y CONECTADO'
                                : 'VINCULADO - OFFLINE',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isConnected
                                    ? AppColors.neonTeal
                                    : AppColors.textMuted,
                                letterSpacing: 1.5),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (!isConnected)
                  IconButton(
                    onPressed: () {
                      if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                        return;
                      }
                      notifier.connect(savedModel);
                    },
                    icon: const Icon(Icons.link_rounded,
                        color: AppColors.electricBlue, size: 22),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Conectar Equipo',
                  ),
                if (isConnected)
                  IconButton(
                    onPressed: () {
                      if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                        return;
                      }
                      notifier.disconnect();
                    },
                    icon: const Icon(Icons.link_off_rounded,
                        color: Colors.orangeAccent, size: 22),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Desconectar Equipo',
                  ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    if (BlockUIHelper.checkRunningBlock(context, isRunning)) {
                      return;
                    }
                    notifier.forgetDevice(savedModel.id);
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.textMuted, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
