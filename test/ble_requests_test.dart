import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magneto_pro/data/ble_frames.dart';
import 'package:magneto_pro/data/repositories/ble_repository.dart';
import 'package:magneto_pro/presentation/providers/ble_provider.dart';

class RadioStub extends BleRepository {
  @override
  Stream<List<ScanResult>> get scanResults => const Stream.empty();
}

class Exchange extends BleNotifier {
  final ids = <int>[];
  final commands = <String>[];
  bool answerStatus = false;
  Exchange(Ref ref) : super(RadioStub(), ref);
  @override
  Future<bool> writeCommand(String command, {int? requestId}) async {
    ids.add(requestId!);
    commands.add(jsonDecode(command)['cmd']);
    if (answerStatus && commands.last == 'status') {
      respond(requestId, '{"state":"IDLE"}');
    }
    return true;
  }

  void respond(int id, String json) {
    for (final f in BleFrames.encode(json, id, 23)) {
      receiveFrame(f);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Exchange ble;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
        overrides: [bleProvider.overrideWith((ref) => Exchange(ref))]);
    ble = container.read(bleProvider.notifier) as Exchange;
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() => container.dispose());
  test('Respuesta tardía o telemetría no confirma otra solicitud', () async {
    var completed = false;
    final future = ble.sendCommandAndAwaitResponse('{"cmd":"pause"}',
        accept: (m) => m.contains('paused'));
    future.then((_) => completed = true);
    final id = ble.ids.single;
    ble.respond(0, '{"ok":"paused"}');
    ble.respond(id + 1, '{"ok":"paused"}');
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    ble.respond(id, '{"ok":"paused"}');
    expect(await future, '{"ok":"paused"}');
  });
  test('Timeout consulta status con nuevo id sin reenviar start', () async {
    ble.answerStatus = true;
    final result = await ble.sendCommandAndAwaitResponse('{"cmd":"start"}',
        accept: (m) => m.contains('started'),
        timeout: const Duration(milliseconds: 5));
    expect(result, isNull);
    expect(ble.commands, ['start', 'status']);
    expect(ble.ids.toSet().length, 2);
    expect(container.read(bleProvider).synchronized, isTrue);
  });
}
