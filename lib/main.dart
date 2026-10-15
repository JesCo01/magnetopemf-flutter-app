import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/session.dart';
import 'presentation/providers/app_alert_provider.dart';
import 'presentation/widgets/app_alert_snackbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(SessionAdapter());

  runApp(const ProviderScope(child: MagnetoProApp()));
}

class MagnetoProApp extends ConsumerWidget {
  const MagnetoProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppAlertEvent?>(appAlertProvider, (prev, next) {
      if (next == null || next.id == prev?.id) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) return;

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(buildAppAlertSnackBar(context, next));
      });
    });

    return MaterialApp.router(
      title: 'Magneto Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: goRouter,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
    );
  }
}
