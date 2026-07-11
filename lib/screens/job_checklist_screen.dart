import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';

class JobChecklistScreen extends ConsumerStatefulWidget {
  final Job job;
  const JobChecklistScreen({super.key, required this.job});

  @override
  ConsumerState<JobChecklistScreen> createState() => _JobChecklistScreenState();
}

class _JobChecklistScreenState extends ConsumerState<JobChecklistScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Eğer iş zaten başladıysa adımı güncelle
    if (widget.job.status == JobStatus.inProgress) {
      _currentStep = 1;
    }
  }

  void _nextStep() async {
    final l10n = ref.read(translationProvider.notifier);
    
    if (_currentStep == 0) {
      // Start -> In Progress
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.inProgress);
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Location verified (simulated)
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Note added (simulated)
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // Finish -> Work Completed
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.workCompleted);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(widget.job.title),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _nextStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 3 ? Colors.green : const Color(0xFF1565C0),
                minimumSize: const Size(120, 45),
              ),
              child: Text(
                _currentStep == 3 ? l10n.translate('job_checklist_finish') : l10n.translate('job_checklist_start'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
        steps: [
          Step(
            title: Text(l10n.translate('job_checklist_start'), style: const TextStyle(color: Colors.white)),
            content: Text(l10n.translate('job_description') + ': ' + widget.job.description, style: const TextStyle(color: Color(0xFF90A4AE))),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_checklist_location'), style: const TextStyle(color: Colors.white)),
            content: Text(widget.job.address, style: const TextStyle(color: Color(0xFF90A4AE))),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_checklist_note'), style: const TextStyle(color: Colors.white)),
            content: const TextField(
              decoration: InputDecoration(
                hintText: 'İşle ilgili notlarınızı girin...',
                hintStyle: TextStyle(color: Color(0xFF546E7A)),
              ),
              style: TextStyle(color: Colors.white),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_checklist_finish'), style: const TextStyle(color: Colors.white)),
            content: Text('Tüm adımlar tamamlandı. İşi bitirebilirsiniz.', style: const TextStyle(color: Color(0xFF90A4AE))),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }
}
