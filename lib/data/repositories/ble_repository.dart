import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../ble_frames.dart';

final bleRepositoryProvider = Provider<BleRepository>((ref) {
  return BleRepository();
});

class BleSetupException implements Exception {
  final String message;
  const BleSetupException(this.message);
  @override
  String toString() => message;
}

class BleRepository {
  // UUIDs deben coincidir con Config.h del ESP32
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  Future<void> _writes = Future.value();

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 4)}) async {
    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) return;

    if (FlutterBluePlus.isScanningNow) return;

    await FlutterBluePlus.startScan(
      withServices: [Guid(serviceUuid)],
      timeout: timeout,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, mtu: null);
      try {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final mtu = await device.requestMtu(512);
          debugPrint('[BLE] MTU negociado: $mtu bytes');
        }
      } catch (e) {
        debugPrint("⚠️ Advertencia: No se pudo negociar MTU - $e");
      }
      return true;
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      await disconnectDevice(device);
      return false;
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }

  Future<BluetoothCharacteristic?> getWriteCharacteristic(
      BluetoothDevice device) async {
    try {
      // Android can retain the old GATT table after the ESP32 is reflashed.
      // Retry discovery once, and never continue without a notification path.
      for (var attempt = 0; attempt < 2; attempt++) {
        final services = await device.discoverServices();
        BluetoothCharacteristic? candidate;
        for (BluetoothService service in services) {
          if (service.uuid.toString().toLowerCase() ==
              serviceUuid.toLowerCase()) {
            for (BluetoothCharacteristic char in service.characteristics) {
              if (char.uuid.toString().toLowerCase() ==
                  characteristicUuid.toLowerCase()) {
                candidate = char;
              }
            }
          }
        }
        if (candidate != null &&
            candidate.properties.write &&
            candidate.properties.notify &&
            (defaultTargetPlatform != TargetPlatform.android ||
                candidate.descriptors.any((d) => d.uuid == cccdUuid))) {
          return candidate;
        }
        debugPrint('[BLE] GATT incompleto: caracteristica=${candidate?.uuid}, '
            'descriptores=${candidate?.descriptors.map((d) => d.uuid).toList()}');
        if (attempt == 0 && defaultTargetPlatform == TargetPlatform.android) {
          debugPrint(
              '[BLE] Actualizando cache GATT y redescubriendo servicios');
          await device.clearGattCache();
          continue;
        }
        throw const BleSetupException(
            'El ESP32 no expone el canal de notificaciones requerido. '
            'Reinicia el equipo y vuelve a buscarlo. Si persiste, revisa el firmware.');
      }
    } on BleSetupException {
      rethrow;
    } catch (e) {
      debugPrint("Error discovering services: $e");
      throw const BleSetupException(
          'No se pudieron preparar los servicios Bluetooth. Vuelve a conectar el equipo.');
    }
    return null;
  }

  Future<bool> writeCommand(
      BluetoothCharacteristic characteristic, String command,
      {required int requestId}) async {
    final completion = Completer<bool>();
    _writes = _writes.then((_) async {
      try {
        for (final frame in BleFrames.encode(
            command, requestId, characteristic.device.mtuNow)) {
          await characteristic.write(frame, withoutResponse: false);
        }
        completion.complete(true);
      } catch (error) {
        completion.complete(false);
      }
    });
    return completion.future;
  }
}
