import 'package:hive/hive.dart';

class Session extends HiveObject {
  final String id;
  final String presetName;
  final DateTime date;
  final int durationSeconds;
  final int hz;
  final int pwm;
  final String patientName;
  final String stopReason;

  Session({
    required this.id,
    required this.presetName,
    required this.date,
    required this.durationSeconds,
    required this.hz,
    required this.pwm,
    required this.patientName,
    this.stopReason = SessionStopReason.manual,
  });

  String get stopReasonLabel {
    switch (stopReason) {
      case SessionStopReason.completed:
        return 'Completada';
      case SessionStopReason.lowBattery:
        return 'Bateria critica';
      case SessionStopReason.disconnected:
        return 'Desconexion';
      default:
        return 'Detenida manualmente';
    }
  }
}

class SessionStopReason {
  static const String manual = 'manual';
  static const String completed = 'completed';
  static const String lowBattery = 'low_battery';
  static const String disconnected = 'disconnected';
}

class SessionAdapter extends TypeAdapter<Session> {
  @override
  final int typeId = 0;

  @override
  Session read(BinaryReader reader) {
    final id = reader.readString();
    final presetName = reader.readString();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final durationSeconds = reader.readInt();
    final hz = reader.readInt();
    final pwm = reader.readInt();
    final patientName = reader.readString();

    String stopReason = SessionStopReason.manual;
    try {
      stopReason = reader.readString();
    } catch (_) {
      stopReason = SessionStopReason.manual;
    }

    return Session(
      id: id,
      presetName: presetName,
      date: date,
      durationSeconds: durationSeconds,
      hz: hz,
      pwm: pwm,
      patientName: patientName,
      stopReason: stopReason,
    );
  }

  @override
  void write(BinaryWriter writer, Session obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.presetName);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeInt(obj.durationSeconds);
    writer.writeInt(obj.hz);
    writer.writeInt(obj.pwm);
    writer.writeString(obj.patientName);
    writer.writeString(obj.stopReason);
  }
}
