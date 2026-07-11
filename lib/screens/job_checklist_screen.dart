import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';

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
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _nextStep() async {
    final l10n = ref.read(translationProvider.notifier);
    
    if (_currentStep == 0) {
      // Start -> In Progress
      await ref.read(jobOperationsProvider.notifier).updateJobStatus(widget.job.id, JobStatus.inProgress);
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Before Photo Step
      if (_beforePhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen iş öncesi fotoğrafını yükleyin.')),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Materials Step (Allowing skip if none used, but usually some are)
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // After Photo Step
      if (_afterPhotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen iş sonrası fotoğrafını yükleyin.')),
        );
        return;
      }
      setState(() => _currentStep = 4);
    } else if (_currentStep == 4) {
      // Payment Step
      if (!widget.job.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce ödemeyi kaydedin.')),
        );
        return;
      }
      setState(() => _currentStep = 5);
    } else if (_currentStep == 5) {
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
        onStepContinue: _isUploading ? null : _nextStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 5 ? Colors.green : const Color(0xFF1565C0),
                minimumSize: const Size(120, 45),
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep == 5 ? l10n.translate('job_checklist_finish') : l10n.translate('job_checklist_start'),
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
          Step(
            title: Text(l10n.translate('job_payment_title'), style: const TextStyle(color: Colors.white)),
            content: _PaymentContent(job: widget.job, l10n: l10n, ref: ref),
            isActive: _currentStep >= 4,
            state: _currentStep > 4 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: Text(l10n.translate('job_checklist_finish'), style: const TextStyle(color: Colors.white)),
            content: Text('Tüm adımlar ve ödeme tamamlandı. İşi kapatabilirsiniz.', style: const TextStyle(color: Color(0xFF90A4AE))),
            isActive: _currentStep >= 5,
            state: _currentStep == 5 ? StepState.complete : StepState.indexed,
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
  final TranslationNotifier l10n;
  final WidgetRef ref;

  const _PaymentContent({required this.job, required this.l10n, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (job.isPaid) {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(l10n.translate('job_payment_received') + ' (${job.paymentMethod?.toUpperCase()})',
               style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Row(
      children: [
        ElevatedButton(
          onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'qr'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7)),
          child: Text(l10n.translate('job_payment_qr'), style: const TextStyle(color: Color(0xFF0D1B2A))),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => ref.read(jobOperationsProvider.notifier).recordPayment(job.id, 'cash'),
          child: Text(l10n.translate('job_payment_cash')),
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
