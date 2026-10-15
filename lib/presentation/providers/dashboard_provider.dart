import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/preset.dart';
import '../../domain/models/session.dart';
import 'app_alert_provider.dart';
import 'ble_provider.dart';
import 'history_provider.dart';
import 'patient_provider.dart';

const int _defaultPwmPercent = 10;
const int _minPwmPercent = 0;
const int _maxPwmPercent = 90;
int _normalizePwmPercent(int pwm) => pwm.clamp(_minPwmPercent, _maxPwmPercent);

class DashboardState {
  final bool isRunning;
  final bool isBusy;
  final int totalSeconds;
  final int currentSeconds;
  final int hz;
  final int pwm;
  final int waveform;
  final int? draftHz;
  final int? draftPwm;
  final String presetName;
  final bool isPaused;

  int get timeMinutes => totalSeconds ~/ 60;
  int get manualHz => draftHz ?? hz;
  int get manualPwm => draftPwm ?? pwm;
  bool get hasPendingManualChanges => draftHz != null || draftPwm != null;
  bool get isSessionActive => isRunning || isPaused;

  const DashboardState({
    this.isRunning = false,
    this.isBusy = false,
    this.isPaused = false,
    this.totalSeconds = 300,
    this.currentSeconds = 300,
    this.hz = 50,
    this.pwm = _defaultPwmPercent,
    this.waveform = 4,
    this.draftHz,
    this.draftPwm,
    this.presetName = 'Ajuste Manual',
  });

  DashboardState copyWith({
    bool? isRunning,
    bool? isBusy,
    bool? isPaused,
    int? totalSeconds,
    int? currentSeconds,
    int? hz,
    int? pwm,
    int? waveform,
    int? draftHz,
    int? draftPwm,
    String? presetName,
    bool clearDraftHz = false,
    bool clearDraftPwm = false,
  }) {
    return DashboardState(
      isRunning: isRunning ?? this.isRunning,
      isBusy: isBusy ?? this.isBusy,
      isPaused: isPaused ?? this.isPaused,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      currentSeconds: currentSeconds ?? this.currentSeconds,
      hz: hz ?? this.hz,
      pwm: _normalizePwmPercent(pwm ?? this.pwm),
      waveform: waveform ?? this.waveform,
      draftHz: clearDraftHz ? null : (draftHz ?? this.draftHz),
      draftPwm: clearDraftPwm
          ? null
          : (draftPwm != null ? _normalizePwmPercent(draftPwm) : this.draftPwm),
      presetName: presetName ?? this.presetName,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  Timer? _timer;
  bool _closing = false;
  final SessionRepository _sessionRepository;
  final Ref _ref;

  DashboardNotifier(this._sessionRepository, this._ref)
      : super(const DashboardState());

  DashboardState get snapshot => state;

  Future<bool> toggleTherapy() async {
    if (state.isBusy) return false;

    if (!state.isRunning) {
      return startTherapy();
    } else if (state.isPaused) {
      return resumeTherapy();
    } else {
      return pauseTherapy();
    }
  }

  Future<bool> startTherapy() async {
    if (state.isRunning || !_ref.read(bleProvider).isProtocolReady) {
      return false;
    }
    if (state.isBusy) return false;
    if (_hasCriticalBatteryLevel()) {
      _showCriticalBatteryAlert(
        percentage: _ref.read(bleProvider).batteryPercentage,
      );
      return false;
    }

    final durationMins = state.totalSeconds ~/ 60;
    final commandData = <String, dynamic>{
      'cmd': 'start',
      'duration': durationMins,
      'freq': state.hz,
      'intensity': state.pwm.toDouble(),
      'wave': state.waveform,
    };
    final command = jsonEncode(commandData);

    return _runBusyAction(() async {
      final response =
          await _ref.read(bleProvider.notifier).sendCommandAndAwaitResponse(
                command,
                accept: _acceptStartResponse,
              );

      if (!_isStartedResponse(response)) {
        _handleStartFailure(response);
        return false;
      }

      state = state.copyWith(
        isRunning: true,
        isPaused: false,
        currentSeconds: state.totalSeconds,
        clearDraftHz: true,
        clearDraftPwm: true,
      );
      _startTimer();
      unawaited(_saveRecoveryState());
      return true;
    });
  }

  Future<bool> pauseTherapy() async {
    if (state.isBusy) return false;

    return _runBusyAction(() async {
      final paused =
          await _ref.read(bleProvider.notifier).sendCommandAndAwaitResponse(
                jsonEncode({'cmd': 'pause'}),
                accept: _acceptPauseResponse,
              );
      if (!_isPausedResponse(paused)) {
        _handlePauseFailure(paused);
        return false;
      }

      _timer?.cancel();
      state = state.copyWith(
        isPaused: true,
        currentSeconds:
            _extractRemainingSeconds(paused) ?? state.currentSeconds,
      );
      return true;
    });
  }

  Future<bool> resumeTherapy({bool applyPending = false}) async {
    if (!state.isPaused || !_ref.read(bleProvider).isProtocolReady) {
      return false;
    }
    if (state.isBusy) return false;
    if (_hasCriticalBatteryLevel()) {
      _showCriticalBatteryAlert(
        percentage: _ref.read(bleProvider).batteryPercentage,
      );
      return false;
    }

    final requestedHz = state.manualHz;
    final requestedPwm = state.manualPwm;
    final commandData = <String, dynamic>{'cmd': 'resume'};
    if (applyPending) {
      commandData['freq'] = requestedHz;
      commandData['intensity'] = requestedPwm.toDouble();
      commandData['wave'] =
          4; // Al alterar manualmente, forzamos onda cuadrada (PWM puro)
    }
    final command = jsonEncode(commandData);

    return _runBusyAction(() async {
      final resumed =
          await _ref.read(bleProvider.notifier).sendCommandAndAwaitResponse(
                command,
                accept: _acceptResumeResponse,
              );
      if (!_isResumedResponse(resumed)) {
        _handleResumeFailure(resumed);
        return false;
      }

      if (!applyPending && state.hasPendingManualChanges) {
        _ref.read(appAlertProvider.notifier).info(
              'Cambios descartados',
              'La terapia se reanudo con los parametros activos.',
            );
      }

      state = state.copyWith(
        hz: applyPending ? requestedHz : state.hz,
        pwm: applyPending ? requestedPwm : state.pwm,
        waveform: applyPending ? 4 : state.waveform,
        isPaused: false,
        currentSeconds:
            _extractRemainingSeconds(resumed) ?? state.currentSeconds,
        clearDraftHz: true,
        clearDraftPwm: true,
      );
      if (applyPending) {
        _ref.read(appAlertProvider.notifier).success(
              'Tratamiento actualizado',
              'Los nuevos parametros fueron aplicados y la terapia continua.',
            );
      }
      _startTimer();
      return true;
    });
  }

  Future<bool> updateTreatmentAndResume() {
    if (!state.isRunning || !state.isPaused) return Future.value(false);
    return resumeTherapy(applyPending: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.currentSeconds > 0) {
        state = state.copyWith(currentSeconds: state.currentSeconds - 1);
      } else {
        _timer?.cancel();
        unawaited(_ref.read(bleProvider.notifier).queryStatus());
      }
    });
  }

