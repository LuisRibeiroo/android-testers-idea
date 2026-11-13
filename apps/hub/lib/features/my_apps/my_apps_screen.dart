import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../featured/featured_booking_sheet.dart';

class MyAppsScreen extends StatelessWidget {
  final HubController controller;
  const MyAppsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final strings = controller.strings;
    final apps = controller.myApps;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.myApps,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            FilledButton.icon(
              key: const Key('new_app_btn'),
              onPressed: () => _showNewAppSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(strings.newApp),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        ...apps.map((app) {
          final campaign = controller.campaignForApp(app.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: SectionCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppDetailScreen(
                    controller: controller,
                    appId: app.id,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.packageName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (campaign != null)
                    StatusPill(
                      label: '${campaign.totalJoined}/${campaign.slots} testadores',
                      color: AppColors.primary,
                    )
                  else if (app.isSdkVerified)
                    const StatusPill(
                      label: 'SDK Verificado',
                      color: AppColors.success,
                    )
                  else
                    const StatusPill(
                      label: 'Validar SDK',
                      color: AppColors.warning,
                    ),
                  const SizedBox(width: AppSpace.xs),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showNewAppSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final pkgCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final optInCtrl = TextEditingController(
      text: 'https://play.google.com/apps/testing/',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.xl,
          AppSpace.xl,
          AppSpace.xl + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cadastrar novo app',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                key: const Key('new_app_name_input'),
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome do app'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                key: const Key('new_app_pkg_input'),
                controller: pkgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package name (ex: com.meu.app)',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                key: const Key('new_app_desc_input'),
                controller: descCtrl,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Descrição curta (≤ 80 chars)',
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              TextField(
                controller: optInCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de opt-in do teste fechado',
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                key: const Key('save_new_app_btn'),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      pkgCtrl.text.trim().isEmpty) {
                    return;
                  }
                  controller.createApp(
                    name: nameCtrl.text,
                    packageName: pkgCtrl.text,
                    shortDescription: descCtrl.text.isEmpty
                        ? 'App em teste fechado no Google Play.'
                        : descCtrl.text,
                    category: 'Produtividade',
                    playOptInUrl: optInCtrl.text,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Criar app e gerar appKey'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDetailScreen extends StatelessWidget {
  final HubController controller;
  final String appId;

  const AppDetailScreen({
    super.key,
    required this.controller,
    required this.appId,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final app = controller.myApps.firstWhere((a) => a.id == appId);
        final campaign = controller.campaignForApp(app.id);
        final aiPrompt =
            'Integre o TesterLoop SDK neste projeto seguindo https://testerloop.io/llms-full.txt. appKey: ${app.appKey}';

        return Scaffold(
          appBar: AppBar(title: Text(app.name)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.lg),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Integração SDK (AI-ready)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    SelectableText(
                      'appKey: ${app.appKey}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: aiPrompt));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Prompt AI-ready copiado!'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar prompt para IA'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validação do SDK em 2 etapas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        OutlinedButton.icon(
                          key: Key('validate_debug_${app.id}'),
                          onPressed: () =>
                              controller.validateAppSdkStep1Debug(app.id),
                          icon: Icon(
                            app.isSdkDebugOk
                                ? Icons.check_circle_outline
                                : Icons.bug_report_outlined,
                            color: app.isSdkDebugOk
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          label: Text(
                            app.isSdkDebugOk
                                ? 'Etapa 1 (Debug) ✓'
                                : 'Etapa 1: Validar build debug',
                          ),
                        ),
                        FilledButton.icon(
                          key: Key('validate_play_${app.id}'),
                          onPressed: () =>
                              controller.validateAppSdkStep2Play(app.id),
                          icon: Icon(
                            app.isSdkVerified
                                ? Icons.verified_rounded
                                : Icons.store_outlined,
                          ),
                          label: Text(
                            app.isSdkVerified
                                ? 'Etapa 2 (Play Closed Track) ✓'
                                : 'Etapa 2: Validar via Play Store',
                          ),
                        ),
                      ],
                    ),
                    if (app.signingCertSha256 != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Certificado TOFU: ${app.signingCertSha256}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              if (campaign == null)
                FilledButton.icon(
                  key: Key('publish_campaign_${app.id}'),
                  onPressed: () {
                    final err = controller.publishCampaign(app.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          err ?? 'Campanha publicada! 12 vagas + 3 reserva ativas.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: Text(controller.strings.publishCampaign),
                )
              else
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Painel da campanha',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusPill(
                            label:
                                '${campaign.completedCount}/${campaign.slots} concluídos',
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Ativos: ${campaign.activeCount} · Meta: ${campaign.requiredDays} dias contínuos',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          FilledButton.icon(
                            key: Key('featured_btn_${app.id}'),
                            onPressed: () => showFeaturedBookingSheet(
                              context,
                              controller,
                              campaign,
                            ),
                            icon: const Icon(Icons.star_rounded),
                            label: Text(
                              campaign.featuredSlot != null
                                  ? 'Featured Slot #${campaign.featuredSlot}'
                                  : 'Destacar (Featured)',
                            ),
                          ),
                          OutlinedButton.icon(
                            key: Key('report_btn_${app.id}'),
                            onPressed: () =>
                                _showProductionReport(context, app, campaign),
                            icon: const Icon(Icons.description_outlined),
                            label: Text(controller.strings.generateReport),
                          ),
                          TextButton(
                            onPressed: () {
                              final refund =
                                  controller.cancelCampaign(campaign.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Campanha cancelada. Reembolso: +$refund pts',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Cancelar campanha',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
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

  Future<void> _showProductionReport(
    BuildContext context,
    AppProject app,
    Campaign campaign,
  ) async {
    final md = controller.buildProductionReportMarkdown(app, campaign);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Relatório para Acesso à Produção'),
        content: SingleChildScrollView(
          child: SelectableText(
            md,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: md));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Relatório Markdown copiado!')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copiar Markdown'),
          ),
        ],
      ),
    );
  }
}
