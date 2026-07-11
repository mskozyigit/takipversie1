import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../models/job.dart';
import '../models/organization.dart';
import 'job_creation_screen.dart';
import 'job_checklist_screen.dart';
import 'admin_dashboard.dart';

class CalendarHomeScreen extends ConsumerStatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  ConsumerState<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends ConsumerState<CalendarHomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _isMultiDayView = false;

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
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle
    final jobsAsync = isAdmin ? ref.watch(allJobsProvider) : ref.watch(workerJobsProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title')),
        backgroundColor: isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: l10n.translate('admin_pending_users'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminDashboard(adminUser: (authState as ApprovedAdmin).appUser)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final selectedJobs = jobs.where((job) => isSameDay(job.scheduledDate, _selectedDay)).toList();

          return Column(
            children: [
              // Admin için Join Code Kartı
              if (isAdmin)
                orgAsync.when(
                  data: (org) => org == null ? const SizedBox() : _JoinCodeCard(org: org, l10n: l10n),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),

              // Görünüm Seçici (3 Gün, Hafta, Ay)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ViewToggle(
                        label: l10n.translate('view_3day'),
                        isSelected: _calendarFormat == CalendarFormat.week && _isMultiDayView,
                        onTap: () => setState(() {
                          _calendarFormat = CalendarFormat.week;
                          _isMultiDayView = true;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _ViewToggle(
                        label: l10n.translate('view_week'),
                        isSelected: _calendarFormat == CalendarFormat.week && !_isMultiDayView,
                        onTap: () => setState(() {
                          _calendarFormat = CalendarFormat.week;
                          _isMultiDayView = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _ViewToggle(
                        label: l10n.translate('view_month'),
                        isSelected: _calendarFormat == CalendarFormat.month,
                        onTap: () => setState(() {
                          _calendarFormat = CalendarFormat.month;
                          _isMultiDayView = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),

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
                    _isMultiDayView = false;
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
                  return jobs.where((job) => isSameDay(job.scheduledDate, day)).toList();
                },
              ),
              const Divider(color: Color(0xFF1A2A3A), thickness: 2),
              Expanded(
                child: _isMultiDayView
                    ? _buildMultiDayView(jobs, l10n, isAdmin)
                    : _buildSingleDayList(selectedJobs, l10n, isAdmin),
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

  Widget _buildSingleDayList(List<Job> selectedJobs, TranslationNotifier l10n, bool isAdmin) {
    if (selectedJobs.isEmpty) {
      return Center(child: Text(l10n.translate('admin_no_pending'), style: const TextStyle(color: Color(0xFF90A4AE))));
    }
    return ListView.builder(
      itemCount: selectedJobs.length,
      itemBuilder: (context, index) {
        final job = selectedJobs[index];
        return Card(
          color: const Color(0xFF1A2A3A),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Container(
              width: 4,
              height: double.infinity,
              color: _getStatusColor(job.status),
            ),
            title: Text(job.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${isAdmin ? job.assignedWorkerName : job.address} • ${l10n.translate('job_status_${job.status.name}')}',
              style: const TextStyle(color: Color(0xFF90A4AE)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF4FC3F7)),
            onTap: () {
              if (!isAdmin) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => JobChecklistScreen(job: job)));
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMultiDayView(List<Job> allJobs, TranslationNotifier l10n, bool isAdmin) {
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
                      return Container(
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
      case JobStatus.inProgress: return Colors.blue;
      case JobStatus.workCompleted: return Colors.green;
      case JobStatus.closed: return Colors.deepPurple;
    }
  }
}

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggle({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4FC3F7) : const Color(0xFF1A2A3A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0D1B2A) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  final Organization org;
  final TranslationNotifier l10n;

  const _JoinCodeCard({required this.org, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1565C0), width: 1),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(org.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${l10n.translate('admin_join_code')}: ${org.joinCode}',
                  style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, color: Color(0xFF4FC3F7), size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
