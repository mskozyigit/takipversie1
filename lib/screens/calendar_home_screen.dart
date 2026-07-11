import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../models/job.dart';
import '../models/organization.dart';
import 'job_creation_screen.dart';
import 'job_checklist_screen.dart';
import 'job_detail_screen.dart';
import 'admin_dashboard.dart';
import 'module_settings_screen.dart';
import '../providers/module_provider.dart';
import '../widgets/calendar/job_card.dart';
import '../widgets/calendar/view_toggle.dart';
import '../widgets/calendar/join_code_card.dart';

class CalendarHomeScreen extends ConsumerStatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  ConsumerState<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends ConsumerState<CalendarHomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
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
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle (Aylık bazlı)
    final jobsAsync = isAdmin 
      ? ref.watch(allJobsProvider(_focusedDay)) 
      : ref.watch(workerJobsProvider(_focusedDay));
    final workersAsync = ref.watch(organizationWorkersProvider); // CAL-03
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title'), 
                 style: const TextStyle(fontSize: 16)),
            orgAsync.when(
              data: (org) => Text(org?.name ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        backgroundColor: isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Modüller',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
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
              }
            },
            itemBuilder: (context) => [
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

          final selectedJobs = filteredJobs.where((job) => isSameDay(job.scheduledDate, _selectedDay)).toList();

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

              // Organizasyon Katılım Kartı (HERKES İÇİN - Admin kodu görsün, İşçi sadece bilsin)
              orgAsync.when(
                data: (org) => org == null ? const SizedBox() : JoinCodeCard(org: org, showCode: isAdmin),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),

              // Görünüm Seçici
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ViewToggle(
                        label: l10n.translate('view_1day'),
                        isSelected: _viewMode == 0,
                        onTap: () => setState(() {
                          _viewMode = 0;
                          _calendarFormat = CalendarFormat.week;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ViewToggle(
                        label: l10n.translate('view_3day'),
                        isSelected: _viewMode == 3,
                        onTap: () => setState(() {
                          _viewMode = 3;
                          _calendarFormat = CalendarFormat.week;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ViewToggle(
                        label: l10n.translate('view_week'),
                        isSelected: _viewMode == 1,
                        onTap: () => setState(() {
                          _viewMode = 1;
                          _calendarFormat = CalendarFormat.week;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ViewToggle(
                        label: l10n.translate('view_month'),
                        isSelected: _viewMode == 2,
                        onTap: () => setState(() {
                          _viewMode = 2;
                          _calendarFormat = CalendarFormat.month;
                        }),
                      ),
                    ],
                  ),
                ),
              ),

              if (_viewMode != 3) // Hafta/Ay/Gün görünümlerinde takvimi göster
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                      if (format == CalendarFormat.month) _viewMode = 2;
                      if (format == CalendarFormat.week) _viewMode = 1;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: const TextStyle(color: Colors.white),
                    weekendTextStyle: const TextStyle(color: Color(0xFF90A4AE)),
                    selectedDecoration: const BoxDecoration(color: Color(0xFF4FC3F7), shape: BoxShape.circle),
                    todayDecoration: const BoxDecoration(color: Color(0xFF1A2A3A), shape: BoxShape.circle),
                    markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
                    leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                    rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                  eventLoader: (day) {
                    return filteredJobs.where((job) => isSameDay(job.scheduledDate, day)).toList();
                  },
                ),
              
              const Divider(color: Color(0xFF1A2A3A), thickness: 2),
              
              Expanded(
                child: _viewMode == 3
                    ? _buildAgendaView(filteredJobs, l10n, isAdmin)
                    : _buildJobList(selectedJobs, l10n, isAdmin),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
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

  Widget _buildJobList(List<Job> selectedJobs, TranslationNotifier l10n, bool isAdmin) {
    if (selectedJobs.isEmpty) {
      return Center(child: Text(l10n.translate('admin_no_pending'), style: const TextStyle(color: Color(0xFF90A4AE))));
    }
    return ListView.builder(
      itemCount: selectedJobs.length,
      itemBuilder: (context, index) {
        final job = selectedJobs[index];
        return JobCard(job: job, isAdmin: isAdmin, onStatusColor: _getStatusColor(job.status));
      },
    );
  }

  Widget _buildAgendaView(List<Job> allJobs, TranslationNotifier l10n, bool isAdmin) {
    final startDay = _selectedDay ?? _focusedDay;
    final days = List.generate(3, (i) => startDay.add(Duration(days: i)));

    return Row(
      children: days.map((day) {
        final dayJobs = allJobs.where((j) => isSameDay(j.scheduledDate, day)).toList();
        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFF1A2A3A),
                  width: double.infinity,
                  child: Text(
                    '${day.day} ${_getMonthName(day.month)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: dayJobs.length,
                    itemBuilder: (context, i) {
                      final job = dayJobs[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(job.status).withOpacity(0.2),
                            border: Border(left: BorderSide(color: _getStatusColor(job.status), width: 3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(job.title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(isAdmin ? job.assignedWorkerName : job.address, style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getMonthName(int month) {
    const names = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return names[month - 1];
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.notStarted: return Colors.grey;
      case JobStatus.inProgress: return Colors.orange; // Yellow/Orange
      case JobStatus.workCompleted: return Colors.blue;
      case JobStatus.closed: return Colors.green;
    }
  }
}
