import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/patient.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/devices_screen.dart';
import '../../presentation/screens/main_layout.dart';
import '../../presentation/screens/manual_screen.dart';
import '../../presentation/screens/patient_history_screen.dart';
import '../../presentation/screens/patients_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'root_scaffold_messenger');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final goRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/manual',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const ManualScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/devices',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const DevicesScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/config',
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const PatientsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/patient-history',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) {
        final patient = state.extra as Patient;
        return CustomTransitionPage(
          child: PatientHistoryScreen(patient: patient),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
    ),
  ],
);