  Future<void> stopTherapy({
    String reason = SessionStopReason.manual,
    bool sendStopCommand = true,
  }) async {
    if (_closing) return;
    _closing = true;
    try {
      if (sendStopCommand) {
        state = state.copyWith(isBusy: true);
        final response = await _ref
            .read(bleProvider.notifier)
            .sendCommandAndAwaitResponse(jsonEncode({'cmd': 'stop'}),
                accept: (s) {
          final data = _tryDecodeMessage(s);
          return data?['ok'] == 'stopped' || data?['error'] != null;
        });
        var confirmed = _tryDecodeMessage(response)?['ok'] == 'stopped';
        if (!confirmed) {
          final status = await _ref.read(bleProvider.notifier).queryStatus();
          confirmed = status?['state'] == 'IDLE';
        }
        if (!confirmed) {
          _ref.read(appAlertProvider.notifier).warning('Parada sin confirmar',
              'No se ha confirmado el estado del equipo. Restablece la conexión.');
          return;
        }
      }
      _timer?.cancel();
      if (state.isRunning) {
        final patientState = _ref.read(patientProvider);
        final patientName =
            patientState.activePatient?.name ?? 'Paciente Desconocido';
        final elapsedSeconds = state.totalSeconds - state.currentSeconds;

        final session = Session(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          presetName: state.presetName,
          date: DateTime.now(),
          durationSeconds: elapsedSeconds,
          hz: state.hz,
          pwm: state.pwm,
          patientName: patientName,
          stopReason: reason,
        );

        await _sessionRepository.saveSession(session);
        _ref.invalidate(historyProvider);
      }

      state = state.copyWith(
        isRunning: false,
        isBusy: false,
        isPaused: false,
        currentSeconds: state.totalSeconds,
        clearDraftHz: true,
        clearDraftPwm: true,
      );
    } finally {
      _closing = false;
      if (mounted) state = state.copyWith(isBusy: false);
    }
  }

