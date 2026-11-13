import 'package:flutter/material.dart';
import 'core/state/hub_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/onboarding_screen.dart';

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
              ? _HubPlaceholderShell(controller: controller)
              : OnboardingScreen(controller: controller),
        );
      },
    );
  }
}

class _HubPlaceholderShell extends StatelessWidget {
  final HubController controller;
  const _HubPlaceholderShell({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.strings.appTitle)),
      body: Center(
        child: Text(
          'Autenticado como ${controller.currentUser?.displayName ?? ''}',
        ),
      ),
    );
  }
}
