import 'package:flutter/material.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

class WalletScreen extends StatelessWidget {
  final HubController controller;
  const WalletScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    final available = controller.availablePoints;
    final pending = controller.pendingPoints;
    final progressToPublish = (available / 120).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.availablePoints,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '$available pts',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.pendingPoints,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '$pending pts',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meta para publicar campanha',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$available / 120 pts',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              LinearProgressIndicator(
                value: progressToPublish,
                minHeight: 8,
                backgroundColor: AppColors.surfaceElevated,
                color: available >= 120 ? AppColors.success : AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  const Icon(Icons.schedule_outlined, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(
                      strings.pointsExpirationNote,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        Text(
          'Extrato do ledger',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpace.sm),
        ...controller.ledger.map((entry) {
          final isPositive = entry.amount >= 0;
          final color = entry.bucket == 'pending'
              ? AppColors.warning
              : (isPositive ? AppColors.success : AppColors.danger);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: SectionCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.description,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          entry.bucket == 'pending' ? 'Em custódia' : 'Disponível',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${entry.amount} pts',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
