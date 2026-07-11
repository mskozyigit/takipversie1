import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../screens/job_detail_screen.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final bool isAdmin;
  final TranslationNotifier l10n;
  final Color onStatusColor;

  const JobCard({
    super.key,
    required this.job,
    required this.isAdmin,
    required this.l10n,
    required this.onStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2A3A),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(width: 4, height: double.infinity, color: onStatusColor),
        title: Text(job.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${isAdmin ? job.assignedWorkerName : job.address} • ${l10n.translate('job_status_${job.status.name}')}',
          style: const TextStyle(color: Color(0xFF90A4AE)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF4FC3F7)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
      ),
    );
  }
}
