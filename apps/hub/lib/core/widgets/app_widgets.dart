import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_tokens.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(onTap: onTap, child: content)
          : content,
    );
  }
}

class StreakCalendarGrid extends StatelessWidget {
  final List<DayCheckState> days;
  const StreakCalendarGrid({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(days.length, (index) {
        final state = days[index];
        final (Color bg, Color fg, String symbol) = switch (state) {
          DayCheckState.validated => (
            AppColors.success.withValues(alpha: 0.18),
            AppColors.success,
            '✓',
          ),
          DayCheckState.pendingToday => (
            AppColors.warning.withValues(alpha: 0.18),
            AppColors.warning,
            '⚠',
          ),
          DayCheckState.missed => (
            AppColors.danger.withValues(alpha: 0.18),
            AppColors.danger,
            '✗',
          ),
          DayCheckState.upcoming => (
            AppColors.surfaceElevated,
            AppColors.textMuted,
            '${index + 1}',
          ),
        };
        return Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state == DayCheckState.pendingToday
                  ? AppColors.warning
                  : AppColors.border,
            ),
          ),
          child: Text(
            symbol,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }),
    );
  }
}
