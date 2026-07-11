import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../models/organization.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
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
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Eğer iş zaten başladıysa adımı güncelle
    if (widget.job.status == JobStatus.inProgress) {
      _currentStep = 1;
    }
    _beforePhotoUrl = widget.job.beforePhotoUrl;
    _afterPhotoUrl = widget.job.afterPhotoUrl;
  }

  Future<void> _takePhoto(bool isBefore) async {
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadJobPhoto(
        jobId: widget.job.id,
        isBefore: isBefore,
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
    
    if (_currentStep == 0) {
      // Start -> In Progress
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.inProgress);
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Before Photo Step
      if (isMandatory && _beforePhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_before_photo_needed'))),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Materials Step (Allowing skip if none used, but usually some are)
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // After Photo Step
      if (isMandatory && _afterPhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_after_photo_needed'))),
        );
        return;
      }
      // If Safety is ON, next is Safety, else Payment
      setState(() => _currentStep = isSafetyOn ? 4 : 5);
    } else if (_currentStep == 4) {
      // Safety Checklist Step
      if (!widget.job.isSafetyConfirmed) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen güvenlik kontrolünü onaylayın.')),
        );
        return;
      }
      setState(() => _currentStep = 5);
    } else if (_currentStep == 5) {
      // Payment Step
      if (isMandatory && !widget.job.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_payment_needed'))),
        );
        return;
      }
      setState(() => _currentStep = 6);
    } else if (_currentStep == 6) {
      // Finish -> Work Completed
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.workCompleted);
      if (mounted) Navigator.pop(context);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${widget.job.missionNumber} - ${widget.job.title}'),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stepper(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
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
          final isFirst = _currentStep == 0;
          final isLast = _currentStep == 6;

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
                          : (isFirst ? l10n.translate('job_checklist_start') : l10n.translate('job_checklist_next')),
                        style: const TextStyle(color: Colors.white),
                      ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(l10n.translate('job_checklist_start'), style: const TextStyle(color: Colors.white)),
            content: InkWell(
              onTap: () => _launchMaps(widget.job.address),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.translate('job_description') + ': ' + widget.job.description, style: const TextStyle(color: Color(0xFF90A4AE))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.map, color: Color(0xFF4FC3F7), size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(widget.job.address, style: const TextStyle(color: Color(0xFF4FC3F7), decoration: TextDecoration.underline))),
                    ],
                  ),
                ],
              ),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_before_photo'), style: const TextStyle(color: Colors.white)),
            content: _PhotoUploadContent(
              url: _beforePhotoUrl,
              onTap: () => _takePhoto(true),
              l10n: l10n,
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_parts_title'), style: const TextStyle(color: Colors.white)),
            content: _PartsContent(job: widget.job, l10n: l10n, ref: ref),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_after_photo'), style: const TextStyle(color: Colors.white)),
            content: _PhotoUploadContent(
              url: _afterPhotoUrl,
              onTap: () => _takePhoto(false),
              l10n: l10n,
            ),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
          if (ref.watch(moduleRegistryProvider)['SAFE-01'] ?? false)
            Step(
              title: Text(l10n.translate('safe_checklist_title'), style: const TextStyle(color: Colors.white)),
              content: _SafetyContent(job: widget.job, l10n: l10n, ref: ref),
              isActive: _currentStep >= 4,
              state: _currentStep > 4 ? StepState.complete : StepState.indexed,
            ),
          Step(
            title: Text(l10n.translate('job_payment_title'), style: const TextStyle(color: Colors.white)),
            content: _PaymentContent(job: widget.job, org: org, l10n: l10n, ref: ref),
            isActive: _currentStep >= 5,
            state: _currentStep > 5 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_checklist_finish'), style: const TextStyle(color: Colors.white)),
            content: Text(l10n.translate('job_checklist_completed_msg'), style: const TextStyle(color: Color(0xFF90A4AE))),
            isActive: _currentStep >= 6,
            state: _currentStep == 6 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
      const Divider(color: Color(0xFF1A2A3A), thickness: 2),
      _CommentsSection(jobId: widget.job.id, l10n: l10n),
    ],
  ),
),
);
}

