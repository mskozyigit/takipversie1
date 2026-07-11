import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../models/job.dart';
import 'job_creation_screen.dart';
import 'job_checklist_screen.dart';

class CalendarHomeScreen extends ConsumerStatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  ConsumerState<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends ConsumerState<CalendarHomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final isAdmin = authState is ApprovedAdmin;
    
    // Admin ise tüm işleri, Worker ise sadece kendine atananları izle
    final jobsAsync = isAdmin ? ref.watch(allJobsProvider) : ref.watch(workerJobsProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(isAdmin ? l10n.translate('admin_panel_title') : l10n.translate('worker_panel_title')),
        backgroundColor: isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1),
        actions: [
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
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
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
                child: selectedJobs.isEmpty
                    ? Center(child: Text(l10n.translate('admin_no_pending'), style: const TextStyle(color: Color(0xFF90A4AE))))
                    : ListView.builder(
                        itemCount: selectedJobs.length,
                        itemBuilder: (context, index) {
                          final job = selectedJobs[index];
                          return Card(
                            color: const Color(0xFF1A2A3A),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(job.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${job.assignedWorkerName} • ${job.status.name}',
                                style: TextStyle(color: _getStatusColor(job.status)),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Color(0xFF4FC3F7)),
                              onTap: () {
                                if (isAdmin) {
                                  // Admin için iş detay veya düzenleme (ileride)
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => JobChecklistScreen(job: job)));
                                }
                              },
                            ),
                          );
                        },
                      ),
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

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.notStarted: return Colors.grey;
      case JobStatus.inProgress: return Colors.blue;
      case JobStatus.workCompleted: return Colors.green;
      case JobStatus.closed: return Colors.deepPurple;
    }
  }
}
