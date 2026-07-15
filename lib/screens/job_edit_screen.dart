import 'package:flutter/material.dart';
import '../models/job.dart';
import '../widgets/job_form.dart';

/// Thin wrapper — all form logic lives in the shared [JobForm] widget.
class JobEditScreen extends StatelessWidget {
  final Job job;
  const JobEditScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) => JobForm(mode: JobFormMode.edit, initialJob: job);
}
