import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_provider.dart';
import '../models/job.dart';
import 'job_creation_screen.dart';
import 'job_detail_screen.dart';
import 'worker_profile_screen.dart';
import 'admin_dashboard.dart';
import 'admin_analytics_screen.dart';
import 'module_settings_screen.dart';
import 'job_template_screen.dart';
import '../providers/module_provider.dart';
import '../widgets/calendar/time_grid_view.dart';
import '../widgets/connectivity_banner.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';

class CalendarHomeScreen extends ConsumerStatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  ConsumerState<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends ConsumerState<CalendarHomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _viewMode = 1; // 0: 1-Day, 1: Week, 2: Month, 3: 3-Day Agenda
  String? _selectedWorkerId; // CAL-03

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final isActuallyAdmin = authState is ApprovedAdmin;
    // Admin "işçi görünümü" moduna geçebilir
    final viewAsWorker = ref.watch(viewAsWorkerProvider);
    final isAdmin = isActuallyAdmin && !viewAsWorker;
    final branding = ref.watch(brandingProvider);
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle (Aylık bazlı)
    final jobsAsync = isAdmin 
      ? ref.watch(allJobsProvider(_focusedDay)) 
      : ref.watch(workerJobsProvider(_focusedDay));
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);

    // --- Bildirim yönlendirme: pendingJobId değişince JobDetailScreen'e git ---
    ref.listen<String?>(pendingJobIdProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      // Job'ı Firestore'dan çek ve yönlendir
      FirebaseFirestore.instance.collection('jobs').doc(next).get().then((doc) {
        if (doc.exists && mounted) {
          final job = Job.fromFirestore(doc);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
          );
        }
        // Yönlendirme sonrası temizle
        ref.read(pendingJobIdProvider.notifier).clear();
      }).catchError((_) {
        ref.read(pendingJobIdProvider.notifier).clear();
      });
    });

    // --- Okunmamış bildirim sayısı (rozet için) ---
    final unreadNotifications = ref.watch(inAppNotificationsProvider).value ?? [];
    final unreadCount = unreadNotifications.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              title: Text(l10n.translate('exit_app_title'), style: const TextStyle(color: Colors.white)),
              content: Text(l10n.translate('exit_app_message'), style: TextStyle(color: context.appExt.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.translate('button_cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.translate('button_ok'), style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldExit == true && context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : (isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1)),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: l10n.translate('analytics_tooltip'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: l10n.translate('module_settings_tooltip'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: l10n.translate('templates_tooltip'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobTemplateScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: l10n.translate('admin_pending_users'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminDashboard(adminUser: (authState as ApprovedAdmin).appUser)),
              ),
            ),
          ],
          // --- Admin: İşçi görünümüne geç / çık ---
          if (isActuallyAdmin)
            IconButton(
              icon: Icon(viewAsWorker ? Icons.visibility_off : Icons.visibility),
              tooltip: viewAsWorker ? 'Admin görünümüne dön' : 'İşçi görünümünü dene',
              onPressed: () => ref.read(viewAsWorkerProvider.notifier).toggle(),
            ),
          // --- Worker menü butonu (profil + ayarlar) ---
          if (!isAdmin)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: l10n.translate('worker_menu_tooltip'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WorkerProfileScreen())),
            ),
          // --- Bildirim çanı (okunmamış rozeti ile) ---
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: l10n.translate('notifications_tooltip'),
                onPressed: () {
                  _showNotificationsSheet(context, unreadNotifications, l10n);
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: l10n.translate('language_tooltip'),
            onSelected: (value) async {
              if (value == 'logout') {
                ref.read(authProvider.notifier).signOut();
              } else if (value == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                    title: Text(l10n.translate('leave_org'), style: const TextStyle(color: Colors.white)),
                    content: Text(l10n.translate('leave_org_confirm'), style: TextStyle(color: context.appExt.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('leave_org'), style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).leaveOrganization();
                }
              } else {
                ref.read(translationProvider.notifier).setLanguage(value);
              }
            },
            itemBuilder: (_) {
              final currentLang = ref.read(translationProvider).value ?? 'tr';
              return [
                PopupMenuItem(
                  value: 'tr',
                  child: Row(children: [
                    Text(l10n.translate('lang_turkish'), style: TextStyle(fontWeight: currentLang == 'tr' ? FontWeight.bold : FontWeight.normal)),
                    if (currentLang == 'tr') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'en',
                  child: Row(children: [
                    Text(l10n.translate('lang_english'), style: TextStyle(fontWeight: currentLang == 'en' ? FontWeight.bold : FontWeight.normal)),
                    if (currentLang == 'en') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'nl',
                  child: Row(children: [
                    Text(l10n.translate('lang_dutch'), style: TextStyle(fontWeight: currentLang == 'nl' ? FontWeight.bold : FontWeight.normal)),
                    if (currentLang == 'nl') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'leave', child: Text(l10n.translate('leave_org'))),
                PopupMenuItem(value: 'logout', child: Text(l10n.translate('logout'))),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          // Admin işçi görünümünde geziyorsa uyarı banner'ı
          if (isActuallyAdmin && viewAsWorker)
            Material(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade800,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.preview, size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('👷 İşçi görünümündesiniz', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => ref.read(viewAsWorkerProvider.notifier).toggle(),
                        child: const Text('Çık', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              bottom: true,
              top: false,
              child: jobsAsync.when(
        data: (jobs) {
          // CAL-03: Apply worker filter
          final filteredJobs = _selectedWorkerId == null 
            ? jobs 
            : jobs.where((j) => j.assignedWorkerId == _selectedWorkerId).toList();

          return Column(
            children: [
              // CAL-03: Admin Filter (lazy-loaded — stream only starts when visible)
              if (isAdmin && (ref.watch(moduleRegistryProvider)['CAL-03'] ?? false))
                _WorkerFilterDropdown(
                  selectedWorkerId: _selectedWorkerId,
                  onChanged: (val) => setState(() => _selectedWorkerId = val),
                ),

              // Tarih Navigasyonu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NavButton(
                      icon: Icons.chevron_left,
                      onTap: () => setState(() => _focusedDay = _focusedDay.subtract(Duration(days: _viewMode == 3 ? 3 : _viewMode == 1 ? 7 : 1))),
                    ),
                    const SizedBox(width: 12),
                    Text(_formatDateRange(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    _NavButton(
                      icon: Icons.chevron_right,
                      onTap: () => setState(() => _focusedDay = _focusedDay.add(Duration(days: _viewMode == 3 ? 3 : _viewMode == 1 ? 7 : 1))),
                    ),
                  ],
                ),
              ),

              // Görünüm Seçici
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ViewChip(label: l10n.translate('calendar_today'), selected: false, onTap: () => setState(() { _focusedDay = DateTime.now(); _selectedDay = _focusedDay; _viewMode = 0; })),
                    const SizedBox(width: 8),
                    _ViewChip(label: l10n.translate('view_3day'), selected: _viewMode == 3, onTap: () => setState(() => _viewMode = 3)),
                    const SizedBox(width: 8),
                    _ViewChip(label: l10n.translate('view_week'), selected: _viewMode == 1, onTap: () => setState(() => _viewMode = 1)),
                  ],
                ),
              ),

              // Zaman Bazlı Grid Takvim
              Expanded(
                child: filteredJobs.isEmpty && jobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_outlined, size: 48, color: context.appExt.textTertiary),
                            const SizedBox(height: 12),
                            Text(l10n.translate('no_jobs_yet'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : RepaintBoundary(
                  child: TimeGridView(
                  jobs: isAdmin && _selectedWorkerId != null
                      ? filteredJobs
                      : jobs,
                  focusedDay: _focusedDay,
                  viewMode: _viewMode,
                  onJobTap: (job) => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
                  statusColor: _getStatusColor,
                ),
              ),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red))),
      ),  // jobsAsync.when
      ),  // SafeArea
      ),  // Expanded
    ],  // Column children
    ),  // Column
      floatingActionButton: isAdmin
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: l10n.translate('refresh_data'),
                  button: true,
                  child: FloatingActionButton.small(
                    heroTag: 'refresh',
                    tooltip: l10n.translate('refresh_data'),
                    onPressed: () {
                      ref.invalidate(allJobsProvider(_focusedDay));
                      ref.invalidate(workerJobsProvider(_focusedDay));
                      ref.invalidate(analyticsProvider);
                      clearAnalyticsCache();
                    },
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: l10n.translate('job_create_title'),
                  button: true,
                  child: FloatingActionButton(
                    heroTag: 'add',
                    tooltip: l10n.translate('job_create_title'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobCreationScreen())),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            )
          : FloatingActionButton.small(
              heroTag: 'refresh-worker',
              tooltip: l10n.translate('refresh_data'),
              onPressed: () {
                ref.invalidate(allJobsProvider(_focusedDay));
                ref.invalidate(workerJobsProvider(_focusedDay));
                ref.invalidate(analyticsProvider);
                clearAnalyticsCache();
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: const Icon(Icons.refresh, color: Color(0xFF4FC3F7)),
            ),
    ),
    );
  }

  String _formatDateRange() {
    final fmt = (DateTime d) => '${d.day}/${d.month}';
    final end = _viewMode == 3
        ? _focusedDay.add(const Duration(days: 2))
        : _viewMode == 1
            ? _focusedDay.add(const Duration(days: 6))
            : _focusedDay;
    if (_viewMode == 0 || _viewMode == 2) return fmt(_focusedDay);
    return '${fmt(_focusedDay)} - ${fmt(end)}';
  }

  /// Okunmamış bildirimleri alt sheet olarak gösterir.
  /// Bir bildirime tıklanınca ilgili işin detayına gider.
  void _showNotificationsSheet(BuildContext context, List<InAppNotification> notifications, dynamic l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A2A3A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (notifications.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off_outlined, size: 48, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(height: 12),
                Text(l10n.translate('no_notifications'), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
          itemBuilder: (ctx, i) {
            final notif = notifications[i];
            return ListTile(
              leading: const Icon(Icons.circle_notifications, color: Color(0xFF1565C0)),
              title: Text(notif.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
              subtitle: Text(notif.body, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
              trailing: Text(
                _timeAgo(notif.timestamp),
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (notif.jobId != null) {
                  ref.read(pendingJobIdProvider.notifier).set(notif.jobId);
                }
              },
            );
          },
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}d';
    if (diff.inHours < 24) return '${diff.inHours}s';
    return '${diff.inDays}g';
  }

  Color _getStatusColor(JobStatus status) {
    if (context.appExt case final ext) {
      return ext.statusColor(status);
    }
    switch (status) {
      case JobStatus.notStarted: return const Color(0xFF9E9E9E);
      case JobStatus.inProgress: return const Color(0xFFFF9800);
      case JobStatus.workCompleted: return const Color(0xFF2196F3);
      case JobStatus.closed: return const Color(0xFF4CAF50);
    }
  }

  Widget _ViewChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4FC3F7) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFF0D1B2A) : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _NavButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.appExt.textSecondary, size: 22),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// CAL-03: Worker filter dropdown (lazy-loaded — Firestore stream starts
// only when this widget is built, i.e. when CAL-03 is active).
// -----------------------------------------------------------------------

class _WorkerFilterDropdown extends ConsumerWidget {
  final String? selectedWorkerId;
  final ValueChanged<String?> onChanged;

  const _WorkerFilterDropdown({
    required this.selectedWorkerId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    final workersAsync = ref.watch(organizationWorkersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: workersAsync.when(
        data: (workers) => DropdownButton<String?>(
          value: selectedWorkerId,
          hint: Text(l10n.translate('worker_filter_hint'), style: const TextStyle(color: Colors.white70)),
          dropdownColor: Theme.of(context).colorScheme.surface,
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.translate('filter_all_workers'))),
            ...workers.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
          ],
          onChanged: onChanged,
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ),
    );
  }
}
