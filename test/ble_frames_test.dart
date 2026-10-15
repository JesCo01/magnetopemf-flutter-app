import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:magneto_pro/data/ble_frames.dart';

void main() {
  for (final mtu in [23, 64, 247, 512]) {
    test('UTF-8, ids y límite ATT con MTU $mtu', () {
      final payload = jsonEncode(
          {'state': 'PAUSED', 'texto': List.filled(120, 'áµ').join()});
      final frames = BleFrames.encode(payload, 65535, mtu);
      final receiver = BleFrames();
      BleMessage? complete;
      for (final frame in frames) {
        expect(frame.length, lessThanOrEqualTo(mtu - 3));
        complete = receiver.accept(frame);
      }
      expect(complete?.text, payload);
      expect(complete?.id, 65535);
    });
  }
  test('Fragmento perdido o duplicado nunca entrega JSON parcial', () {
    final frames = BleFrames.encode('x' * 200, 12, 23);
    final receiver = BleFrames();
    expect(receiver.accept(frames[0]), isNull);
    expect(() => receiver.accept(frames[2]), throwsFormatException);
    receiver.accept(frames[0]);
    receiver.accept(frames[1]);
    expect(() => receiver.accept(frames[1]), throwsFormatException);
  });
  test('Caducidad, cambio de id y nueva transferencia', () {
    final frames = BleFrames.encode('x' * 60, 7, 23);
    final receiver = BleFrames();
    final now = DateTime(2026);
    receiver.accept(frames[0], now: now);
    expect(
        () => receiver.accept(frames[1],
            now: now.add(const Duration(seconds: 4))),
        throwsFormatException);
    receiver.accept(frames[0]);
    final changed = [...frames[1]];
    changed[2] = 8;
    expect(() => receiver.accept(changed), throwsFormatException);
    final single = BleFrames.encode('OK', 22, 23).single;
    expect(receiver.accept(single)?.text, 'OK');
  });
  test('Tamaño máximo, encabezado y datos UTF-8 inválidos', () {
    final receiver = BleFrames();
    BleMessage? result;
    for (final p in BleFrames.encode('x' * 1024, 0, 23)) {
      result = receiver.accept(p);
    }
    expect(result?.text.length, 1024);
    expect(() => BleFrames.encode('x' * 1025, 1, 23), throwsFormatException);
    expect(
        () => receiver.accept([0, 1, 0, 0, 0, 3, 65]), throwsFormatException);
    expect(() => receiver.accept([0xa5, 1, 0, 0, 0, 3, 255]),
        throwsFormatException);
  });
}
