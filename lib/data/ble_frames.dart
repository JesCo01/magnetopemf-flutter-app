import 'dart:convert';

class BleMessage {
  final int id;
  final String text;
  const BleMessage(this.id, this.text);
}

/// Versioned framing shared with BleFrames.h. Supports ATT MTU 23 through 512.
class BleFrames {
  static const maxMessage = 1024;
  static List<List<int>> encode(String text, int id, int mtu) {
    final bytes = utf8.encode(text);
    if (bytes.isEmpty || bytes.length > maxMessage || id < 0 || id > 65535) {
      throw const FormatException('Mensaje BLE fuera de límites');
    }
    final capacity = mtu.clamp(23, 512) - 3 - 6;
    final result = <List<int>>[];
    for (var offset = 0, seq = 0; offset < bytes.length; seq++) {
      final end = (offset + capacity).clamp(0, bytes.length);
      result.add([
        0xa5,
        1,
        id & 255,
        id >> 8,
        seq,
        (offset == 0 ? 1 : 0) | (end == bytes.length ? 2 : 0),
        ...bytes.sublist(offset, end)
      ]);
      offset = end;
    }
    return result;
  }

  final List<int> _data = [];
  int? _id;
  int _sequence = 0;
  DateTime? _last;
  void reset() {
    _data.clear();
    _id = null;
    _sequence = 0;
    _last = null;
  }

  BleMessage? accept(List<int> frame, {DateTime? now}) {
    now ??= DateTime.now();
    if (_last != null && now.difference(_last!).inMilliseconds > 3000) reset();
    if (frame.length <= 6 ||
        frame[0] != 0xa5 ||
        frame[1] != 1 ||
        frame[5] & ~3 != 0) {
      reset();
      throw const FormatException('Cabecera BLE inválida');
    }
    final id = frame[2] | frame[3] << 8;
    if (frame[5] & 1 != 0) {
      reset();
      _id = id;
    }
    if (_id != id ||
        frame[4] != _sequence ||
        _data.length + frame.length - 6 > maxMessage) {
      reset();
      throw const FormatException(
          'Secuencia BLE incompleta o fuera de límites');
    }
    _data.addAll(frame.skip(6));
    _sequence++;
    _last = now;
    if (frame[5] & 2 == 0) return null;
    try {
      return BleMessage(id, utf8.decode(_data));
    } finally {
      reset();
    }
  }
}
