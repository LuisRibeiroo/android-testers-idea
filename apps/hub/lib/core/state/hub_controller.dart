import 'dart:math';
import 'package:flutter/foundation.dart';
import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../native/hub_native_channel.dart';

class HubController extends ChangeNotifier {
  final HubNativeChannel nativeChannel;

  HubController({HubNativeChannel? nativeChannel})
      : nativeChannel = nativeChannel ?? HubNativeChannel() {
    _seedInitialData();
  }

  static const String googleGroupUrl =
      'https://groups.google.com/g/testerloop-testers';
  static const String redditCommunityUrl =
      'https://www.reddit.com/r/AndroidAppTesters';

  AppLocale _locale = AppLocale.ptBr;
  AppLocale get locale => _locale;
  AppStrings get strings => AppStrings(_locale);

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  bool _dailyReminder19h = true;
  bool get dailyReminder19h => _dailyReminder19h;

  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  final List<Campaign> _campaigns = [];
  final List<Enrollment> _enrollments = [];
  final List<AppProject> _myApps = [];
  final List<LedgerEntry> _ledger = [];
  final List<TesterFeedback> _receivedFeedback = [];

  List<Campaign> get campaigns => List.unmodifiable(_campaigns);
  List<Campaign> get featuredCampaigns => _campaigns
      .where((c) => c.featuredSlot != null && c.status == CampaignStatus.recruiting)
      .toList()
    ..sort((a, b) => (a.featuredSlot ?? 9).compareTo(b.featuredSlot ?? 9));

  List<Campaign> get recentCampaigns => _campaigns
      .where((c) => c.status == CampaignStatus.recruiting)
      .toList()
    ..sort((a, b) => (b.publishedAt ?? DateTime(2026)).compareTo(a.publishedAt ?? DateTime(2026)));

  List<Campaign> get almostFullCampaigns => _campaigns
      .where((c) => c.status == CampaignStatus.recruiting)
      .toList()
    ..sort((a, b) => b.totalJoined.compareTo(a.totalJoined));

  List<Enrollment> get enrollments => List.unmodifiable(_enrollments);
  List<AppProject> get myApps => List.unmodifiable(_myApps);
  List<LedgerEntry> get ledger => List.unmodifiable(_ledger);
  List<TesterFeedback> get receivedFeedback => List.unmodifiable(_receivedFeedback);

  int get availablePoints => _ledger
      .where((e) => e.bucket == 'available')
      .fold(0, (sum, e) => sum + e.amount);

  int get pendingPoints => _ledger
      .where((e) => e.bucket == 'pending')
      .fold(0, (sum, e) => sum + e.amount);

  static const List<FeaturedPackage> featuredPackages = [
    FeaturedPackage(
      id: 'featured_24h',
      label: '24 horas',
      durationHours: 24,
      referencePrice: 'US\$ 4,99 (ref.)',
    ),
    FeaturedPackage(
      id: 'featured_72h',
      label: '72 horas',
      durationHours: 72,
      referencePrice: 'US\$ 11,99 (ref.)',
    ),
    FeaturedPackage(
      id: 'featured_7d',
      label: '7 dias',
      durationHours: 168,
      referencePrice: 'US\$ 24,99 (ref.)',
    ),
  ];

