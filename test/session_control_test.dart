import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magneto_pro/data/repositories/ble_repository.dart';
import 'package:magneto_pro/data/repositories/session_repository.dart';
import 'package:magneto_pro/domain/models/ble_device_model.dart';
import 'package:magneto_pro/domain/models/session.dart';
import 'package:magneto_pro/presentation/providers/ble_provider.dart';
import 'package:magneto_pro/presentation/providers/dashboard_provider.dart';

class NoRadio extends BleRepository {
  @override
  Stream<List<ScanResult>> get scanResults => const Stream.empty();
}

class MemoryHistory extends SessionRepository {
  final saved = <Session>[];
  @override
  Future<void> saveSession(Session s) async {
    saved.add(s);
  }

  @override
  Future<List<Session>> getSessions() async => saved;
}

class TestBle extends BleNotifier {
  String? response;
  Map<String, dynamic>? remote;
  final commands = <Map<String, dynamic>>[];
  TestBle(Ref ref) : super(NoRadio(), ref) {
    state = state.copyWith(
        synchronized: true,
        batteryPercentage: 80,
        connectedDevice: BLEDeviceModel(
            id: 'AA:BB:CC:DD:EE:FF',
            name: 'test',
            device: BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF')),
        writeCharacteristic: BluetoothCharacteristic(
            remoteId: const DeviceIdentifier('AA:BB:CC:DD:EE:FF'),
            serviceUuid: Guid(BleRepository.serviceUuid),
            characteristicUuid: Guid(BleRepository.characteristicUuid)));
  }
  @override
  Future<String?> sendCommandAndAwaitResponse(String command,
      {required bool Function(String) accept,
      Duration timeout = const Duration(seconds: 2)}) async {
    commands.add(Map<String, dynamic>.from(jsonDecode(command)));
    if (response == null && remote != null) emit(remote!);
    return response;
  }

  @override
  Future<Map<String, dynamic>?> queryStatus() async {
    if (remote != null) emit(remote!);
    return remote;
  }

  void emit(Map<String, dynamic> data) {
    state = state.copyWith(lastMessage: jsonEncode(data));
  }

  void loseLink() {
    state = state.copyWith(
        clearConnected: true, clearChar: true, synchronized: false);
  }
}

Map<String, dynamic> status(String state,
        {int seconds = 200, int wave = 4, int hz = 50, int duty = 20}) =>
    {
      'state': state,
      'remaining_sec': seconds,
      'total_sec': 300,
      'elapsed_sec': 300 - seconds,
      'stop_reason': state == 'IDLE' ? 'disconnected' : 'running',
      'channels': [
        {'freq': hz, 'duty_pct': duty, 'wave': wave}
      ]
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late MemoryHistory history;
  late TestBle ble;
  late DashboardNotifier control;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    history = MemoryHistory();
    container = ProviderContainer(overrides: [
      sessionRepositoryProvider.overrideWithValue(history),
      bleProvider.overrideWith((ref) => TestBle(ref))
    ]);
    control = container.read(dashboardProvider.notifier);
    ble = container.read(bleProvider.notifier) as TestBle;
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() {
    container.dispose();
  });
  test('Inicio rechazado no inicia ni registra', () async {
    ble.response = '{"error":"INVALID_PARAM"}';
    expect(await control.startTherapy(), isFalse);
    expect(control.snapshot.isRunning, isFalse);
    expect(history.saved, isEmpty);
  });
  test('Telemetría sincroniza tiempo, modo y mantiene borradores en pausa',
      () async {
    ble.emit(status('RUNNING', wave: 3));
    expect(control.snapshot.waveform, 3);
    expect(control.snapshot.currentSeconds, 200);
    ble.emit(status('PAUSED', seconds: 180, wave: 3));
    control.updateParams(hz: 75, pwm: 40);
    ble.emit(status('PAUSED', seconds: 179, wave: 3));
    expect(control.snapshot.hz, 50);
    expect(control.snapshot.manualHz, 75);
    expect(control.snapshot.waveform, 3);
    ble.response = '{"ok":"resumed","remaining_sec":179}';
    expect(await control.resumeTherapy(applyPending: true), isTrue);
    expect(control.snapshot.waveform, 4);
    expect(control.snapshot.hz, 75);
    expect(control.snapshot.pwm, 40);
    expect(control.snapshot.isPaused, isFalse);
  });
  test(
      'Parada sin confirmación conserva registro; confirmada lo cierra una vez',
      () async {
    ble.emit(status('RUNNING'));
    await control.stopTherapy();
    expect(history.saved, isEmpty);
    expect(control.snapshot.isRunning, isTrue);
    ble.response = '{"ok":"stopped"}';
    await control.stopTherapy();
    await control.stopTherapy();
    expect(history.saved.length, 1);
    expect(control.snapshot.isRunning, isFalse);
  });
  test('Desconexión espera estado terminal, sin reanudar automáticamente',
      () async {
    ble.emit(status('RUNNING'));
    ble.loseLink();
    expect(history.saved, isEmpty);
    expect(control.snapshot.isPaused, isTrue);
    expect(await control.resumeTherapy(), isFalse);
    ble.emit(status('IDLE', seconds: 190));
    await Future<void>.delayed(Duration.zero);
    expect(history.saved.single.stopReason, 'disconnected');
    expect(history.saved.single.durationSeconds, 110);
    expect(ble.commands, isEmpty);
  });
  test(
      'Ausencia de ACK no repite inicio y el estado recuperado gobierna la vista',
      () async {
    ble.remote = status('RUNNING', seconds: 298);
    expect(await control.startTherapy(), isFalse);
    expect(control.snapshot.isRunning, isTrue);
    expect(ble.commands.where((c) => c['cmd'] == 'start').length, 1);
  });
  test('Límites de edición del ensayo', () {
    control.updateParams(hz: 1, pwm: 120, timeMinutes: 480);
    expect(control.snapshot.hz, 10);
    expect(control.snapshot.pwm, 90);
    expect(control.snapshot.totalSeconds, 600);
  });
}
