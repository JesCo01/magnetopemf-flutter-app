import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/ble_frames.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/ble_repository.dart';
import '../../domain/models/ble_device_model.dart';
import 'app_alert_provider.dart';

enum _BatteryAlertLevel { normal, low, critical }

class _PendingResponse {
  final int id;
  final bool Function(String) accept;
  final Completer<String?> completer;

  _PendingResponse({
    required this.id,
    required this.accept,
    required this.completer,
  });
}

class BleState {
  final bool isScanning;
  final bool synchronized;
  final List<BLEDeviceModel> scannedDevices;
  final BLEDeviceModel? connectedDevice;
  final List<BLEDeviceModel> savedDevices;
  final BluetoothCharacteristic? writeCharacteristic;
  final String? lastMessage;
  final int batteryPercentage;
  final double batteryVoltage;

  bool get isProtocolReady =>
      connectedDevice != null && writeCharacteristic != null && synchronized;

  BleState({
    this.isScanning = false,
    this.synchronized = false,
    this.scannedDevices = const [],
    this.connectedDevice,
    this.savedDevices = const [],
    this.writeCharacteristic,
    this.lastMessage,
    this.batteryPercentage = -1,
    this.batteryVoltage = 0.0,
  });

  BleState copyWith({
    bool? isScanning,
    bool? synchronized,
    List<BLEDeviceModel>? scannedDevices,
    BLEDeviceModel? connectedDevice,
    List<BLEDeviceModel>? savedDevices,
    BluetoothCharacteristic? writeCharacteristic,
    String? lastMessage,
    int? batteryPercentage,
    double? batteryVoltage,
    bool clearConnected = false,
    bool clearChar = false,
    bool clearMessage = false,
  }) {
    return BleState(
      isScanning: isScanning ?? this.isScanning,
      synchronized: synchronized ?? this.synchronized,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      connectedDevice:
          clearConnected ? null : (connectedDevice ?? this.connectedDevice),
      savedDevices: savedDevices ?? this.savedDevices,
      writeCharacteristic:
          clearChar ? null : (writeCharacteristic ?? this.writeCharacteristic),
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
    );
  }
}

class BleNotifier extends StateNotifier<BleState> {
  final BleRepository _bleRepo;
  final Ref _ref;
  StreamSubscription<List<int>>? _messageSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  final List<_PendingResponse> _pendingResponses = [];
  _BatteryAlertLevel _batteryAlertLevel = _BatteryAlertLevel.normal;
  bool _userInitiatedDisconnect = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final _frames = BleFrames();
  int _requestId = 0;
  int _nextId() {
    _requestId = (_requestId % 65535) + 1;
    return _requestId;
  }

  BleNotifier(this._bleRepo, this._ref) : super(BleState()) {
    _init();
  }

