import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

class JoinCampaignStepperScreen extends StatefulWidget {
  final HubController controller;
  final String enrollmentId;

  const JoinCampaignStepperScreen({
    super.key,
    required this.controller,
    required this.enrollmentId,
  });

  @override
  State<JoinCampaignStepperScreen> createState() =>
      _JoinCampaignStepperScreenState();
}

class _JoinCampaignStepperScreenState extends State<JoinCampaignStepperScreen> {
  int _step = 0;
  bool _validating = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final enrollment = widget.controller.enrollments.firstWhere(
          (e) => e.id == widget.enrollmentId,
        );
        final campaign = enrollment.campaign;

        return Scaffold(
          appBar: AppBar(title: Text('Inscrição: ${campaign.app.name}')),
          body: Stepper(
            currentStep: _step,
            onStepTapped: (index) => setState(() => _step = index),
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: [
              Step(
                title: const Text('1. Entrar no Google Group da plataforma'),
                isActive: _step >= 0,
                state: enrollment.groupJoined ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Entre no grupo oficial com a mesma conta Google usada na Play Store. Isso evita compartilhar seu e-mail com terceiros.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.controller.nativeChannel.openExternalUrl(
                          HubController.googleGroupUrl,
                        );
                        await widget.controller.updateEnrollmentStep(
                          enrollment.id,
                          groupJoined: true,
                        );
                        setState(() => _step = 1);
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Abrir Google Group e avançar'),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('2. Aceitar convite no Play (Opt-in)'),
                isActive: _step >= 1,
                state: enrollment.optInAccepted ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Link: ${campaign.app.playOptInUrl}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpace.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.controller.nativeChannel.openExternalUrl(
                          campaign.app.playOptInUrl,
                        );
                        await widget.controller.updateEnrollmentStep(
                          enrollment.id,
                          optInAccepted: true,
                        );
                        setState(() => _step = 2);
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Tornar-se testador na Play Store'),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('3. Instalar app pela Play Store'),
                isActive: _step >= 2,
                state: enrollment.appInstalled ? StepState.complete : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Instale o app pelo link oficial da Play Store. O Hub detecta automaticamente quando o pacote aparece no dispositivo.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.controller.nativeChannel.openExternalUrl(
                          'market://details?id=${campaign.app.packageName}',
                        );
                        await widget.controller.updateEnrollmentStep(
                          enrollment.id,
                          appInstalled: true,
                        );
                        setState(() => _step = 3);
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Verificar instalação e avançar'),
                    ),
                  ],
                ),
              ),
              Step(
                title: const Text('4. Abrir pelo Hub e validar handshake'),
                isActive: _step >= 3,
                state: enrollment.status == EnrollmentStatus.active
                    ? StepState.complete
                    : StepState.indexed,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (enrollment.status == EnrollmentStatus.active) ...[
                      const StatusPill(
                        label: 'Handshake SDK confirmado · Inscrição ativa ✓',
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpace.md),
                      FilledButton(
                        onPressed: () {
                          widget.controller.setTab(1);
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                        child: const Text('Ir para Meus Testes'),
                      ),
                    ] else
                      FilledButton.icon(
                        key: const Key('validate_handshake_btn'),
                        onPressed: _validating
                            ? null
                            : () async {
                                setState(() => _validating = true);
                                await widget.controller
                                    .validateHandshakeAndActivate(enrollment.id);
                                if (mounted) {
                                  setState(() => _validating = false);
                                }
                              },
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(
                          _validating
                              ? 'Validando SDK...'
                              : 'Abrir app e validar SDK',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
