import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    final ext = context.appExt;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('analytics_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      body: SafeArea(
        child: analyticsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red))),
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Summary Cards ---
              Text(l10n.translate('analytics_overview'), style: TextStyle(color: context.cs.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(label: l10n.translate('analytics_total_jobs'), value: '${data.totalJobs}', icon: Icons.work, color: context.cs.secondary),
                  _StatCard(label: l10n.translate('analytics_not_started'), value: '${data.notStarted}', icon: Icons.radio_button_unchecked, color: ext.statusNotStarted),
                  _StatCard(label: l10n.translate('analytics_in_progress'), value: '${data.inProgress}', icon: Icons.play_circle, color: ext.statusInProgress),
                  _StatCard(label: l10n.translate('analytics_completed'), value: '${data.workCompleted}', icon: Icons.check_circle, color: ext.statusWorkCompleted),
                  _StatCard(label: l10n.translate('analytics_closed'), value: '${data.closed}', icon: Icons.lock, color: ext.statusClosed),
                ],
              ),
              const SizedBox(height: 24),

              // --- Completion Stats ---
              Text(l10n.translate('analytics_completion'), style: TextStyle(color: context.cs.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(label: l10n.translate('analytics_today'), value: '${data.completedToday}', icon: Icons.today, color: const Color(0xFF4FC3F7))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: l10n.translate('analytics_this_week'), value: '${data.completedThisWeek}', icon: Icons.view_week, color: const Color(0xFF4FC3F7))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: l10n.translate('analytics_this_month'), value: '${data.completedThisMonth}', icon: Icons.calendar_month, color: const Color(0xFF4FC3F7))),
                ],
              ),
              const SizedBox(height: 24),

              // --- Financial ---
              Text(l10n.translate('analytics_financial'), style: TextStyle(color: context.cs.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(
                    label: l10n.translate('analytics_total_revenue'),
                    value: '₺${data.totalFees.toStringAsFixed(0)}',
                    icon: Icons.payments,
                    color: Colors.green,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(
                    label: l10n.translate('analytics_avg_travel'),
                    value: '${data.avgTravelMinutes.toStringAsFixed(0)} ${l10n.translate('analytics_minutes_suffix')}',
                    icon: Icons.route,
                    color: const Color(0xFF4FC3F7),
                  )),
                ],
              ),
              const SizedBox(height: 24),

              // --- Per Worker ---
              Text(l10n.translate('analytics_per_worker'), style: TextStyle(color: context.cs.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (data.perWorker.isEmpty)
                Text(l10n.translate('analytics_no_data'), style: TextStyle(color: context.appExt.textSecondary))
              else
                ...data.perWorker.map((w) => _WorkerCard(stats: w)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExt>() ?? AppThemeExt.defaultDark;
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: ext.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _WorkerCard extends ConsumerWidget {
  final WorkerStats stats;
  const _WorkerCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExt>() ?? AppThemeExt.defaultDark;
    final rate = stats.totalJobs > 0
        ? (stats.completedJobs / stats.totalJobs * 100).toStringAsFixed(0)
        : '0';

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(stats.workerName, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))),
                Text('$rate%', style: TextStyle(color: ext.statusClosed, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MiniStat(label: l10n.translate('analytics_worker_completed'), value: '${stats.completedJobs}'),
                const SizedBox(width: 16),
                _MiniStat(label: l10n.translate('analytics_worker_total'), value: '${stats.totalJobs}'),
                const SizedBox(width: 16),
                _MiniStat(label: l10n.translate('analytics_worker_revenue'), value: '₺${stats.totalFee.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 4),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.totalJobs > 0 ? stats.completedJobs / stats.totalJobs : 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                color: Theme.of(context).colorScheme.secondary,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExt>() ?? AppThemeExt.defaultDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: ext.textSecondary, fontSize: 11)),
      ],
    );
  }
}