class _CommentsSection extends ConsumerWidget {
  final String jobId;
  final TranslationNotifier l10n;
  const _CommentsSection({required this.jobId, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider(jobId));
    final controller = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('job_notes_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          commentsAsync.when(
            data: (comments) => ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, i) {
                final c = comments[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${c.authorName}: ${c.text}', style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                );
              },
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(l10n.translate('error_loading', {'error': e.toString()})),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(hintText: l10n.translate('job_notes_hint'), hintStyle: const TextStyle(color: Color(0xFF546E7A))),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF4FC3F7)),
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    ref.read(jobOperationsProvider.notifier).addComment(jobId, controller.text.trim());
                    controller.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartsContent extends StatelessWidget {
  final Job job;
  final TranslationNotifier l10n;
  final WidgetRef ref;

  const _PartsContent({required this.job, required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (job.usedParts != null)
          ...job.usedParts!.map((p) => ListTile(
            title: Text(p['name'], style: const TextStyle(color: Colors.white)),
            trailing: Text('x${p['qty']}', style: const TextStyle(color: Color(0xFF4FC3F7))),
          )),
        OutlinedButton.icon(
          onPressed: () async {
            final nameController = TextEditingController();
            final qtyController = TextEditingController(text: '1');
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.translate('job_add_part')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(hintText: 'Parça Adı')),
                    TextField(controller: qtyController, decoration: const InputDecoration(hintText: 'Adet'), keyboardType: TextInputType.number),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                  TextButton(onPressed: () {
                    ref.read(jobOperationsProvider.notifier).addJobPart(job.id, {
                      'name': nameController.text,
                      'qty': int.tryParse(qtyController.text) ?? 1,
                    });
                    Navigator.pop(ctx);
                  }, child: const Text('Ekle')),
                ],
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: Text(l10n.translate('job_add_part')),
        ),
      ],
    );
  }
}

class _PaymentContent extends StatelessWidget {
  final Job job;
  final Organization? org;
  final TranslationNotifier l10n;
  final WidgetRef ref;

  const _PaymentContent({required this.job, this.org, required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (job.isPaid) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(l10n.translate('job_payment_received') + ' (${job.paymentMethod == 'cash' ? l10n.translate('job_payment_cash') : l10n.translate('job_payment_qr')})',
               style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (org?.paymentQrUrl != null)
          Container(
            height: 200,
            width: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: NetworkImage(org!.paymentQrUrl!), fit: BoxFit.contain),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(l10n.translate('job_payment_qr_not_available'), style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ),
        Row(
          children: [
            if (org?.paymentQrUrl != null)
              ElevatedButton(
                onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'qr'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7)),
                child: Text(l10n.translate('job_payment_qr'), style: const TextStyle(color: Color(0xFF0D1B2A))),
              ),
            if (org?.paymentQrUrl != null) const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'cash'),
              child: Text(l10n.translate('job_payment_cash')),
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoUploadContent extends StatelessWidget {
  final String? url;
  final VoidCallback onTap;
  final TranslationNotifier l10n;

  const _PhotoUploadContent({required this.url, required this.onTap, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (url != null)
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.camera_alt),
          label: Text(url == null ? 'Fotoğraf Çek' : 'Fotoğrafı Değiştir'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF4FC3F7)),
        ),
      ],
    );
  }
}

class _SafetyContent extends StatelessWidget {
  final Job job;
  final TranslationNotifier l10n;
  final WidgetRef ref;

  const _SafetyContent({required this.job, required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    final checklist = job.safetyChecklist ?? {
      'ppe': false,
      'hazard': false,
      'lockout': false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_ppe'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['ppe'],
          onChanged: (val) => _update(checklist, 'ppe', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_hazard'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['hazard'],
          onChanged: (val) => _update(checklist, 'hazard', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        CheckboxListTile(
          title: Text(l10n.translate('safe_checklist_item_lockout'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          value: checklist['lockout'],
          onChanged: (val) => _update(checklist, 'lockout', val ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF4FC3F7),
        ),
        const SizedBox(height: 12),
        if (job.isSafetyConfirmed)
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Güvenlik adımları onaylandı.', style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
      ],
    );
  }

  void _update(Map<String, bool> current, String key, bool value) {
    final next = Map<String, bool>.from(current);
    next[key] = value;
    ref.read(jobOperationsProvider.notifier).updateSafetyChecklist(job.id, next);
  }
}
