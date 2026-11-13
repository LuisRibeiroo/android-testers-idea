import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

Future<void> showFeaturedBookingSheet(
  BuildContext context,
  HubController controller,
  Campaign campaign,
) async {
  FeaturedPackage selected = HubController.featuredPackages.first;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.xl,
          AppSpace.xl,
          AppSpace.xl + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.featuredGold),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Destacar ${campaign.app.name}',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Reserva o próximo slot livre (1 a 3) no topo do Descobrir via Google Play Billing. O preço final dos blocos segue configurável (OQ-9).',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.lg),
            ...HubController.featuredPackages.map((pkg) {
              final active = pkg.id == selected.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: SectionCard(
                  onTap: () => setLocal(() => selected = pkg),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: active ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          pkg.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        pkg.referencePrice,
                        style: const TextStyle(
                          color: AppColors.featuredGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              key: const Key('confirm_featured_btn'),
              onPressed: () {
                controller.bookFeaturedSlot(campaign.id, selected);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${campaign.app.name} destacado por ${selected.label}!',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bolt_rounded),
              label: Text('Reservar slot (${selected.label})'),
            ),
          ],
        ),
      ),
    ),
  );
}
