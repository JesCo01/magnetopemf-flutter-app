import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEDeviceModel {
  final BluetoothDevice device;
  final String name;
  final String id;
  final bool isConnected;

  BLEDeviceModel({
    required this.device,
    required this.name,
    required this.id,
    this.isConnected = false,
  });

  BLEDeviceModel copyWith({
    BluetoothDevice? device,
    String? name,
    String? id,
    bool? isConnected,
  }) {
    return BLEDeviceModel(
      device: device ?? this.device,
      name: name ?? this.name,
      id: id ?? this.id,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
