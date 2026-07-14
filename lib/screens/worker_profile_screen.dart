import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/worker_analytics_provider.dart';
import '../theme/app_theme.dart';

/// Worker profil ve ayar ekranı.
/// B + C: Profil bilgisi, dil seçimi, bildirim tercihleri, istatistikler.
class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final authState = ref.watch(authProvider).value;
    final userName = authState?.appUser?.name ?? '';
    final analyticsAsync = ref.watch(workerAnalyticsProvider);
    final branding = ref.watch(brandingProvider);
    final notificationEnabled = ref.watch(notificationProvider);
    final currentLang = ref.watch(translationProvider).value ?? 'tr';
    final cs = context.cs;
    final ext = context.appExt;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('worker_profile_title')),
        backgroundColor: branding.useBranding
            ? branding.primaryColor
            : const Color(0xFF0D47A1),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Profil Kartı ---
              Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primary,
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName,
                                style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(l10n.translate('worker_role_label'),
                                style: TextStyle(
                                    color: ext.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- İstatistik Özeti ---
              Text(l10n.translate('worker_my_stats'),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              analyticsAsync.when(
                loading: () => Center(
                    child: CircularProgressIndicator(color: cs.secondary)),
                error: (e, _) => Text(
                    l10n.translate('generic_error', {'error': '$e'}),
                    style: const TextStyle(color: Colors.red)),
                data: (data) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MiniStat(
                        icon: Icons.work_outline,
                        label: l10n.translate('worker_stat_total'),
                        value: '${data.totalJobs}',
                        color: cs.secondary),
                    _MiniStat(
                        icon: Icons.check_circle_outline,
                        label: l10n.translate('worker_stat_done'),
                        value: '${data.workCompleted + data.closed}',
                        color: ext.statusClosed),
                    _MiniStat(
                        icon: Icons.today,
                        label: l10n.translate('worker_stat_month'),
                        value: '${data.completedThisMonth}',
                        color: ext.statusWorkCompleted),
                    _MiniStat(
                        icon: Icons.payments_outlined,
                        label: l10n.translate('worker_stat_fees'),
                        value: '₺${data.totalFees.toStringAsFixed(0)}',
                        color: ext.statusInProgress),
                    _MiniStat(
                        icon: Icons.trending_up,
                        label: l10n.translate('worker_stat_rate'),
                        value: '%${data.completionRate.toStringAsFixed(0)}',
                        color: cs.primary),
                    _MiniStat(
                        icon: Icons.auto_awesome,
                        label: l10n.translate('worker_stat_avg'),
                        value: '₺${data.avgFeePerJob.toStringAsFixed(0)}',
                        color: ext.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Dil Seçimi ---
              Text(l10n.translate('worker_language'),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: ['tr', 'en', 'nl'].map((lang) {
                    final isSelected = currentLang == lang;
                    final langNames = {
                      'tr': l10n.translate('lang_turkish'),
                      'en': l10n.translate('lang_english'),
                      'nl': l10n.translate('lang_dutch'),
                    };
                    return ListTile(
                      title: Text(langNames[lang] ?? lang,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50))
                          : null,
                      onTap: () => ref
                          .read(translationProvider.notifier)
                          .setLanguage(lang),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // --- Bildirim Tercihleri ---
              Text(l10n.translate('worker_notifications'),
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: SwitchListTile(
                  title: Text(l10n.translate('worker_push_enabled'),
                      style: TextStyle(
                          color: cs.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text(l10n.translate('worker_push_desc'),
                      style: TextStyle(
                          color: ext.textSecondary, fontSize: 12)),
                  value: notificationEnabled,
                  onChanged: (val) {
                    if (val) {
                      ref.read(notificationProvider.notifier).initialize();
                    } else {
                      ref.read(notificationProvider.notifier).disable();
                    }
                  },
                  activeColor: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(height: 24),

              // --- Çıkış ---
              ElevatedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: Text(l10n.translate('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük istatistik kartı (Wrap içinde kullanılır).
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 10)),
        ],
      ),
    );
  }
}
