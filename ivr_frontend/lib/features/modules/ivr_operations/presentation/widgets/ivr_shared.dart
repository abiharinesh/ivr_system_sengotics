import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// Small pieces shared by the two Voice & IVR tabs, so they cannot drift apart
/// visually — they are two views of the same call.

enum MetricTone { neutral, good, warn, bad }

/// A counter above the list.
class IvrMetric extends StatelessWidget {
  const IvrMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone = MetricTone.neutral,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final MetricTone tone;

  Color get _accent => switch (tone) {
        MetricTone.good => AppTheme.accent,
        MetricTone.warn => AppTheme.warning,
        MetricTone.bad => AppTheme.error,
        MetricTone.neutral => AppTheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tone == MetricTone.neutral
              ? AppTheme.stroke
              : _accent.withValues(alpha: 0.32),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: _accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              height: 1,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w800,
              color: tone == MetricTone.neutral ? AppTheme.textPrimary : _accent,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact status pill.
class IvrTag extends StatelessWidget {
  const IvrTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          // Flexible, not a bare Text: a tag sits inside a Wrap that a
          // Flexible parent can squeeze below the label's natural width, and
          // an unshrinkable Text then overflows its own pill.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IvrEmptyState extends StatelessWidget {
  const IvrEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IvrErrorState extends StatelessWidget {
  const IvrErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A search field with filter controls beside it.
///
/// Below [breakpoint] the filters drop to their own line instead of competing
/// with the search box for width. A Row here overflowed by 215px at phone
/// width — three chips and a button do not fit next to a text field on a
/// 320px screen, and no amount of Expanded fixes that.
class IvrControlBar extends StatelessWidget {
  const IvrControlBar({
    super.key,
    required this.search,
    required this.filters,
    this.breakpoint = 620,
  });

  final Widget search;
  final List<Widget> filters;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= breakpoint) {
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                ...filters,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `manual_review` → `Manual review`.
String prettyIvr(String raw) {
  if (raw.isEmpty) return raw;
  final s = raw.replaceAll('_', ' ').toLowerCase();
  return s[0].toUpperCase() + s.substring(1);
}
