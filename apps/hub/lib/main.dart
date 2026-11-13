import 'package:flutter/material.dart';
import 'core/state/hub_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/enrollment/my_tests_screen.dart';
import 'features/wallet/wallet_screen.dart';

void main() {
  runApp(TesterLoopHubApp(controller: HubController()));
}

class TesterLoopHubApp extends StatelessWidget {
  final HubController controller;
  const TesterLoopHubApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: controller.strings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: controller.isAuthenticated
              ? HubHomeShell(controller: controller)
              : OnboardingScreen(controller: controller),
        );
      },
    );
  }
}

class HubHomeShell extends StatelessWidget {
  final HubController controller;
  const HubHomeShell({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final idx = controller.selectedTabIndex.clamp(0, 4);
    final pages = [
      DiscoverScreen(controller: controller),
      MyTestsScreen(controller: controller),
      WalletScreen(controller: controller),
      const Center(child: Text('Meus Apps')),
      const Center(child: Text('Ajustes')),
    ];

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.lg),
            child: Chip(
              label: Text(
                '${controller.availablePoints} pts',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: idx,
                  onDestinationSelected: controller.setTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.explore_outlined),
                      label: Text(s.discover),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(s.myTests),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(s.wallet),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.apps_outlined),
                      label: Text(s.myApps),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(s.settings),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[idx]),
              ],
            )
          : pages[idx],
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: idx,
              onDestinationSelected: controller.setTab,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  label: s.discover,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: s.myTests,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: s.wallet,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.apps_outlined),
                  label: s.myApps,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: s.settings,
                ),
              ],
            ),
    );
  }
}
