import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../models/job.dart';
import 'job_creation_screen.dart';
import 'job_detail_screen.dart';
import 'admin_dashboard.dart';
import 'admin_analytics_screen.dart';
import 'module_settings_screen.dart';
import 'job_template_screen.dart';
import '../providers/module_provider.dart';
import '../widgets/calendar/time_grid_view.dart';
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
    final isAdmin = authState is ApprovedAdmin;
    final branding = ref.watch(brandingProvider);
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle (Aylık bazlı)
    final jobsAsync = isAdmin 
      ? ref.watch(allJobsProvider(_focusedDay)) 
      : ref.watch(workerJobsProvider(_focusedDay));
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title'), style: const TextStyle(fontSize: 16)),
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
                    content: Text(l10n.translate('leave_org_confirm'), style: const TextStyle(color: Color(0xFF90A4AE))),
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
      body: SafeArea(
        bottom: true,
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
                child: RepaintBoundary(
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
      ),
      ),
      floatingActionButton: isAdmin
          ? Semantics(
              label: l10n.translate('job_create_title'),
              button: true,
              child: FloatingActionButton(
                tooltip: l10n.translate('job_create_title'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobCreationScreen())),
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            )
          : null,
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