  void setTab(int index) {
    if (_selectedTabIndex == index) return;
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void setDailyReminder(bool enabled) {
    _dailyReminder19h = enabled;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    await nativeChannel.getDeviceIdentity();
    _currentUser = const UserProfile(
      id: 'user-owner-1',
      displayName: 'Luís Ribeiro',
      email: 'luis@testerloop.dev',
      reputation: 0.96,
      integrityVerified: true,
      timezone: 'America/Sao_Paulo',
    );
    if (!_ledger.any((e) => e.kind == LedgerKind.bonusWelcome)) {
      _ledger.insert(
        0,
        LedgerEntry(
          id: 'led-welcome',
          kind: LedgerKind.bonusWelcome,
          bucket: 'available',
          amount: 10,
          description: 'Bônus de boas-vindas (Play Integrity OK)',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void signOut() {
    _currentUser = null;
    _selectedTabIndex = 0;
    notifyListeners();
  }

  void deleteAccount() {
    _currentUser = null;
    _enrollments.clear();
    _myApps.clear();
    _ledger.clear();
    _selectedTabIndex = 0;
    notifyListeners();
  }

  bool isEnrolledIn(String campaignId) {
    return _enrollments.any((e) => e.campaign.id == campaignId);
  }

  Enrollment? enrollmentForCampaign(String campaignId) {
    for (final e in _enrollments) {
      if (e.campaign.id == campaignId) return e;
    }
    return null;
  }

  Enrollment startEnrollment(Campaign campaign) {
    final existing = enrollmentForCampaign(campaign.id);
    if (existing != null) return existing;

    final days = List<DayCheckState>.generate(
      campaign.requiredDays,
      (i) => i == 0 ? DayCheckState.pendingToday : DayCheckState.upcoming,
    );
    final created = Enrollment(
      id: 'enr-${DateTime.now().microsecondsSinceEpoch}',
      campaign: campaign,
      status: EnrollmentStatus.pending,
      streakDays: 0,
      activeDays: 0,
      todayForegroundSeconds: 0,
      calendarDays: days,
      groupJoined: false,
      optInAccepted: false,
      appInstalled: false,
    );
    _enrollments.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> updateEnrollmentStep(
    String enrollmentId, {
    bool? groupJoined,
    bool? optInAccepted,
    bool? appInstalled,
  }) async {
    final idx = _enrollments.indexWhere((e) => e.id == enrollmentId);
    if (idx < 0) return;
    final current = _enrollments[idx];
    var installed = appInstalled ?? current.appInstalled;
    if (appInstalled == true) {
      installed = await nativeChannel.isPackageInstalled(
        current.campaign.app.packageName,
      );
    }
    _enrollments[idx] = current.copyWith(
      groupJoined: groupJoined,
      optInAccepted: optInAccepted,
      appInstalled: installed,
    );
    notifyListeners();
  }

  Future<bool> validateHandshakeAndActivate(String enrollmentId) async {
    final idx = _enrollments.indexWhere((e) => e.id == enrollmentId);
    if (idx < 0) return false;
    final current = _enrollments[idx];
    final token = 'eyJhbGciOiJFUzI1NiJ9.${current.id}.demo';
    final launched = await nativeChannel.launchWithToken(
      current.campaign.app.packageName,
      token,
    );
    if (!launched) return false;

    _enrollments[idx] = current.copyWith(
      status: EnrollmentStatus.active,
      groupJoined: true,
      optInAccepted: true,
      appInstalled: true,
    );

    final cIdx = _campaigns.indexWhere((c) => c.id == current.campaign.id);
    if (cIdx >= 0) {
      _campaigns[cIdx] = _campaigns[cIdx].copyWith(
        activeCount: _campaigns[cIdx].activeCount + 1,
      );
    }
    notifyListeners();
    return true;
  }

  Future<void> recordForegroundSession(String enrollmentId, int seconds) async {
    final idx = _enrollments.indexWhere((e) => e.id == enrollmentId);
    if (idx < 0) return;
    final current = _enrollments[idx];
    await nativeChannel.launchWithToken(
      current.campaign.app.packageName,
      'eyJhbGciOiJFUzI1NiJ9.${current.id}.demo',
    );

    final updatedSec = current.todayForegroundSeconds + seconds;
    final wasValidated = current.todayValidated;
    final nowValidated = updatedSec >= 60;

    final updatedDays = List<DayCheckState>.from(current.calendarDays);
    final pendingIdx = updatedDays.indexOf(DayCheckState.pendingToday);
    if (nowValidated && pendingIdx >= 0) {
      updatedDays[pendingIdx] = DayCheckState.validated;
    }

    var newActiveDays = current.activeDays;
    var newStreak = current.streakDays;
    if (!wasValidated && nowValidated) {
      newActiveDays += 1;
      newStreak += 1;
      _ledger.insert(
        0,
        LedgerEntry(
          id: 'led-${DateTime.now().microsecondsSinceEpoch}',
          kind: LedgerKind.earnPending,
          bucket: 'pending',
          amount: 1,
          description: '${current.campaign.app.name} — dia $newStreak validado',
          createdAt: DateTime.now(),
        ),
      );
    }

    _enrollments[idx] = current.copyWith(
      todayForegroundSeconds: updatedSec,
      activeDays: newActiveDays,
      streakDays: newStreak,
      calendarDays: updatedDays,
    );
    notifyListeners();
  }

  void submitFeedback(
    String enrollmentId, {
    required int rating,
    required String liked,
    required String issues,
    required String suggestion,
  }) {
    final idx = _enrollments.indexWhere((e) => e.id == enrollmentId);
    if (idx < 0) return;
    final current = _enrollments[idx];
    if (current.feedback != null) return;

    final fb = TesterFeedback(
      id: 'fb-${DateTime.now().microsecondsSinceEpoch}',
      enrollmentId: enrollmentId,
      authorName: _currentUser?.displayName ?? 'Testador',
      rating: rating,
      liked: liked,
      issues: issues,
      suggestion: suggestion,
      createdAt: DateTime.now(),
    );
    _enrollments[idx] = current.copyWith(feedback: fb);

    final totalLen = liked.trim().length + issues.trim().length + suggestion.trim().length;
    if (totalLen >= 30) {
      _ledger.insert(
        0,
        LedgerEntry(
          id: 'led-fb-${DateTime.now().microsecondsSinceEpoch}',
          kind: LedgerKind.bonusFeedback,
          bucket: 'available',
          amount: 2,
          description: 'Bônus feedback aprovado (${current.campaign.app.name})',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  AppProject createApp({
    required String name,
    required String packageName,
    required String shortDescription,
    required String category,
    required String playOptInUrl,
  }) {
    final rand = Random(packageName.hashCode ^ DateTime.now().millisecond);
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(24, (_) => chars[rand.nextInt(chars.length)]).join();
    final app = AppProject(
      id: 'app-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: _currentUser?.id ?? 'user-owner-1',
      name: name.trim(),
      packageName: packageName.trim(),
      shortDescription: shortDescription.trim(),
      description: shortDescription.trim(),
      category: category,
      playOptInUrl: playOptInUrl.trim(),
      appKey: 'tl_pk_$suffix',
    );
    _myApps.insert(0, app);
    notifyListeners();
    return app;
  }

  void validateAppSdkStep1Debug(String appId) {
    final idx = _myApps.indexWhere((a) => a.id == appId);
    if (idx < 0) return;
    _myApps[idx] = _myApps[idx].copyWith(sdkDebugOkAt: DateTime.now());
    notifyListeners();
  }

  void validateAppSdkStep2Play(String appId) {
    final idx = _myApps.indexWhere((a) => a.id == appId);
    if (idx < 0) return;
    final current = _myApps[idx];
    _myApps[idx] = current.copyWith(
      sdkDebugOkAt: current.sdkDebugOkAt ?? DateTime.now(),
      sdkVerifiedAt: DateTime.now(),
      signingCertSha256:
          current.signingCertSha256 ?? 'AB:4C:91:F0:33:E8:12:7B:C4:9A:01:22',
    );
    notifyListeners();
  }

  Campaign? campaignForApp(String appId) {
    for (final c in _campaigns) {
      if (c.app.id == appId &&
          (c.status == CampaignStatus.recruiting ||
              c.status == CampaignStatus.inProgress ||
              c.status == CampaignStatus.completed)) {
        return c;
      }
    }
    return null;
  }

  String? publishCampaign(String appId) {
    final appIdx = _myApps.indexWhere((a) => a.id == appId);
    if (appIdx < 0) return 'App não encontrado';
    final app = _myApps[appIdx];
    if (!app.isSdkVerified) return 'Valide o SDK na Etapa 2 (Play Store) antes de publicar.';
    if (availablePoints < 120) {
      return 'Saldo insuficiente ($availablePoints/120 pts disponíveis).';
    }
    if (campaignForApp(appId) != null) {
      return 'Este app já possui campanha ativa.';
    }

    final campaign = Campaign(
      id: 'camp-${DateTime.now().microsecondsSinceEpoch}',
      app: app,
      status: CampaignStatus.recruiting,
      activeCount: 0,
      completedCount: 0,
      publishedAt: DateTime.now(),
    );
    _campaigns.insert(0, campaign);
    _ledger.insert(
      0,
      LedgerEntry(
        id: 'led-spend-${DateTime.now().microsecondsSinceEpoch}',
        kind: LedgerKind.spendCampaign,
        bucket: 'available',
        amount: -120,
        description: 'Publicação de campanha (${app.name})',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  int cancelCampaign(String campaignId) {
    final idx = _campaigns.indexWhere((c) => c.id == campaignId);
    if (idx < 0) return 0;
    final c = _campaigns[idx];
    final occupied = min(c.slots, c.activeCount + c.completedCount);
    final refund = occupied == 0
        ? c.costPoints
        : (c.costPoints * ((c.slots - occupied) / c.slots)).floor();

    _campaigns[idx] = c.copyWith(status: CampaignStatus.cancelled);
    if (refund > 0) {
      _ledger.insert(
        0,
        LedgerEntry(
          id: 'led-ref-${DateTime.now().microsecondsSinceEpoch}',
          kind: LedgerKind.refundCampaign,
          bucket: 'available',
          amount: refund,
          description: 'Reembolso proporcional (${c.app.name})',
          createdAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
    return refund;
  }

  void bookFeaturedSlot(String campaignId, FeaturedPackage pkg) {
    final idx = _campaigns.indexWhere((c) => c.id == campaignId);
    if (idx < 0) return;
    final usedSlots = _campaigns.map((c) => c.featuredSlot).whereType<int>().toSet();
    final freeSlot = [1, 2, 3].firstWhere((s) => !usedSlots.contains(s), orElse: () => 1);
    _campaigns[idx] = _campaigns[idx].copyWith(featuredSlot: freeSlot);
    notifyListeners();
  }

  String buildProductionReportMarkdown(AppProject app, Campaign? campaign) {
    final active = campaign?.activeCount ?? 0;
    final completed = campaign?.completedCount ?? 0;
    final feedbacks = _receivedFeedback;
    final buf = StringBuffer()
      ..writeln('# Closed Testing Production Access Report — ${app.name}')
      ..writeln('- **Package:** `${app.packageName}`')
      ..writeln('- **Verification:** TesterLoop SDK (SHA-256 TOFU: `${app.signingCertSha256 ?? "verified"}`)')
      ..writeln('- **Requirement:** ${campaign?.requiredDays ?? 14} continuous days / ${campaign?.slots ?? 12} testers')
      ..writeln('- **Testers:** $completed completed · $active active')
      ..writeln('\n## Tester Feedback Summary');
    for (final fb in feedbacks) {
      buf.writeln('- **${fb.rating}/5** (${fb.authorName}): ${fb.liked} | Issues: ${fb.issues} | Suggestion: ${fb.suggestion}');
    }
    return buf.toString();
  }

  void _seedInitialData() {
    final now = DateTime.now();

    const app1 = AppProject(
      id: 'app-seed-1',
      ownerId: 'dev-other-1',
      name: 'FinTrack Offline',
      packageName: 'br.dev.fintrack',
      shortDescription: 'Controle de despesas 100% offline com importação CSV.',
      description:
          'App leve de finanças pessoais focado em privacidade, categorias personalizadas e exportação para planilhas.',
      category: 'Finanças',
      playOptInUrl: 'https://play.google.com/apps/testing/br.dev.fintrack',
      appKey: 'tl_pk_fintrack991234abcd5678ef',
      signingCertSha256: '3A:91:CC:10:88:7D:22:F1:44:9B:02:1E',
      sdkDebugOkAt: null,
      sdkVerifiedAt: null,
    );

    const app2 = AppProject(
      id: 'app-seed-2',
      ownerId: 'dev-other-2',
      name: 'FocusPod Pomodoro',
      packageName: 'io.focuspod.timer',
      shortDescription: 'Timer Pomodoro minimalista com sons binaurais locais.',
      description:
          'Ideal para sessões de deep work sem distrações, com histórico semanal e estatísticas por projeto.',
      category: 'Produtividade',
      playOptInUrl: 'https://play.google.com/apps/testing/io.focuspod.timer',
      appKey: 'tl_pk_focuspod774411xyzw9988ab',
      signingCertSha256: '7C:12:AB:55:90:1F:8E:33:A2:4D:91:00',
    );

    const app3 = AppProject(
      id: 'app-seed-3',
      ownerId: 'dev-other-3',
      name: 'BoletoScan OCR',
      packageName: 'com.boletoscan.ocr',
      shortDescription: 'Leitor rápido de códigos de barras e linha digitável.',
      description:
          'Lê boletos pela câmera mesmo em baixa luz e copia a linha digitável com 1 toque.',
      category: 'Utilitários',
      playOptInUrl: 'https://play.google.com/apps/testing/com.boletoscan.ocr',
      appKey: 'tl_pk_boletoscan331122mnop4455',
      signingCertSha256: '9D:44:21:FE:11:09:6A:BC:77:88:23:1F',
    );

    const myOwnedApp = AppProject(
      id: 'app-owned-1',
      ownerId: 'user-owner-1',
      name: 'HabitoLoop',
      packageName: 'dev.luisribeiro.habitoloop',
      shortDescription: 'Rastreador de hábitos diários com widgets Material You.',
      description: 'App próprio cadastrado para validação do SDK e publicação.',
      category: 'Produtividade',
      playOptInUrl: 'https://play.google.com/apps/testing/dev.luisribeiro.habitoloop',
      appKey: 'tl_pk_habitoloop1122334455667788',
    );

    _myApps.add(myOwnedApp);

    final c1 = Campaign(
      id: 'camp-seed-1',
      app: app1,
      status: CampaignStatus.recruiting,
      activeCount: 10,
      completedCount: 1,
      featuredSlot: 1,
      publishedAt: now.subtract(const Duration(hours: 6)),
    );
    final c2 = Campaign(
      id: 'camp-seed-2',
      app: app2,
      status: CampaignStatus.recruiting,
      activeCount: 8,
      completedCount: 0,
      featuredSlot: 2,
      publishedAt: now.subtract(const Duration(hours: 12)),
    );
    final c3 = Campaign(
      id: 'camp-seed-3',
      app: app3,
      status: CampaignStatus.recruiting,
      activeCount: 4,
      completedCount: 0,
      publishedAt: now.subtract(const Duration(hours: 2)),
    );

    _campaigns.addAll([c1, c2, c3]);

    // Seed one active enrollment in day 5/14 so user immediately sees 14-day calendar
    _enrollments.add(
      Enrollment(
        id: 'enr-seed-1',
        campaign: c2,
        status: EnrollmentStatus.active,
        streakDays: 4,
        activeDays: 4,
        todayForegroundSeconds: 20,
        calendarDays: [
          DayCheckState.validated,
          DayCheckState.validated,
          DayCheckState.validated,
          DayCheckState.validated,
          DayCheckState.pendingToday,
          ...List.filled(9, DayCheckState.upcoming),
        ],
        groupJoined: true,
        optInAccepted: true,
        appInstalled: true,
      ),
    );

    _ledger.addAll([
      LedgerEntry(
        id: 'led-seed-1',
        kind: LedgerKind.bonusCompletion,
        bucket: 'available',
        amount: 125,
        description: 'Saldo acumulado de campanhas anteriores',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      LedgerEntry(
        id: 'led-seed-2',
        kind: LedgerKind.earnPending,
        bucket: 'pending',
        amount: 4,
        description: 'FocusPod Pomodoro — 4 dias ativos em custódia',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    _receivedFeedback.add(
      TesterFeedback(
        id: 'fb-seed-1',
        enrollmentId: 'enr-ext-1',
        authorName: 'Marina S.',
        rating: 5,
        liked: 'Interface muito rápida e onboarding claro em menos de 30 segundos.',
        issues: 'No Android 14 o teclado cobriu o botão salvar na primeira tentativa.',
        suggestion: 'Adicionar atalho de widget na tela inicial.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    );
  }
}
