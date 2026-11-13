import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../enrollment/join_campaign_stepper_screen.dart';

class CampaignDetailScreen extends StatelessWidget {
  final HubController controller;
  final Campaign campaign;

  const CampaignDetailScreen({
    super.key,
    required this.controller,
    required this.campaign,
  });

  @override
  Widget build(BuildContext context) {
    final enrollment = controller.enrollmentForCampaign(campaign.id);
    return Scaffold(
      appBar: AppBar(title: Text(campaign.app.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: campaign.app.category,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    const StatusPill(
                      label: 'SDK Verificado',
                      color: AppColors.success,
                      icon: Icons.verified_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  campaign.app.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  campaign.app.packageName,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  campaign.app.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regras da campanha',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpace.md),
                _RuleRow(
                  icon: Icons.people_outline,
                  label: 'Vagas ocupadas',
                  value: '${campaign.totalJoined}/${campaign.slots} (+${campaign.bufferSlots} reserva)',
                ),
                const SizedBox(height: AppSpace.sm),
                _RuleRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Duração contínua',
                  value: '${campaign.requiredDays} dias (mín. ${campaign.minActiveDays} ativos)',
                ),
                const SizedBox(height: AppSpace.sm),
                const _RuleRow(
                  icon: Icons.timer_outlined,
                  label: 'Uso diário exigido',
                  value: '≥ 60s em foreground',
                ),
                const SizedBox(height: AppSpace.sm),
                _RuleRow(
                  icon: Icons.toll_outlined,
                  label: 'Recompensa',
                  value: '+${campaign.requiredDays} pts + 3 bônus (+2 feedback)',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            key: const Key('join_campaign_btn'),
            onPressed: () {
              final activeOrNew = enrollment ?? controller.startEnrollment(campaign);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinCampaignStepperScreen(
                    controller: controller,
                    enrollmentId: activeOrNew.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              enrollment != null
                  ? 'Continuar inscrição'
                  : controller.strings.wantToTest,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
