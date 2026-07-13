import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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
import '../widgets/checklist/multi_photo_picker.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class JobChecklistScreen extends ConsumerStatefulWidget {
  final Job job;
  const JobChecklistScreen({super.key, required this.job});

  @override
  ConsumerState<JobChecklistScreen> createState() => _JobChecklistScreenState();
}

class _JobChecklistScreenState extends ConsumerState<JobChecklistScreen> {
  int _currentStep = 0;
  late List<String> _beforePhotoUrls;
  late List<String> _afterPhotoUrls;
  final _noteController = TextEditingController();
  bool _isUploading = false;
  bool _isPaid = false;
  late List<String> _checklistNotes;

  @override
  void initState() {
    super.initState();
    if (widget.job.status == JobStatus.inProgress) {
      _currentStep = 1;
    } else if (widget.job.status == JobStatus.workCompleted || widget.job.status == JobStatus.closed) {
      _currentStep = 1;
    }
    _beforePhotoUrls = List.from(widget.job.beforePhotoUrls);
    _afterPhotoUrls = List.from(widget.job.afterPhotoUrls);
    _isPaid = widget.job.isPaid;
    _checklistNotes = List.from(widget.job.checklistNotes);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Pick and upload a photo. Returns the download URL, or null if cancelled/failed.
  Future<String?> _pickAndUploadPhoto(bool isBefore) async {
    final l10n = ref.read(translationProvider.notifier);
    
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('photo_add_title'), style: const TextStyle(color: Colors.white)),
        content: Text(l10n.translate('photo_add_source'), style: const TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library, color: Color(0xFF4FC3F7), size: 20),
                const SizedBox(width: 8),
                Text(l10n.translate('photo_gallery'), style: const TextStyle(color: Color(0xFF4FC3F7))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: Text(l10n.translate('photo_camera')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (source == null || !mounted) return null;
    
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadJobPhoto(
        jobId: widget.job.id,
        isBefore: isBefore,
        source: source,
      );
      if (url != null) {
        await ref.read(jobOperationsProvider.notifier).addJobPhoto(
          widget.job.id,
          url: url,
          isBefore: isBefore,
        );
        setState(() {
          if (isBefore) {
            _beforePhotoUrls.add(url);
          } else {
            _afterPhotoUrls.add(url);
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate(isBefore ? 'photo_before_uploaded' : 'photo_after_uploaded')), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
          );
        }
        return url;
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final msg = e.code == 'unavailable'
            ? l10n.translate('checklist_photo_offline')
            : l10n.translate('job_checklist_photo_error', {'error': e.message ?? 'Unknown error'});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
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
    return null;
  }

  Future<void> _deletePhoto(bool isBefore, int index) async {
    final urls = isBefore ? List.from(_beforePhotoUrls) : List.from(_afterPhotoUrls);
    urls.removeAt(index);
    setState(() {
      if (isBefore) {
        _beforePhotoUrls = urls;
      } else {
        _afterPhotoUrls = urls;
      }
    });
    await ref.read(jobOperationsProvider.notifier).updateJobPhotos(
      widget.job.id,
      beforeUrls: isBefore ? urls : null,
      afterUrls: isBefore ? null : urls,
    );
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
      if (isMandatory && _beforePhotoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_before_photo_needed')), backgroundColor: Colors.orange));
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Note — save to checklistNotes on the job (visible to both worker & admin)
      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        await ref.read(jobOperationsProvider.notifier).addChecklistNote(widget.job.id, note);
        _checklistNotes.add(note); // Update local list for instant UI
        _noteController.clear(); // Clear input for next note
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // After Photo
      if (isMandatory && _afterPhotoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_after_photo_needed')), backgroundColor: Colors.orange));
        return;
      }
      setState(() => _currentStep = isSafetyOn ? 4 : finishStep);
    } else if (isSafetyOn && _currentStep == 4) {
      if (!widget.job.isSafetyConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('safe_checklist_confirm_required')), backgroundColor: Colors.orange));
        return;
      }
      setState(() => _currentStep = finishStep);
    } else if (_currentStep == finishStep) {
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.workCompleted);
      setState(() => _currentStep = paymentStep);
    } else if (_currentStep == paymentStep) {
      // Re-check isPaid from local state (set by PaymentStep via callback)
      if (isMandatory && !_isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_payment_needed')), backgroundColor: Colors.orange));
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
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    final org = ref.watch(currentOrganizationProvider).value;
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.job.missionNumber} - ${widget.job.title}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF0D47A1),
      ),
      body: SafeArea(
        bottom: true,
        child: Scrollbar(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
          children: [
            Stepper(
              physics: const AlwaysScrollableScrollPhysics(),
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
                          : (isFirst ? (isCompleted ? l10n.translate('button_edit') : l10n.translate('job_checklist_start')) : l10n.translate('job_checklist_next')),
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
        content: MultiPhotoPicker(
          photoUrls: _beforePhotoUrls,
          label: l10n.translate('before_photo_label'),
          isUploading: _isUploading && _currentStep == 1,
          onPickPhoto: () => _pickAndUploadPhoto(true),
          onPhotosChanged: (urls) async {
            setState(() => _beforePhotoUrls = urls);
            await ref.read(jobOperationsProvider.notifier).updateJobPhotos(
              widget.job.id,
              beforeUrls: urls,
            );
          },
        ),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      // 2: Note
      Step(
        title: Text(l10n.translate('job_checklist_note'), style: const TextStyle(color: Colors.white)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show previously saved checklist notes
            if (_checklistNotes.isNotEmpty) ...[
              Text(l10n.translate('job_checklist_previous_notes'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._checklistNotes.map((note) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF37474F)),
                ),
                child: Text(note, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
              )),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l10n.translate('job_notes_hint'),
                hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      // 3: After Photo
      Step(
        title: Text(l10n.translate('job_after_photo'), style: const TextStyle(color: Colors.white)),
        content: MultiPhotoPicker(
          photoUrls: _afterPhotoUrls,
          label: l10n.translate('after_photo_label'),
          isUploading: _isUploading && _currentStep == 3,
          onPickPhoto: () => _pickAndUploadPhoto(false),
          onPhotosChanged: (urls) async {
            setState(() => _afterPhotoUrls = urls);
            await ref.read(jobOperationsProvider.notifier).updateJobPhotos(
              widget.job.id,
              afterUrls: urls,
            );
          },
        ),
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
        content: PaymentStep(job: widget.job, org: org, onPaymentRecorded: () => setState(() => _isPaid = true)),
        isActive: _currentStep >= (isSafetyOn ? 6 : 5),
        state: _currentStep > (isSafetyOn ? 6 : 5) ? StepState.complete : StepState.indexed,
      ),
    ];
  }
}
