import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppAlertSeverity { info, success, warning, critical }

class AppAlertEvent {
  final int id;
  final String title;
  final String message;
  final AppAlertSeverity severity;
  final bool persistent;

  const AppAlertEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.persistent = false,
  });
}

class AppAlertNotifier extends StateNotifier<AppAlertEvent?> {
  AppAlertNotifier() : super(null);

  int _nextId = 0;

  void show({
    required String title,
    required String message,
    required AppAlertSeverity severity,
    bool persistent = false,
  }) {
    state = AppAlertEvent(
      id: ++_nextId,
      title: title,
      message: message,
      severity: severity,
      persistent: persistent,
    );
  }

  void info(String title, String message) {
    show(title: title, message: message, severity: AppAlertSeverity.info);
  }

  void success(String title, String message) {
    show(title: title, message: message, severity: AppAlertSeverity.success);
  }

  void warning(String title, String message) {
    show(title: title, message: message, severity: AppAlertSeverity.warning);
  }

  void critical(
    String title,
    String message, {
    bool persistent = false,
  }) {
    show(
      title: title,
      message: message,
      severity: AppAlertSeverity.critical,
      persistent: persistent,
    );
  }
}

final appAlertProvider =
    StateNotifierProvider<AppAlertNotifier, AppAlertEvent?>((ref) {
  return AppAlertNotifier();
});
