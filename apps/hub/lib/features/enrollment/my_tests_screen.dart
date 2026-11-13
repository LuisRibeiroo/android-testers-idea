import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

class MyTestsScreen extends StatelessWidget {
  final HubController controller;
  const MyTestsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final enrollments = controller.enrollments;
    final strings = controller.strings;

    if (enrollments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: SectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fact_check_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: AppSpace.md),
                Text(strings.noTestsYet, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.lg),
                FilledButton(
                  onPressed: () => controller.setTab(0),
                  child: Text(strings.browseDiscover),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.lg),
      itemCount: enrollments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, index) {
        final enr = enrollments[index];
        final (Color statusColor, String statusLabel) = switch (enr.status) {
          EnrollmentStatus.active => (AppColors.success, 'Ativo'),
          EnrollmentStatus.atRisk => (AppColors.warning, 'Em risco'),
          EnrollmentStatus.completed => (AppColors.primary, 'Concluído'),
          EnrollmentStatus.pending => (AppColors.textSecondary, 'Pendente'),
          _ => (AppColors.danger, 'Encerrado'),
        };

        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enr.campaign.app.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Sequência: ${enr.streakDays}/${enr.campaign.requiredDays} dias · Hoje: ${enr.todayForegroundSeconds}s/60s',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              StreakCalendarGrid(days: enr.calendarDays),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  FilledButton.icon(
                    key: Key('launch_session_${enr.id}'),
                    onPressed: () async {
                      await controller.recordForegroundSession(enr.id, 65);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sessão validada (${enr.campaign.app.name}): dia marcado ✓',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(
                      enr.todayValidated
                          ? 'Dia validado ✓'
                          : 'Abrir e validar 60s hoje',
                    ),
                  ),
                  OutlinedButton.icon(
                    key: Key('feedback_btn_${enr.id}'),
                    onPressed: enr.feedback != null
                        ? null
                        : () => _showFeedbackDialog(context, enr),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(
                      enr.feedback != null
                          ? 'Feedback enviado ✓'
                          : 'Enviar feedback (+2 pts)',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context, Enrollment enr) async {
    int rating = 5;
    final likedCtrl = TextEditingController();
    final issuesCtrl = TextEditingController();
    final suggestionCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Feedback — ${enr.campaign.app.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nota: $rating/5'),
                Slider(
                  value: rating.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  onChanged: (v) => setLocal(() => rating = v.round()),
                ),
                TextField(
                  controller: likedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'O que funcionou bem?',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: issuesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bugs ou travamentos',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: suggestionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sugestão de melhoria',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                controller.submitFeedback(
                  enr.id,
                  rating: rating,
                  liked: likedCtrl.text.isEmpty
                      ? 'Fluxo inicial claro e responsivo no dispositivo Android.'
                      : likedCtrl.text,
                  issues: issuesCtrl.text,
                  suggestion: suggestionCtrl.text,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Enviar (+2 pts)'),
            ),
          ],
        ),
      ),
    );
  }
}
