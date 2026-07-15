import 'package:flutter/material.dart';
import '../widgets/job_form.dart';

/// Thin wrapper — all form logic lives in the shared [JobForm] widget.
class JobCreationScreen extends StatelessWidget {
  const JobCreationScreen({super.key});

  @override
  Widget build(BuildContext context) => const JobForm(mode: JobFormMode.create);
}
