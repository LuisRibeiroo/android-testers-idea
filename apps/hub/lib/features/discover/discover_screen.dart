import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../campaign_detail/campaign_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final HubController controller;
  const DiscoverScreen({super.key, required this.controller});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  int _feedIndex = 0; // 0 = Recentes, 1 = Quase completos

  List<Campaign> _filter(List<Campaign> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where((c) =>
            c.app.name.toLowerCase().contains(q) ||
            c.app.packageName.toLowerCase().contains(q) ||
            c.app.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.controller.strings;
    final featured = widget.controller.featuredCampaigns;
    final list = _filter(
      _feedIndex == 0
          ? widget.controller.recentCampaigns
          : widget.controller.almostFullCampaigns,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        TextField(
          key: const Key('discover_search_input'),
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: strings.searchApps,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        if (featured.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.featuredGold, size: 20),
              const SizedBox(width: AppSpace.xs),
              Text(
                '${strings.featured} (3 slots)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
              itemBuilder: (context, index) {
                final c = featured[index];
                return SizedBox(
                  width: 270,
                  child: SectionCard(
                    onTap: () => _openDetail(context, c),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusPill(
                              label: 'Slot #${c.featuredSlot}',
                              color: AppColors.featuredGold,
                              icon: Icons.bolt_rounded,
                            ),
                            const Spacer(),
                            StatusPill(
                              label: '${c.totalJoined}/${c.slots}',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          c.app.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            c.app.shortDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ),
                        Text(
                          '+${c.rewardPoints} pts · ${c.requiredDays}d',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.xl),
        ],
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(strings.recent)),
            ButtonSegment(value: 1, label: Text(strings.almostFull)),
          ],
          selected: {_feedIndex},
          onSelectionChanged: (s) => setState(() => _feedIndex = s.first),
        ),
        const SizedBox(height: AppSpace.md),
        if (list.isEmpty)
          SectionCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(
                  'Nenhuma campanha encontrada para "$_query".',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          )
        else
          ...list.map((c) {
            final enrolled = widget.controller.isEnrolledIn(c.id);
            final ratio = (c.totalJoined / c.slots).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: SectionCard(
                onTap: () => _openDetail(context, c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c.app.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.app.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '${c.app.category} · ${c.app.packageName}',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (enrolled)
                          StatusPill(
                            label: strings.alreadyEnrolled,
                            color: AppColors.success,
                          )
                        else
                          StatusPill(
                            label: '+${c.rewardPoints} pts',
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      c.app.shortDescription,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpace.md),
                    LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppColors.surfaceElevated,
                      color: ratio >= 0.7 ? AppColors.success : AppColors.primary,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${c.totalJoined}/${c.slots} vagas (+${c.bufferSlots} reserva)',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '${c.requiredDays} dias contínuos',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _openDetail(BuildContext context, Campaign campaign) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(
          controller: widget.controller,
          campaign: campaign,
        ),
      ),
    );
  }
}
