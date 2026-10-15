import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/bottom_nav_bar.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.startsWith('/manual')) currentIndex = 1;
    if (location.startsWith('/devices')) currentIndex = 2;
    if (location.startsWith('/config')) currentIndex = 3;

    return Scaffold(
      body: Stack(
        children: [
          child,
          BottomNavBar(currentIndex: currentIndex),
        ],
      ),
    );
  }
}
