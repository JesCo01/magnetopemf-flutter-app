import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/patient.dart';

class PatientState {
  final List<Patient> patients;
  final Patient? activePatient;
  final bool isLoading;

  PatientState(
      {this.patients = const [], this.activePatient, this.isLoading = true});

  PatientState copyWith(
      {List<Patient>? patients, Patient? activePatient, bool? isLoading}) {
    return PatientState(
      patients: patients ?? this.patients,
      activePatient: activePatient ?? this.activePatient,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PatientNotifier extends StateNotifier<PatientState> {
  PatientNotifier() : super(PatientState()) {
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('saved_patients');

    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final patients = decoded.map((p) => Patient.fromJson(p)).toList();
        // Sort newest first
        patients.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(patients: patients, isLoading: false);
      } catch (e) {
        debugPrint("Error parsing patients: $e");
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addPatient(String name, int age, String condition) async {
    final newPatient = Patient(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      age: age,
      condition: condition,
      createdAt: DateTime.now(),
    );

    final updated = [newPatient, ...state.patients];
    state = state.copyWith(patients: updated);
    await _saveToPrefs(updated);
  }

  Future<void> deletePatient(String id) async {
    final updated = state.patients.where((p) => p.id != id).toList();

    // Clear active patient if it was deleted
    Patient? newActive = state.activePatient;
    if (newActive?.id == id) {
      newActive = null;
    }

    state = state.copyWith(patients: updated, activePatient: newActive);
    await _saveToPrefs(updated);
  }

  void setActivePatient(Patient patient) {
    state = state.copyWith(activePatient: patient);
  }

  Future<void> setOmittedPatient() async {
    const dummyId = 'omitted_anon';
    Patient? dummy;

    try {
      dummy = state.patients.firstWhere((p) => p.id == dummyId);
    } catch (_) {
      dummy = Patient(
        id: dummyId,
        name: 'Paciente Anónimo',
        age: 0,
        condition: 'Terapia Rápida (Anónimo)',
        createdAt: DateTime.now(),
      );
      final updated = [dummy, ...state.patients];
      state = state.copyWith(patients: updated);
      await _saveToPrefs(updated);
    }

    setActivePatient(dummy);
  }

  Future<void> _saveToPrefs(List<Patient> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((p) => p.toJson()).toList();
    await prefs.setString('saved_patients', jsonEncode(jsonList));
  }
}

final patientProvider =
    StateNotifierProvider<PatientNotifier, PatientState>((ref) {
  return PatientNotifier();
});
