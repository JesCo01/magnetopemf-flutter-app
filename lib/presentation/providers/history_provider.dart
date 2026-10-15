import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/session.dart';
import '../../data/repositories/session_repository.dart';

final historyProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getSessions();
});
