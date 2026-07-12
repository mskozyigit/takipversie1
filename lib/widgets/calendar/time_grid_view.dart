import 'package:flutter/material.dart';
import '../../models/job.dart';

/// Time-based grid calendar view (Day / 3-Day / Week)
class TimeGridView extends StatelessWidget {
  final List<Job> jobs;
  final DateTime focusedDay;
  final int viewMode; // 0=Day, 3=3-Day, 1=Week
  final void Function(Job) onJobTap;
  final Color Function(JobStatus) statusColor;

  const TimeGridView({
    super.key,
    required this.jobs,
    required this.focusedDay,
    required this.viewMode,
    required this.onJobTap,
    required this.statusColor,
  });

  int get columnCount {
    switch (viewMode) {
      case 0: return 1;  // Day
      case 3: return 3;  // 3-Day
      case 1: return 7;  // Week
      default: return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(columnCount, (i) {
      final d = focusedDay.add(Duration(days: i));
      return d;
    });

    final hours = List.generate(11, (i) => i + 8); // 08:00 - 18:00

    return SingleChildScrollView(
      child: Column(
        children: [
          // Day headers
          _buildDayHeaders(days),
          // Time grid
          SizedBox(
            height: hours.length * 60.0,
            child: Row(
              children: [
                // Hour labels
                SizedBox(
                  width: 50,
                  child: Column(
                    children: hours.map((h) => SizedBox(
                      height: 60,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 10),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                // Day columns
                ...days.map((day) => Expanded(child: _DayColumn(
                  day: day,
                  hours: hours,
                  jobs: _jobsForDay(day),
                  onJobTap: onJobTap,
                  statusColor: statusColor,
                ))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders(List<DateTime> days) {
    final dayNames = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PAZ'];
    final monthNames = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A2A3A))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 50),
          ...days.map((d) {
            final isToday = d.day == DateTime.now().day && d.month == DateTime.now().month && d.year == DateTime.now().year;
            return Expanded(
              child: Column(
                children: [
                  Text(dayNames[d.weekday - 1], style: TextStyle(color: isToday ? const Color(0xFF4FC3F7) : const Color(0xFF90A4AE), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isToday ? const Color(0xFF1565C0) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text('${d.day}', style: TextStyle(color: isToday ? Colors.white : const Color(0xFF90A4AE), fontSize: 14, fontWeight: FontWeight.bold))),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Job> _jobsForDay(DateTime day) {
    return jobs.where((j) =>
      j.scheduledDate.year == day.year &&
      j.scheduledDate.month == day.month &&
      j.scheduledDate.day == day.day
    ).toList();
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<int> hours;
  final List<Job> jobs;
  final void Function(Job) onJobTap;
  final Color Function(JobStatus) statusColor;

  const _DayColumn({required this.day, required this.hours, required this.jobs, required this.onJobTap, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Grid lines
        Column(
          children: hours.map((h) => Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1A2A3A), width: 0.5)),
              ),
            ),
          )).toList(),
        ),
        // Job cards
        ...jobs.map((job) {
          final hour = job.scheduledDate.hour.clamp(8, 17);
          final top = (hour - 8) * 60.0;
          // Distribute jobs within the hour
          final indexInHour = jobs.where((j) => j.scheduledDate.hour == hour).toList().indexOf(job);
          final topOffset = top + (indexInHour * 20.0);

          return Positioned(
            top: topOffset,
            left: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => onJobTap(job),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: statusColor(job.status).withOpacity(0.25),
                  border: Border(left: BorderSide(color: statusColor(job.status), width: 3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(job.title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (job.description.isNotEmpty)
                      Text(job.description, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 8), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (job.customerName != null && job.customerName!.isNotEmpty)
                      Text(job.customerName!, style: const TextStyle(color: Color(0xFF546E7A), fontSize: 7), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
