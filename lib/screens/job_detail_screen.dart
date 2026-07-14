import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../widgets/web_safe_image.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../theme/app_theme.dart';
import 'job_checklist_screen.dart';
import 'admin_dashboard.dart';
import 'audit_log_screen.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  Job get job => widget.job;

  Future<void> _confirmDelete() async {
    final l10n = ref.read(translationProvider.notifier);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('delete_job_title'), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text(l10n.translate('delete_job_confirm', {'title': job.title}), style: TextStyle(color: context.appExt.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('button_delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(jobOperationsProvider.notifier).deleteJob(job.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _launchMaps(String address) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showDescription2Dialog() async {
    final l10n = ref.read(translationProvider.notifier);
    final controller = TextEditingController(text: job.description2 ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('job_description2_title'), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 2,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: l10n.translate('job_description2_hint'),
            hintStyle: TextStyle(color: context.appExt.textTertiary),
            filled: true,
            fillColor: Theme.of(ctx).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF37474F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF37474F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1565C0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.translate('button_cancel'), style: TextStyle(color: context.appExt.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.translate('button_ok'), style: const TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      try {
        await ref.read(jobOperationsProvider.notifier).updateDescription2(job.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('job_description2_saved')), backgroundColor: const Color(0xFF4CAF50)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showFeeEditDialog() async {
    final l10n = ref.read(translationProvider.notifier);
    final controller = TextEditingController(text: job.fee?.toStringAsFixed(0) ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('job_fee_edit_title'), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: context.appExt.textTertiary),
            prefixIcon: const Padding(padding: EdgeInsets.only(left: 12, right: 4), child: Icon(Icons.attach_money, color: Color(0xFF4CAF50), size: 22)),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: Theme.of(ctx).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF37474F)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF37474F)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1565C0)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.translate('button_cancel'), style: TextStyle(color: context.appExt.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.translate('button_save'), style: const TextStyle(color: Color(0xFF4FC3F7))),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final newFee = double.tryParse(result);
      if (newFee != null) {
        try {
          await ref.read(jobOperationsProvider.notifier).updateFee(job.id, newFee);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('job_fee_updated')), backgroundColor: const Color(0xFF4CAF50)),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _showDurationEditDialog() async {
    final l10n = ref.read(translationProvider.notifier);
    final controller = TextEditingController(text: '${widget.job.durationHours}');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('duration_label'), style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 18),
          decoration: InputDecoration(
            hintText: l10n.translate('duration_hint'),
            hintStyle: TextStyle(color: context.appExt.textTertiary),
            suffixText: ' ${l10n.translate('log_hours')}',
            filled: true,
            fillColor: Theme.of(ctx).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('button_cancel'), style: TextStyle(color: context.appExt.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(l10n.translate('button_save'), style: const TextStyle(color: Color(0xFF4FC3F7)))),
        ],
      ),
    );
    if (result != null && mounted) {
      final hours = int.tryParse(result);
      if (hours != null && hours > 0) {
        try {
          await ref.read(jobOperationsProvider.notifier).updateDuration(widget.job.id, hours);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('job_duration_updated')), backgroundColor: const Color(0xFF4CAF50)),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  Future<void> _makeCall(String phone) async {
    // Sanitize: strip non-numeric and limit length to prevent injection
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) return;
    final url = Uri.parse('tel:$sanitized');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final isActuallyAdmin = authState is ApprovedAdmin;
    final viewAsWorker = ref.watch(viewAsWorkerProvider);
    final isAdmin = isActuallyAdmin && !viewAsWorker;
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);
    // Canlı job verisi — Firestore güncellenince anında yansır
    final job = ref.watch(jobByIdProvider(widget.job.id)).value ?? widget.job;

    return Scaffold(
      appBar: AppBar(
        title: Text('${job.missionNumber} - ${l10n.translate('job_details')}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : (isAdmin ? Theme.of(context).colorScheme.primary : const Color(0xFF0D47A1)),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.history_toggle_off),
              tooltip: l10n.translate('job_history_tooltip'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuditLogScreen(jobId: job.id))),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: l10n.translate('delete_job_tooltip'),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: Scrollbar(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge
            _InfoRow(label: l10n.translate('status_label'), value: l10n.translate('job_status_${job.status.name}'), icon: Icons.info_outline, color: _getStatusColor(job.status)),
            const SizedBox(height: 12),

            // 2. 👤 Müşteri Adı
            _DetailCard(
              title: l10n.translate('job_customer_name'),
              value: job.customerName ?? '-',
              icon: Icons.person_outline,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 3. 📞 Telefon
            _DetailCard(
              title: l10n.translate('job_customer_phone'),
              value: job.customerPhone ?? '-',
              icon: Icons.phone_outlined,
              onTap: job.customerPhone != null && job.customerPhone!.isNotEmpty ? () => _makeCall(job.customerPhone!) : null,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 4. 📍 Adres
            _DetailCard(
              title: l10n.translate('job_address'),
              value: job.address,
              icon: Icons.location_on_outlined,
              onTap: () => _launchMaps(job.address),
              isLink: true,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 5. 📅 Tarih & 6. 🕐 Saat
            _InfoRow(
              label: l10n.translate('job_date'),
              value: '${l10n.translate('date_format_short', {'day': '${job.scheduledDate.day}', 'month': '${job.scheduledDate.month}', 'year': '${job.scheduledDate.year}'})}  ${job.scheduledDate.hour.toString().padLeft(2, '0')}:${job.scheduledDate.minute.toString().padLeft(2, '0')}',
              icon: Icons.access_time,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 12),

            // 7. ⏱ Süre
            _DetailCard(
              title: l10n.translate('duration_label'),
              value: l10n.translate('template_desc_duration_hours', {'hours': '${job.durationHours}'}),
              icon: Icons.timelapse,
              onTap: !isAdmin ? _showDurationEditDialog : null,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 8. 📝 İş Başlığı
            _DetailCard(
              title: l10n.translate('job_title'),
              value: job.title,
              icon: Icons.work_outline,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 9. 📄 Açıklama
            _DetailCard(
              title: l10n.translate('job_description'),
              value: job.description,
              icon: Icons.description_outlined,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),
            // Worker ek açıklaması — her zaman görünür, boşsa ekleme butonu
            if (!isAdmin)
              _DetailCard(
                title: l10n.translate('job_description2_label'),
                value: (job.description2 != null && job.description2!.isNotEmpty) ? job.description2! : l10n.translate('job_description2_add'),
                icon: (job.description2 != null && job.description2!.isNotEmpty) ? Icons.edit_note : Icons.add_comment_outlined,
                onTap: _showDescription2Dialog,
              ),

            // 10. 👷 Personel
            _DetailCard(
              title: l10n.translate('job_assignee'),
              value: job.assignedWorkerName,
              icon: Icons.person,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // 11. 🗺 Mesafe / 💰 Ücret
            if (job.estimatedTravelTime != null)
              _DetailCard(
                title: l10n.translate('log_travel_estimate'),
                value: '${job.estimatedTravelTime!.inMinutes} ${l10n.translate('log_minutes')}',
                icon: Icons.map,
              ),
            _DetailCard(
              title: l10n.translate('job_fee_label'),
              value: job.fee != null 
                ? '${job.fee!.toStringAsFixed(0)} €${isAdmin && job.feeEnteredBy == 1 ? '  👷' : ''}' 
                : (!isAdmin ? l10n.translate('job_fee_add') : '-'),
              icon: job.fee != null ? Icons.euro : (!isAdmin ? Icons.add_circle_outline : Icons.euro),
              onTap: !isAdmin ? _showFeeEditDialog : null,
              onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null,
            ),

            // Checklist Notes (worker notes between photos)
            if (job.checklistNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l10n.translate('job_checklist_notes_title'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              ...job.checklistNotes.map((note) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF37474F)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes, color: context.appExt.textSecondary, size: 16),
                    const SizedBox(width: 10),
                    Expanded(child: Text(note, style: TextStyle(color: context.appExt.textSecondary, fontSize: 13))),
                  ],
                ),
              )),
            ],

            // Description Blocks
            if (job.descriptionBlocks.isNotEmpty) ...[
              ...job.descriptionBlocks.map((block) {
                if (block.startsWith('[RESIM]')) {
                  final imageUrl = block.substring(7);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DescriptionImagePreview(imageUrl: imageUrl),
                  );
                }
                return _DetailCard(title: l10n.translate('info_label'), value: block, icon: Icons.info_outline);
              }),
            ],

            // Attached Images (admin tarafından eklenen resimler)
            if (job.attachedImages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l10n.translate('attached_images'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              ...job.attachedImages.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DescriptionImagePreview(imageUrl: url),
              )),
            ],

            // Before/After Photos (çalışan checklist fotoğrafları)
            if (job.beforePhotoUrls.isNotEmpty || job.afterPhotoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(l10n.translate('photos_label'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              if (job.beforePhotoUrls.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Text(l10n.translate('before_photo_label'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: job.beforePhotoUrls.map((url) => _PhotoThumb(url: url)).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (job.afterPhotoUrls.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Text(l10n.translate('after_photo_label'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: job.afterPhotoUrls.map((url) => _PhotoThumb(url: url)).toList(),
                ),
              ],
            ],

            const SizedBox(height: 32),

            // Action Button
            if (!isAdmin && job.status != JobStatus.closed && job.status != JobStatus.workCompleted)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobChecklistScreen(job: job))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  job.status == JobStatus.notStarted 
                    ? l10n.translate('job_start_checklist') 
                    : l10n.translate('job_continue_checklist'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            // Completed/Closed jobs: allow reopen or edit
            if (!isAdmin && (job.status == JobStatus.closed || job.status == JobStatus.workCompleted))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobChecklistScreen(job: job))),
                        icon: const Icon(Icons.replay, size: 18),
                        label: Text(l10n.translate('job_edit_reopen')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (isAdmin && job.status == JobStatus.closed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('✅ ${l10n.translate('job_status_${job.status.name}')}', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.appExt.statusClosed, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Color _getStatusColor(JobStatus status) {
    return context.appExt.statusColor(status);
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool isLink;

  const _DetailCard({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
    this.onEdit,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: context.appExt.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: isLink ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: isLink ? TextDecoration.underline : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit, color: context.appExt.textSecondary, size: 20),
                  onPressed: onEdit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PhotoPreview extends ConsumerWidget {
  final String url;
  final String label;
  const _PhotoPreview({required this.url, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      children: [
        InkWell(
          onTap: () => FullScreenImageViewer.show(context, url),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                WebSafeImage(
                  url: url,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    height: 120,
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.red, size: 32),
                          const SizedBox(height: 4),
                          Text(l10n.translate('image_load_error'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: context.appExt.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _DescriptionImagePreview extends ConsumerWidget {
  final String imageUrl;
  const _DescriptionImagePreview({required this.imageUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return InkWell(
      onTap: () => FullScreenImageViewer.show(context, imageUrl),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            WebSafeImage(
              url: imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                height: 120,
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, color: Colors.red, size: 32),
                      const SizedBox(height: 4),
                      Text(l10n.translate('image_load_error'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String url;
  const _PhotoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FullScreenImageViewer.show(context, url),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.4), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebSafeImage(
                url: url,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (context, error, stack) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.red, size: 24)),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