  Future<void> handleRemoteStop({
    required String reason,
    required String title,
    required String message,
  }) async {
    if (!state.isRunning) return;

    await stopTherapy(
      reason: reason,
      sendStopCommand: false,
    );

    final alertNotifier = _ref.read(appAlertProvider.notifier);
    if (reason == SessionStopReason.lowBattery) {
      alertNotifier.critical(title, message, persistent: true);
    } else {
      alertNotifier.warning(title, message);
    }
  }

  void updateParams({int? hz, int? pwm, int? timeMinutes}) {
    timeMinutes = timeMinutes?.clamp(1, 10);
    if (hz != null) {
      if (state.isRunning && state.isPaused) {
        final nextHz = hz.clamp(10, 100);
        if (state.manualHz != nextHz) {
          state = nextHz == state.hz
              ? state.copyWith(
                  presetName: 'Ajuste Manual',
                  clearDraftHz: true,
                )
              : state.copyWith(
                  draftHz: nextHz,
                  presetName: 'Ajuste Manual',
                );
        }
      } else if (!state.isRunning && state.hz != hz) {
        state = state.copyWith(
          hz: hz.clamp(10, 100),
          presetName: 'Ajuste Manual',
          waveform: 4,
        );
      }
    }

    final normalizedPwm = pwm?.clamp(10, 90);
    if (normalizedPwm != null) {
      if (state.isRunning && state.isPaused) {
        if (state.manualPwm != normalizedPwm) {
          state = normalizedPwm == state.pwm
              ? state.copyWith(
                  presetName: 'Ajuste Manual',
                  clearDraftPwm: true,
                )
              : state.copyWith(
                  draftPwm: normalizedPwm,
                  presetName: 'Ajuste Manual',
                );
        }
      } else if (!state.isRunning && state.pwm != normalizedPwm) {
        state = state.copyWith(
          pwm: normalizedPwm,
          presetName: 'Ajuste Manual',
          waveform: 4,
        );
      }
    }

    if (timeMinutes != null &&
        !state.isRunning &&
        (state.totalSeconds ~/ 60) != timeMinutes) {
      state = state.copyWith(
        totalSeconds: timeMinutes * 60,
        currentSeconds: timeMinutes * 60,
        presetName: 'Ajuste Manual',
        waveform: 4,
        isPaused: false,
      );
    }
  }

  Future<bool> applyPreset(Preset preset) async {
    if (state.isBusy || ![0, 3, 4].contains(preset.waveform)) return false;

    if (state.isRunning) {
      await stopTherapy(reason: SessionStopReason.manual);
      if (state.isRunning) return false;
    }

    state = state.copyWith(
      hz: preset.hz,
      pwm: _normalizePwmPercent(preset.pwm),
      waveform: preset.waveform,
      totalSeconds: preset.durationSeconds,
      currentSeconds: preset.durationSeconds,
      presetName: preset.name,
      isPaused: false,
      clearDraftHz: true,
      clearDraftPwm: true,
    );
    return true;
  }