  void _init() async {
    _scanSubscription = _bleRepo.scanResults.listen((results) {
      if (!mounted) return;
      final devices = results
          .map(
            (r) => BLEDeviceModel(
              device: r.device,
              name: r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : 'Dispositivo Desconocido',
              id: r.device.remoteId.str,
            ),
          )
          .toList();

      state = state.copyWith(scannedDevices: devices);
    });

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedJson = prefs.getString('saved_devices');
    if (savedJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final List<BLEDeviceModel> loaded = decoded
            .map(
              (d) => BLEDeviceModel(
                id: d['id'],
                name: d['name'],
                device: BluetoothDevice.fromId(d['id']),
              ),
            )
            .toList();
        state = state.copyWith(savedDevices: loaded);

        if (loaded.isNotEmpty) {
          Future.delayed(
            const Duration(milliseconds: 500),
            () {
              if (mounted) connect(loaded.last, reconnecting: true);
            },
          );
        }
      } catch (e) {
        debugPrint('Error parsing saved devices: $e');
      }
    }
  }

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, scannedDevices: []);
    await _bleRepo.startScan();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) state = state.copyWith(isScanning: false);
    });
  }

  Future<void> saveDevice(BLEDeviceModel model) async {
    if (state.savedDevices.any((d) => d.id == model.id)) return;
    final newList = List<BLEDeviceModel>.from(state.savedDevices)..add(model);
    state = state.copyWith(savedDevices: newList);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = newList.map((d) => {'id': d.id, 'name': d.name}).toList();
    prefs.setString('saved_devices', jsonEncode(jsonList));
  }

  Future<void> forgetDevice(String deviceId) async {
    if (state.connectedDevice?.id == deviceId) {
      await disconnect();
    }
    final newList = state.savedDevices.where((d) => d.id != deviceId).toList();
    state = state.copyWith(savedDevices: newList);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = newList.map((d) => {'id': d.id, 'name': d.name}).toList();
    prefs.setString('saved_devices', jsonEncode(jsonList));
  }

  Future<bool> connect(
    BLEDeviceModel model, {
    bool reconnecting = false,
  }) async {
    _cancelPendingResponses();
    _frames.reset();
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _userInitiatedDisconnect = false;

    final alertNotifier = _ref.read(appAlertProvider.notifier);
    if (reconnecting) {
      alertNotifier.info(
        'Reconectando',
        'Restableciendo enlace con ${model.name}.',
      );
    } else {
      alertNotifier.info(
        'Conectando',
        'Abriendo enlace BLE con ${model.name}.',
      );
    }

    if (state.connectedDevice != null) {
      await _bleRepo.disconnectDevice(state.connectedDevice!.device);
    }

    final connected = await _bleRepo.connectToDevice(model.device);
    if (!connected) {
      _clearConnectionState();
      return false;
    }

    final char = await _bleRepo.getWriteCharacteristic(model.device);
    if (char == null) {
      await _bleRepo.disconnectDevice(model.device);
      _clearConnectionState();
      return false;
    }

    try {
      await char.setNotifyValue(true);
    } catch (e) {
      debugPrint('Error enabling notifications: $e');
      await _bleRepo.disconnectDevice(model.device);
      _clearConnectionState();
      return false;
    }

    _connectionSubscription = model.device.connectionState.listen((connState) {
      if (connState != BluetoothConnectionState.disconnected) return;

      final hadDevice = state.connectedDevice != null;
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _cancelPendingResponses();
      _clearConnectionState();

      if (hadDevice) {
        if (_userInitiatedDisconnect) {
          alertNotifier.info(
            'Desconectado',
            'El equipo BLE fue desconectado.',
          );
        } else {
          alertNotifier.warning(
            'Conexion perdida',
            'Se perdio la comunicacion con el equipo.',
          );
        }
      }

      _userInitiatedDisconnect = false;
    });

    state = state.copyWith(
      connectedDevice: model.copyWith(isConnected: true),
      writeCharacteristic: char,
      batteryPercentage: -1,
      batteryVoltage: 0.0,
      clearMessage: true,
      synchronized: false,
    );

    _messageSubscription = char.onValueReceived.listen(receiveFrame);

    if (await queryStatus() == null) {
      await disconnect(userInitiated: false);
      return false;
    }
    await saveDevice(model);
    alertNotifier.success(
      'Conectado',
      'Comunicacion BLE lista con ${model.name}.',
    );
    return true;
  }

  void receiveFrame(List<int> value) {
    if (!mounted) return;
    try {
      final message = _frames.accept(value);
      if (message == null) return;
      bool isStatus = false;
      try {
        isStatus = jsonDecode(message.text)['state'] is String;
      } catch (_) {}
      state = state.copyWith(
          lastMessage: message.text, synchronized: isStatus ? true : null);
      _parseBatteryMessage(message.text);
      _resolvePendingResponses(message.text, message.id);
    } on FormatException {
      // A damaged/incomplete message never updates the application state.
    }
  }

  Future<void> disconnect({bool userInitiated = true}) async {
    _userInitiatedDisconnect = userInitiated;
    _cancelPendingResponses();
    _frames.reset();
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (state.connectedDevice != null) {
      await _bleRepo.disconnectDevice(state.connectedDevice!.device);
    }

    final alertNotifier = _ref.read(appAlertProvider.notifier);
    if (userInitiated) {
      alertNotifier.info(
        'Desconectado',
        'El equipo BLE fue desconectado.',
      );
    } else {
      alertNotifier.warning(
        'Conexion perdida',
        'Se interrumpio la comunicacion con el equipo.',
      );
    }
    _clearConnectionState();
  }

  Future<bool> writeCommand(String command, {int? requestId}) async {
    final characteristic = state.writeCharacteristic;
    if (characteristic == null || state.connectedDevice == null) {
      debugPrint(
          'No write characteristic available. Ignoring command: $command');
      return false;
    }

    final success = await _bleRepo.writeCommand(characteristic, command,
        requestId: requestId ?? _nextId());
    if (!success && mounted) {
      await disconnect(userInitiated: false);
    }
    return success;
  }

  Future<String?> sendCommandAndAwaitResponse(
    String command, {
    required bool Function(String message) accept,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final id = _nextId();
    final completer = Completer<String?>();
    final pending = _PendingResponse(
      id: id,
      accept: accept,
      completer: completer,
    );
    _pendingResponses.add(pending);

    final success = await writeCommand(command, requestId: id);
    if (!success || !mounted) {
      _pendingResponses.remove(pending);
      return null;
    }

    try {
      final result =
          await completer.future.timeout(timeout, onTimeout: () => null);
      if (!mounted) return null;
      if (result == null && jsonDecode(command)['cmd'] != 'status') {
        // Do not retry a start: it may already have been applied.
        state = state.copyWith(synchronized: false);
        await queryStatus();
      }
      return result;
    } finally {
      _pendingResponses.remove(pending);
    }
  }

  Future<Map<String, dynamic>?> queryStatus() async {
    final response = await sendCommandAndAwaitResponse(
        jsonEncode({'cmd': 'status'}), accept: (s) {
      try {
        return jsonDecode(s) is Map && jsonDecode(s)['state'] is String;
      } catch (_) {
        return false;
      }
    });
    if (response == null) return null;
    final data = Map<String, dynamic>.from(jsonDecode(response));
    if (mounted) state = state.copyWith(synchronized: true);
    return data;
  }

  void _parseBatteryMessage(String msg) {
    if (!msg.contains('"bat"')) return;
    try {
      final data = jsonDecode(msg);
      if (data is Map && data.containsKey('bat')) {
        final percentage = (data['bat'] as num).toInt();
        final voltage = (data['v'] as num?)?.toDouble() ?? 0.0;

        state = state.copyWith(
          batteryPercentage: percentage,
          batteryVoltage: voltage,
        );
        _handleBatteryAlerts(percentage);
      }
    } catch (_) {
      // Not battery JSON.
    }
  }

  void _resolvePendingResponses(String message, int id) {
    if (_pendingResponses.isEmpty) return;

    for (final pending in List<_PendingResponse>.from(_pendingResponses)) {
      if (pending.completer.isCompleted) continue;
      if (pending.id != id || !pending.accept(message)) continue;

      pending.completer.complete(message);
      _pendingResponses.remove(pending);
    }
  }

  void _handleBatteryAlerts(int percentage) {
    final nextLevel = percentage < 5
        ? _BatteryAlertLevel.critical
        : percentage < 15
            ? _BatteryAlertLevel.low
            : _BatteryAlertLevel.normal;

    if (nextLevel == _batteryAlertLevel) return;
    _batteryAlertLevel = nextLevel;

    if (nextLevel == _BatteryAlertLevel.low) {
      _ref.read(appAlertProvider.notifier).warning(
            'Bateria baja',
            'El equipo esta en $percentage%. Conviene recargar pronto.',
          );
    } else if (nextLevel == _BatteryAlertLevel.critical) {
      _ref.read(appAlertProvider.notifier).critical(
            'Bateria critica',
            'La bateria esta en $percentage%. No inicies terapia hasta recargar.',
          );
    }
  }

  void _clearConnectionState() {
    _batteryAlertLevel = _BatteryAlertLevel.normal;
    state = state.copyWith(
      synchronized: false,
      clearConnected: true,
      clearChar: true,
      clearMessage: true,
      batteryPercentage: -1,
      batteryVoltage: 0.0,
    );
  }

  void _cancelPendingResponses() {
    for (final pending in List<_PendingResponse>.from(_pendingResponses)) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(null);
      }
    }
    _pendingResponses.clear();
  }

  @override
  void dispose() {
    _cancelPendingResponses();
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }
}

final bleProvider = StateNotifierProvider<BleNotifier, BleState>((ref) {
  final repo = ref.watch(bleRepositoryProvider);
  return BleNotifier(repo, ref);
});
