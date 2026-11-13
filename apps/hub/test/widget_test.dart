import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testerloop_hub/core/native/hub_native_channel.dart';
import 'package:testerloop_hub/core/state/hub_controller.dart';
import 'package:testerloop_hub/main.dart';

void main() {
  testWidgets('Onboarding signs in and awards welcome bonus', (tester) async {
    final controller = HubController(
      nativeChannel: const HubNativeChannel(simulated: true),
    );
    await tester.pumpWidget(TesterLoopHubApp(controller: controller));

    expect(find.text('TesterLoop Hub'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google_signin_btn')));
    await tester.pumpAndSettle();

    expect(controller.isAuthenticated, isTrue);
    expect(controller.availablePoints, 135); // 125 seed + 10 welcome
  });

  testWidgets('Tester discovers campaign, joins 4-step flow and checks wallet',
      (tester) async {
    final controller = HubController(
      nativeChannel: const HubNativeChannel(simulated: true),
    );
    await controller.signInWithGoogle();
    await tester.pumpWidget(TesterLoopHubApp(controller: controller));
    await tester.pumpAndSettle();

    // Open BoletoScan OCR campaign detail
    await tester.tap(find.text('BoletoScan OCR'));
    await tester.pumpAndSettle();

    expect(find.text('Regras da campanha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join_campaign_btn')));
    await tester.pumpAndSettle();

    // Advance stepper to step 4 and validate SDK handshake
    await tester.tap(find.text('Abrir Google Group e avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar-se testador na Play Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verificar instalação e avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('validate_handshake_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Handshake SDK confirmado · Inscrição ativa ✓'), findsOneWidget);

    // Go to My Tests and validate 60s daily session
    await tester.tap(find.text('Ir para Meus Testes'));
    await tester.pumpAndSettle();

    final enr = controller.enrollments.first;
    await tester.tap(find.byKey(Key('launch_session_${enr.id}')));
    await tester.pumpAndSettle();
    expect(enr.id, isNotEmpty);
    expect(controller.pendingPoints, 5); // 4 seed + 1 newly validated day

    // Check Wallet displays 360-day expiration notice
    await tester.tap(find.text('Carteira'));
    await tester.pumpAndSettle();
    expect(find.textContaining('360 dias'), findsOneWidget);
  });
}
