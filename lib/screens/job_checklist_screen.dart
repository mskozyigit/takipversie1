import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/job.dart';
import '../models/organization.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../providers/module_provider.dart';
import '../widgets/checklist/safety_step.dart';
import '../widgets/checklist/payment_step.dart';
import '../widgets/checklist/parts_step.dart';
import '../widgets/checklist/photo_step.dart';
import 'package:url_launcher/url_launcher.dart';

class JobChecklistScreen extends ConsumerStatefulWidget {
  final Job job;
  const JobChecklistScreen({super.key, required this.job});

  @override
  ConsumerState<JobChecklistScreen> createState() => _JobChecklistScreenState();
}

class _JobChecklistScreenState extends ConsumerState<JobChecklistScreen> {
  int _currentStep = 0;
  String? _beforePhotoUrl;
  String? _afterPhotoUrl;
  final _noteController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.job.status == JobStatus.inProgress) {
      _currentStep = 1;
    } else if (widget.job.status == JobStatus.workCompleted || widget.job.status == JobStatus.closed) {
      // Bitmiş işler: düzenleme için direkt fotoğraf adımından başla, sıfırdan başlama
      _currentStep = 1;
    }
    _beforePhotoUrl = widget.job.beforePhotoUrl;
    _afterPhotoUrl = widget.job.afterPhotoUrl;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(bool isBefore) async {
    final l10n = ref.read(translationProvider.notifier);
    
    // Show source picker dialog first (avoids camera activity lifecycle issues on mobile)
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Text('Fotoğraf Ekle', style: TextStyle(color: Colors.white)),
        content: const Text('Nereden fotoğraf eklemek istersiniz?', style: TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library, color: Color(0xFF4FC3F7), size: 20),
                SizedBox(width: 8),
                Text('Galeri', style: TextStyle(color: Color(0xFF4FC3F7))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Kamera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (source == null || !mounted) return;
    
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadJobPhoto(
        jobId: widget.job.id,
        isBefore: isBefore,
        source: source,
      );
      if (url != null) {
        await ref.read(jobOperationsProvider.notifier).updateJobPhotos(
          widget.job.id,
          beforeUrl: isBefore ? url : null,
          afterUrl: isBefore ? null : url,
        );
        setState(() {
          if (isBefore) _beforePhotoUrl = url;
          else _afterPhotoUrl = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isBefore ? 'İş öncesi fotoğraf yüklendi ✓' : 'İş sonrası fotoğraf yüklendi ✓'), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_photo_error', {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _nextStep() async {
    final l10n = ref.read(translationProvider.notifier);
    final registry = ref.read(moduleRegistryProvider);
    final isMandatory = registry['JOB-03'] ?? false;
    final isSafetyOn = registry['SAFE-01'] ?? false;

    // Steps: 0=Start, 1=BeforePhoto, 2=Note, 3=AfterPhoto, 4(or5)=Safety, 5(or6)=Finish, 6(or7)=Payment
    final safetyOffset = isSafetyOn ? 1 : 0;
    final finishStep = 4 + safetyOffset;
    final paymentStep = 5 + safetyOffset;
    final lastStep = paymentStep;

    if (_currentStep == 0) {
      // Sadece hiç başlamamış işler için status'ü inProgress yap
      if (widget.job.status == JobStatus.notStarted) {
        await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.inProgress);
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Before Photo
      if (isMandatory && _beforePhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_before_photo_needed'))));
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Note
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // After Photo
      if (isMandatory && _afterPhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_after_photo_needed'))));
        return;
      }
      setState(() => _currentStep = isSafetyOn ? 4 : finishStep);
    } else if (isSafetyOn && _currentStep == 4) {
      if (!widget.job.isSafetyConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen güvenlik kontrolünü onaylayın.')));
        return;
      }
      setState(() => _currentStep = finishStep);
    } else if (_currentStep == finishStep) {
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.workCompleted);
      setState(() => _currentStep = paymentStep);
    } else if (_currentStep == paymentStep) {
      if (isMandatory && !widget.job.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_payment_needed'))));
        return;
      }
      if (mounted) Navigator.pop(context);
    }
  }

  void _prevStep() {
    // Bitmiş işlerde "Başlat" adımına geri dönme
    final minStep = (widget.job.status == JobStatus.workCompleted || widget.job.status == JobStatus.closed) ? 1 : 0;
    if (_currentStep > minStep) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _launchMaps(String address) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    final org = ref.watch(currentOrganizationProvider).value;
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${widget.job.missionNumber} - ${widget.job.title}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF0D47A1),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stepper(
              physics: const NeverScrollableScrollPhysics(),
              type: StepperType.vertical,
              currentStep: _currentStep,
        onStepContinue: _isUploading ? null : _nextStep,
        onStepCancel: _prevStep,
        onStepTapped: (step) {
          if (step < _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          final isSafetyOn = (ref.read(moduleRegistryProvider)['SAFE-01'] ?? false);
          final lastStep = isSafetyOn ? 6 : 5;
          final isCompleted = widget.job.status == JobStatus.workCompleted || widget.job.status == JobStatus.closed;
          final minStep = isCompleted ? 1 : 0;
          final isFirst = _currentStep == minStep;
          final isLast = _currentStep == lastStep;
          final finishStep = isSafetyOn ? 5 : 4;

          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (!isFirst)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(l10n.translate('job_checklist_back'), style: const TextStyle(color: Color(0xFF90A4AE))),
                  ),
                if (!isFirst) const Spacer(),
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast ? Colors.green : const Color(0xFF1565C0),
                    minimumSize: const Size(120, 45),
                  ),
                  child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        isLast 
                          ? l10n.translate('job_checklist_finish') 
                          : (isFirst ? (isCompleted ? 'Düzenle' : l10n.translate('job_checklist_start')) : l10n.translate('job_checklist_next')),
                        style: const TextStyle(color: Colors.white),
                      ),
                ),
              ],
            ),
          );
        },
        steps: _buildSteps(l10n, org),
      ),
    ],
  ),
),
);
}

  List<Step> _buildSteps(dynamic l10n, dynamic org) {
    final isSafetyOn = ref.watch(moduleRegistryProvider)['SAFE-01'] ?? false;

    return [
      // 0: Start
      Step(
        title: Text(l10n.translate('job_checklist_start'), style: const TextStyle(color: Colors.white)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.translate('job_description')}: ${widget.job.description}', style: const TextStyle(color: Color(0xFF90A4AE))),
            const SizedBox(height: 8),
            Text('${l10n.translate('job_address')}: ${widget.job.address}', style: const TextStyle(color: Color(0xFF90A4AE))),
          ],
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      // 1: Before Photo
      Step(
        title: Text(l10n.translate('job_before_photo'), style: const TextStyle(color: Colors.white)),
        content: PhotoStep(url: _beforePhotoUrl, onTap: () => _takePhoto(true), isUploading: _isUploading && _currentStep == 1),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      // 2: Note
      Step(
        title: Text(l10n.translate('job_checklist_note'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: _noteController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.translate('job_notes_hint'),
            hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
            filled: true,
            fillColor: const Color(0xFF1A2A3A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      // 3: After Photo
      Step(
        title: Text(l10n.translate('job_after_photo'), style: const TextStyle(color: Colors.white)),
        content: PhotoStep(url: _afterPhotoUrl, onTap: () => _takePhoto(false), isUploading: _isUploading && _currentStep == 3),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      ),
      // 4: Safety (conditional)
      if (isSafetyOn)
        Step(
          title: Text(l10n.translate('safe_checklist_title'), style: const TextStyle(color: Colors.white)),
          content: SafetyStep(job: widget.job),
          isActive: _currentStep >= 4,
          state: _currentStep > 4 ? StepState.complete : StepState.indexed,
        ),
      // Finish
      Step(
        title: Text(l10n.translate('job_checklist_finish'), style: const TextStyle(color: Colors.white)),
        content: Text(l10n.translate('job_checklist_completed_msg'), style: const TextStyle(color: Color(0xFF90A4AE))),
        isActive: _currentStep >= (isSafetyOn ? 5 : 4),
        state: _currentStep > (isSafetyOn ? 5 : 4) ? StepState.complete : StepState.indexed,
      ),
      // Payment
      Step(
        title: Text(l10n.translate('job_payment_title'), style: const TextStyle(color: Colors.white)),
        content: PaymentStep(job: widget.job, org: org),
        isActive: _currentStep >= (isSafetyOn ? 6 : 5),
        state: _currentStep > (isSafetyOn ? 6 : 5) ? StepState.complete : StepState.indexed,
      ),
    ];
  }
}
