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
    final orgAsync = ref.watch(currentOrganizationProvider);
    final branding = ref.watch(brandingProvider);
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle (Aylık bazlı)
    final jobsAsync = isAdmin 
      ? ref.watch(allJobsProvider(_focusedDay)) 
      : ref.watch(workerJobsProvider(_focusedDay));
    final workersAsync = ref.watch(organizationWorkersProvider); // CAL-03
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title'), style: const TextStyle(fontSize: 16)),
        backgroundColor: branding.useBranding ? branding.primaryColor : (isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1)),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.analytics),
              tooltip: 'Analitik',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Modüller',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Şablonlar',
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
            onSelected: (value) async {
              if (value == 'logout') {
                ref.read(authProvider.notifier).signOut();
              } else if (value == 'leave') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.translate('leave_org')),
                    content: Text(l10n.translate('leave_org_confirm')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('leave_org'), style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).leaveOrganization();
                }
              } else if (value.startsWith('lang_')) {
                // ADM-02: Language switch from popup
                ref.read(translationProvider.notifier).setLanguage(value.substring(5));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'lang_tr', child: Text('🇹🇷  Türkçe')),
              PopupMenuItem(value: 'lang_en', child: Text('🇬🇧  English')),
              PopupMenuItem(value: 'lang_nl', child: Text('🇳🇱  Nederlands')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'leave', child: Text(l10n.translate('leave_org'))),
              PopupMenuItem(value: 'logout', child: Text(l10n.translate('logout'))),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          // CAL-03: Apply worker filter
          final filteredJobs = _selectedWorkerId == null 
            ? jobs 
            : jobs.where((j) => j.assignedWorkerId == _selectedWorkerId).toList();

          return Column(
            children: [
              // CAL-03: Admin Filter
              if (isAdmin && (ref.watch(moduleRegistryProvider)['CAL-03'] ?? false))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: workersAsync.when(
                    data: (workers) => DropdownButton<String?>(
                      value: _selectedWorkerId,
                      hint: const Text('Personel Filtresi', style: TextStyle(color: Colors.white70)),
                      dropdownColor: const Color(0xFF1A2A3A),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tüm Personeller')),
                        ...workers.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedWorkerId = val),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

              // Görünüm Seçici
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _ViewChip(label: l10n.translate('view_1day'), selected: _viewMode == 0, onTap: () => setState(() => _viewMode = 0)),
                    const SizedBox(width: 8),
                    _ViewChip(label: l10n.translate('view_3day'), selected: _viewMode == 3, onTap: () => setState(() => _viewMode = 3)),
                    const SizedBox(width: 8),
                    _ViewChip(label: l10n.translate('view_week'), selected: _viewMode == 1, onTap: () => setState(() => _viewMode = 1)),
                  ],
                ),
              ),

              // Zaman Bazlı Grid Takvim
              Expanded(
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7))),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobCreationScreen())),
              backgroundColor: const Color(0xFF1565C0),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.notStarted: return Colors.grey;
      case JobStatus.inProgress: return Colors.orange; // Yellow/Orange
      case JobStatus.workCompleted: return Colors.blue;
      case JobStatus.closed: return Colors.green;
    }
  }
  Widget _ViewChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4FC3F7) : const Color(0xFF1A2A3A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(color: selected ? const Color(0xFF0D1B2A) : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }}
