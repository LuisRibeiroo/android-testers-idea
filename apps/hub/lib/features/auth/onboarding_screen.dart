import 'package:flutter/material.dart';
import '../../core/state/hub_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  final HubController controller;
  const OnboardingScreen({super.key, required this.controller});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _signingIn = false;

  static const _slides = [
    (
      icon: Icons.groups_rounded,
      title: '12 testadores por 14 dias contínuos',
      body:
          'Teste apps de outros desenvolvedores para ganhar pontos e use seu saldo para receber testadores reais no seu teste fechado do Google Play.',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: 'Verificação automática via SDK',
      body:
          'Sem prints nem planilhas. O SDK confirma instalação via Play Store, uso diário de ≥ 60s e protege sua campanha contra abandono.',
    ),
    (
      icon: Icons.article_outlined,
      title: 'Relatório pronto para produção',
      body:
          'Exporte métricas de engajamento verificadas e feedbacks reais dos testadores para preencher o questionário de acesso à produção.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() => _signingIn = true);
    await widget.controller.signInWithGoogle();
    if (mounted) {
      setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.loop_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text(
                          'TesterLoop Hub',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      const StatusPill(
                        label: '12×14 Play Ready',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return SectionCard(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Icon(slide.icon, color: AppColors.primary, size: 36),
                                  ),
                                  const SizedBox(height: AppSpace.lg),
                                  Text(
                                    slide.title,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpace.md),
                                  Text(
                                    slide.body,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  FilledButton.icon(
                    key: const Key('google_signin_btn'),
                    onPressed: _signingIn ? null : _handleSignIn,
                    icon: _signingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _signingIn
                          ? 'Verificando Play Integrity...'
                          : 'Entrar com Google (+10 pts boas-vindas)',
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Conta Google obrigatória para participar dos testes fechados no Google Play. Sem coleta de PII pelo SDK.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
