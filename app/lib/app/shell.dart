import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/l10n.dart';

/// Bottom navigation: Home | Customers | Records | More.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab returns to its first screen.
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: l.navCustomers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l.navRecords,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_rounded),
            selectedIcon: const Icon(Icons.menu_open_rounded),
            label: l.navMore,
          ),
        ],
      ),
    );
  }
}
