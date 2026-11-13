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

    await tester.tap(find.text('BoletoScan OCR'));
    await tester.pumpAndSettle();

    expect(find.text('Regras da campanha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('join_campaign_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir Google Group e avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tornar-se testador na Play Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verificar instalação e avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('validate_handshake_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Handshake SDK confirmado · Inscrição ativa ✓'), findsOneWidget);

    await tester.tap(find.text('Ir para Meus Testes'));
    await tester.pumpAndSettle();

    final enr = controller.enrollments.first;
    await tester.tap(find.byKey(Key('launch_session_${enr.id}')));
    await tester.pumpAndSettle();
    expect(controller.pendingPoints, 5);

    await tester.tap(find.text('Carteira'));
    await tester.pumpAndSettle();
    expect(find.textContaining('360 dias'), findsOneWidget);
  });

  testWidgets('Developer validates SDK in 2 steps, publishes campaign and opens report',
      (tester) async {
    final controller = HubController(
      nativeChannel: const HubNativeChannel(simulated: true),
    );
    await controller.signInWithGoogle();
    await tester.pumpWidget(TesterLoopHubApp(controller: controller));
    await tester.pumpAndSettle();

    // Navigate to My Apps
    await tester.tap(find.text('Meus Apps'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HabitoLoop'));
    await tester.pumpAndSettle();

    final ownedApp = controller.myApps.first;
    await tester.tap(find.byKey(Key('validate_debug_${ownedApp.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('validate_play_${ownedApp.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('publish_campaign_${ownedApp.id}')));
    await tester.pumpAndSettle();

    expect(controller.availablePoints, 15); // 135 - 120 campaign cost
    expect(controller.campaignForApp(ownedApp.id), isNotNull);

    await tester.tap(find.byKey(Key('report_btn_${ownedApp.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Relatório para Acesso à Produção'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    // Check Settings and Reddit community link
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('r/AndroidAppTesters'), findsOneWidget);
  });
}