  Future<void> _saveRecoveryState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recovery_total_secs', state.totalSeconds);
    await prefs.setString('recovery_preset', state.presetName);
  }

  void applyRemoteStatus(Map<String, dynamic> data) {
    final remote = data['state'];
    final channels = data['channels'];
    if (channels is! List || channels.isEmpty || channels.first is! Map) return;
    final channel = channels.first as Map;
    final remaining = (data['remaining_sec'] as num?)?.toInt() ?? 0;
    if (remote == 'RUNNING' || remote == 'PAUSED') {
      final wasPaused = state.isPaused;
      state = state.copyWith(
          isRunning: true,
          isPaused: remote == 'PAUSED',
          currentSeconds: remaining,
          totalSeconds:
              (data['total_sec'] as num?)?.toInt() ?? state.totalSeconds,
          hz: (channel['freq'] as num?)?.toInt(),
          pwm: (channel['duty_pct'] as num?)?.round(),
          waveform: (channel['wave'] as num?)?.toInt(),
          // Preserve edits during a paused session; they are not active parameters.
          clearDraftHz: !wasPaused || remote != 'PAUSED',
          clearDraftPwm: !wasPaused || remote != 'PAUSED');
      if (remote == 'PAUSED') {
        _timer?.cancel();
      } else {
        _startTimer();
      }
    } else if (remote == 'IDLE' && state.isRunning) {
      final elapsed = (data['elapsed_sec'] as num?)?.toInt();
      if (elapsed != null) {
        state = state.copyWith(
            currentSeconds:
                (state.totalSeconds - elapsed).clamp(0, state.totalSeconds));
      }
      unawaited(stopTherapy(
          reason: data['stop_reason'] as String? ?? SessionStopReason.manual,
          sendStopCommand: false));
    }
  }

  void connectionLost() {
    _timer?.cancel();
    // Keep the record open until the device reports its terminal state.
    if (state.isRunning) state = state.copyWith(isPaused: true, isBusy: false);
    _ref.read(appAlertProvider.notifier).warning('Conexión perdida',
        'El equipo dispone de parada por desconexión. El registro se confirmará al reconectar.');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<T> _runBusyAction<T>(Future<T> Function() action) async {
    state = state.copyWith(isBusy: true);
    try {
      return await action();
    } finally {
      if (mounted) {
        state = state.copyWith(isBusy: false);
      }
    }
  }

  bool _hasCriticalBatteryLevel() {
    final percentage = _ref.read(bleProvider).batteryPercentage;
    return percentage >= 0 && percentage < 5;
  }

  bool _acceptStartResponse(String message) {
    final data = _tryDecodeMessage(message);
    if (data == null) return false;

    return data['ok'] == 'started' ||
        data['action'] == 'start_blocked' ||
        data.containsKey('error');
  }

  bool _acceptPauseResponse(String message) {
    final data = _tryDecodeMessage(message);
    if (data == null) return false;

    return data['ok'] == 'paused' || data.containsKey('error');
  }

  bool _acceptResumeResponse(String message) {
    final data = _tryDecodeMessage(message);
    if (data == null) return false;

    return data['ok'] == 'resumed' ||
        data['action'] == 'resume_blocked' ||
        data.containsKey('error');
  }

  bool _isStartedResponse(String? message) {
    final data = _tryDecodeMessage(message);
    return data?['ok'] == 'started';
  }

  bool _isPausedResponse(String? message) {
    final data = _tryDecodeMessage(message);
    return data?['ok'] == 'paused';
  }

  bool _isResumedResponse(String? message) {
    final data = _tryDecodeMessage(message);
    return data?['ok'] == 'resumed';
  }

  void _handleStartFailure(String? response) {
    final data = _tryDecodeMessage(response);
    if (data == null) return;

    if (data['error'] == 'LOW_BAT' || data['action'] == 'start_blocked') {
      final battery = (data['bat'] as num?)?.toInt();
      _showCriticalBatteryAlert(percentage: battery);
    }
  }

  void _handlePauseFailure(String? response) {
    final data = _tryDecodeMessage(response);
    if (data != null && data['action'] == 'pause_failed') {
      _ref.read(appAlertProvider.notifier).warning(
            'No se pudo pausar',
            'La terapia no entro en pausa. Intenta nuevamente desde Panel.',
          );
      return;
    }

    _ref.read(appAlertProvider.notifier).warning(
          'No se pudo pausar',
          'No se recibio confirmacion de pausa desde el equipo.',
        );
  }

  void _handleResumeFailure(String? response) {
    final data = _tryDecodeMessage(response);
    if (data == null) return;

    if (data['error'] == 'LOW_BAT' || data['action'] == 'resume_blocked') {
      final battery = (data['bat'] as num?)?.toInt();
      _showCriticalBatteryAlert(percentage: battery);
      return;
    }

    _ref.read(appAlertProvider.notifier).warning(
          'No se pudo reanudar',
          'La terapia no pudo reanudarse con los parametros solicitados.',
        );
  }

  void _showCriticalBatteryAlert({int? percentage}) {
    final suffix = percentage != null && percentage >= 0
        ? ' La bateria esta en $percentage%.'
        : '';
    _ref.read(appAlertProvider.notifier).critical(
          'Inicio bloqueado',
          'No se puede iniciar ni reanudar la terapia por bateria critica.$suffix Recarga el equipo antes de continuar.',
        );
  }

  Map<String, dynamic>? _tryDecodeMessage(String? message) {
    if (message == null) return null;

    try {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {}

    return null;
  }

  int? _extractRemainingSeconds(String? message) {
    final data = _tryDecodeMessage(message);
    final remaining = data?['remaining_sec'];
    if (remaining is num) return remaining.toInt();
    return null;
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final notifier = DashboardNotifier(sessionRepo, ref);

  ref.listen<BleState>(bleProvider, (prev, next) {
    if (prev?.connectedDevice != null && next.connectedDevice == null) {
      notifier.connectionLost();
      return;
    }
    if (next.lastMessage == null || next.lastMessage == prev?.lastMessage) {
      return;
    }
    try {
      final data = jsonDecode(next.lastMessage!);
      if (data is Map<String, dynamic> && data['state'] is String) {
        notifier.applyRemoteStatus(data);
      }
    } catch (_) {}
  });
  return notifier;
});
