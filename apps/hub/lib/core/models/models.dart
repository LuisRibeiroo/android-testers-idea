enum CampaignStatus { draft, recruiting, inProgress, completed, failed, cancelled }

enum EnrollmentStatus { pending, active, atRisk, completed, dropped, rejected }

enum DayCheckState { validated, pendingToday, missed, upcoming }

enum LedgerKind {
  earnPending,
  release,
  forfeit,
  spendCampaign,
  refundCampaign,
  bonusWelcome,
  bonusCompletion,
  bonusFeedback,
  expire,
}

class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final double reputation;
  final bool integrityVerified;
  final String timezone;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.reputation,
    required this.integrityVerified,
    required this.timezone,
  });
}

class AppProject {
  final String id;
  final String ownerId;
  final String name;
  final String packageName;
  final String shortDescription;
  final String description;
  final String category;
  final String playOptInUrl;
  final String appKey;
  final String? signingCertSha256;
  final DateTime? sdkDebugOkAt;
  final DateTime? sdkVerifiedAt;

  const AppProject({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.packageName,
    required this.shortDescription,
    required this.description,
    required this.category,
    required this.playOptInUrl,
    required this.appKey,
    this.signingCertSha256,
    this.sdkDebugOkAt,
    this.sdkVerifiedAt,
  });

  bool get isSdkDebugOk => sdkDebugOkAt != null;
  bool get isSdkVerified => sdkVerifiedAt != null;

  AppProject copyWith({
    String? signingCertSha256,
    DateTime? sdkDebugOkAt,
    DateTime? sdkVerifiedAt,
  }) {
    return AppProject(
      id: id,
      ownerId: ownerId,
      name: name,
      packageName: packageName,
      shortDescription: shortDescription,
      description: description,
      category: category,
      playOptInUrl: playOptInUrl,
      appKey: appKey,
      signingCertSha256: signingCertSha256 ?? this.signingCertSha256,
      sdkDebugOkAt: sdkDebugOkAt ?? this.sdkDebugOkAt,
      sdkVerifiedAt: sdkVerifiedAt ?? this.sdkVerifiedAt,
    );
  }
}

class Campaign {
  final String id;
  final AppProject app;
  final CampaignStatus status;
  final int slots;
  final int bufferSlots;
  final int requiredDays;
  final int minActiveDays;
  final int costPoints;
  final int activeCount;
  final int completedCount;
  final int? featuredSlot;
  final DateTime? publishedAt;

  const Campaign({
    required this.id,
    required this.app,
    required this.status,
    this.slots = 12,
    this.bufferSlots = 3,
    this.requiredDays = 14,
    this.minActiveDays = 10,
    this.costPoints = 120,
    required this.activeCount,
    required this.completedCount,
    this.featuredSlot,
    this.publishedAt,
  });

  int get totalCapacity => slots + bufferSlots;
  int get totalJoined => activeCount + completedCount;
  int get rewardPoints => requiredDays + 3; // 14 daily + 3 completion bonus

  Campaign copyWith({
    CampaignStatus? status,
    int? activeCount,
    int? completedCount,
    int? featuredSlot,
  }) {
    return Campaign(
      id: id,
      app: app,
      status: status ?? this.status,
      slots: slots,
      bufferSlots: bufferSlots,
      requiredDays: requiredDays,
      minActiveDays: minActiveDays,
      costPoints: costPoints,
      activeCount: activeCount ?? this.activeCount,
      completedCount: completedCount ?? this.completedCount,
      featuredSlot: featuredSlot ?? this.featuredSlot,
      publishedAt: publishedAt,
    );
  }
}

class TesterFeedback {
  final String id;
  final String enrollmentId;
  final String authorName;
  final int rating;
  final String liked;
  final String issues;
  final String suggestion;
  final DateTime createdAt;

  const TesterFeedback({
    required this.id,
    required this.enrollmentId,
    required this.authorName,
    required this.rating,
    required this.liked,
    required this.issues,
    required this.suggestion,
    required this.createdAt,
  });
}

class Enrollment {
  final String id;
  final Campaign campaign;
  final EnrollmentStatus status;
  final int streakDays;
  final int activeDays;
  final int todayForegroundSeconds;
  final List<DayCheckState> calendarDays;
  final bool groupJoined;
  final bool optInAccepted;
  final bool appInstalled;
  final TesterFeedback? feedback;

  const Enrollment({
    required this.id,
    required this.campaign,
    required this.status,
    required this.streakDays,
    required this.activeDays,
    required this.todayForegroundSeconds,
    required this.calendarDays,
    required this.groupJoined,
    required this.optInAccepted,
    required this.appInstalled,
    this.feedback,
  });

  bool get todayValidated => todayForegroundSeconds >= 60;

  Enrollment copyWith({
    EnrollmentStatus? status,
    int? streakDays,
    int? activeDays,
    int? todayForegroundSeconds,
    List<DayCheckState>? calendarDays,
    bool? groupJoined,
    bool? optInAccepted,
    bool? appInstalled,
    TesterFeedback? feedback,
  }) {
    return Enrollment(
      id: id,
      campaign: campaign,
      status: status ?? this.status,
      streakDays: streakDays ?? this.streakDays,
      activeDays: activeDays ?? this.activeDays,
      todayForegroundSeconds:
          todayForegroundSeconds ?? this.todayForegroundSeconds,
      calendarDays: calendarDays ?? this.calendarDays,
      groupJoined: groupJoined ?? this.groupJoined,
      optInAccepted: optInAccepted ?? this.optInAccepted,
      appInstalled: appInstalled ?? this.appInstalled,
      feedback: feedback ?? this.feedback,
    );
  }
}

class LedgerEntry {
  final String id;
  final LedgerKind kind;
  final String bucket; // 'available' | 'pending'
  final int amount;
  final String description;
  final DateTime createdAt;

  const LedgerEntry({
    required this.id,
    required this.kind,
    required this.bucket,
    required this.amount,
    required this.description,
    required this.createdAt,
  });
}

class FeaturedPackage {
  final String id;
  final String label;
  final int durationHours;
  final String referencePrice;

  const FeaturedPackage({
    required this.id,
    required this.label,
    required this.durationHours,
    required this.referencePrice,
  });
}
