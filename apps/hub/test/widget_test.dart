import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testerloop_hub/core/state/hub_controller.dart';
import 'package:testerloop_hub/main.dart';

void main() {
  testWidgets('Onboarding signs in and awards welcome bonus', (tester) async {
    final controller = HubController();
    await tester.pumpWidget(TesterLoopHubApp(controller: controller));

    expect(find.text('TesterLoop Hub'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google_signin_btn')));
    await tester.pumpAndSettle();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.availablePoints, 135); // 125 seed + 10 welcome
  });
}
