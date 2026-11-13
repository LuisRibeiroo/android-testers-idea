import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

class SettingsScreen extends StatelessWidget {
  final HubController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    final s = controller.strings;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.lg),
      children: [
        SectionCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  (user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: 'Reputação ${((user?.reputation ?? 1.0) * 100).round()}%',
                color: AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Idioma / Language',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpace.sm),
              SegmentedButton<AppLocale>(
                segments: const [
                  ButtonSegment(value: AppLocale.ptBr, label: Text('Português (BR)')),
                  ButtonSegment(value: AppLocale.en, label: Text('English')),
                ],
                selected: {controller.locale},
                onSelectionChanged: (sel) => controller.setLocale(sel.first),
              ),
              const SizedBox(height: AppSpace.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lembrete diário às 19:00'),
                subtitle: const Text(
                  'Notificar sobre apps em teste que ainda faltam 60s no dia.',
                ),
                value: controller.dailyReminder19h,
                onChanged: controller.setDailyReminder,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        SectionCard(
          onTap: () => controller.nativeChannel
              .openExternalUrl(HubController.redditCommunityUrl),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.communityTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      'Canal oficial de apoio e recrutamento para testes fechados (OQ-15).',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        OutlinedButton.icon(
          onPressed: controller.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
        ),
        const SizedBox(height: AppSpace.sm),
        TextButton.icon(
          key: const Key('delete_account_btn'),
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          label: Text(
            s.deleteAccount,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta permanentemente?'),
        content: const Text(
          'Esta ação remove seu perfil, dispositivos, inscrições e saldo de pontos conforme a LGPD e as políticas do Google Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir conta'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.deleteAccount();
    }
  }
}
