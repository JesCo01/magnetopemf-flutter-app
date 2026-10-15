import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../domain/models/session.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

class SessionRepository {
  static const String boxName = 'sessions_box';

  Future<void> saveSession(Session session) async {
    final box = await Hive.openBox<Session>(boxName);
    await box.put(session.id, session);
  }

  Future<List<Session>> getSessions() async {
    final box = await Hive.openBox<Session>(boxName);
    final sessions = box.values.toList();
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions;
  }
}
