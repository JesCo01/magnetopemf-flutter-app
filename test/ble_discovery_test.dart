import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magneto_pro/data/repositories/ble_repository.dart';

class TestCharacteristic extends BluetoothCharacteristic {
  final bool hasCccd;
  final bool canWrite;
  TestCharacteristic({required this.hasCccd, this.canWrite = true})
      : super(
          remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:FF'),
          serviceUuid: Guid(BleRepository.serviceUuid),
          characteristicUuid: Guid(BleRepository.characteristicUuid),
        );
  @override
  CharacteristicProperties get properties =>
      CharacteristicProperties(write: canWrite, notify: true);
  @override
  List<BluetoothDescriptor> get descriptors => hasCccd
      ? [
          BluetoothDescriptor(
              remoteId: remoteId,
              serviceUuid: serviceUuid,
              characteristicUuid: characteristicUuid,
              descriptorUuid: cccdUuid)
        ]
      : [];
}

class TestService implements BluetoothService {
  @override
  Guid get uuid => Guid(BleRepository.serviceUuid);
  @override
  final List<BluetoothCharacteristic> characteristics;
  TestService(BluetoothCharacteristic characteristic)
      : characteristics = [characteristic];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDevice extends BluetoothDevice {
  final List<List<BluetoothService>> discoveries;
  int discoveryCount = 0;
  int refreshCount = 0;
  bool failRefresh = false;
  TestDevice(this.discoveries) : super.fromId('AA:BB:CC:DD:EE:FF');
  @override
  Future<List<BluetoothService>> discoverServices({int timeout = 15}) async =>
      discoveries[discoveryCount++];
  @override
  Future<void> clearGattCache() async {
    refreshCount++;
    if (failRefresh) throw StateError('refresh failed');
  }
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('GATT valido no borra cache', () async {
    final characteristic = TestCharacteristic(hasCccd: true);
    final device = TestDevice([
      [TestService(characteristic)]
    ]);
    expect(
        await BleRepository().getWriteCharacteristic(device), characteristic);
    expect(device.refreshCount, 0);
  });

  test('Recupera CCCD ausente redescubriendo tras renovar cache', () async {
    final fresh = TestCharacteristic(hasCccd: true);
    final device = TestDevice([
      [TestService(TestCharacteristic(hasCccd: false))],
      [TestService(fresh)],
    ]);
    expect(await BleRepository().getWriteCharacteristic(device), fresh);
    expect(device.refreshCount, 1);
    expect(device.discoveryCount, 2);
  });

  test('CCCD ausente persistente rechaza conexion sin bucle de reintentos',
      () async {
    final services = [TestService(TestCharacteristic(hasCccd: false))];
    final device = TestDevice([services, services]);
    await expectLater(BleRepository().getWriteCharacteristic(device),
        throwsA(isA<BleSetupException>()));
    expect(device.refreshCount, 1);
    expect(device.discoveryCount, 2);
  });

  test('Servicio ausente tambien se redescubre', () async {
    final fresh = TestCharacteristic(hasCccd: true);
    final device = TestDevice([
      [],
      [TestService(fresh)]
    ]);
    expect(await BleRepository().getWriteCharacteristic(device), fresh);
  });

  test('No acepta caracteristica sin escritura con respuesta', () async {
    final services = [
      TestService(TestCharacteristic(hasCccd: true, canWrite: false))
    ];
    await expectLater(
        BleRepository()
            .getWriteCharacteristic(TestDevice([services, services])),
        throwsA(isA<BleSetupException>()));
  });

  test('Fallo al renovar cache produce error de conexion controlado', () async {
    final device = TestDevice([[]])..failRefresh = true;
    await expectLater(BleRepository().getWriteCharacteristic(device),
        throwsA(isA<BleSetupException>()));
    expect(device.discoveryCount, 1);
  });
}
