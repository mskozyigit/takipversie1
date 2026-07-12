import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: const Text('Görevi Sil', style: TextStyle(color: Colors.white)),
        content: Text('"${job.title}" görevini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.', style: const TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(jobOperationsProvider.notifier).deleteJob(job.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _launchMaps(String address) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _makeCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).value;
    final isAdmin = authState is ApprovedAdmin;
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${job.missionNumber} - ${l10n.translate('job_details')}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : (isAdmin ? const Color(0xFF1565C0) : const Color(0xFF0D47A1)),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.history_toggle_off),
              tooltip: 'İş Geçmişi',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuditLogScreen(jobId: job.id))),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Görevi Sil',
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Badge
            _InfoRow(label: 'Durum', value: l10n.translate('job_status_${job.status.name}'), icon: Icons.info_outline, color: _getStatusColor(job.status)),
            const SizedBox(height: 12),

            // Date & Time
            _InfoRow(
              label: l10n.translate('job_date'),
              value: '${job.scheduledDate.day}/${job.scheduledDate.month}/${job.scheduledDate.year}  ${job.scheduledDate.hour.toString().padLeft(2, '0')}:${job.scheduledDate.minute.toString().padLeft(2, '0')}',
              icon: Icons.access_time,
              color: const Color(0xFF4FC3F7),
            ),
            const SizedBox(height: 12),

            // Worker: Customer info on top
            if (!isAdmin) ...[
              _DetailCard(title: l10n.translate('job_customer_name'), value: job.customerName ?? '-', icon: Icons.person_outline),
              _DetailCard(title: l10n.translate('job_customer_phone'), value: job.customerPhone ?? '-', icon: Icons.phone_outlined, onTap: job.customerPhone != null ? () => _makeCall(job.customerPhone!) : null),
              _DetailCard(title: l10n.translate('job_address'), value: job.address, icon: Icons.location_on_outlined, onTap: () => _launchMaps(job.address), isLink: true),
              const SizedBox(height: 8),
            ],

            // Job Title & Description
            _DetailCard(title: l10n.translate('job_title'), value: job.title, icon: Icons.work_outline, onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null),
            _DetailCard(title: l10n.translate('job_description'), value: job.description, icon: Icons.description_outlined, onEdit: isAdmin ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job))) : null),

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
                return _DetailCard(title: 'Bilgi', value: block, icon: Icons.info_outline);
              }),
            ],

            // Photos (if any)
            if (job.beforePhotoUrl != null || job.afterPhotoUrl != null) ...[
              const SizedBox(height: 8),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Fotoğraflar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              const SizedBox(height: 8),
              Row(children: [
                if (job.beforePhotoUrl != null) Expanded(child: _PhotoPreview(url: job.beforePhotoUrl!, label: 'Öncesi')),
                if (job.beforePhotoUrl != null && job.afterPhotoUrl != null) const SizedBox(width: 12),
                if (job.afterPhotoUrl != null) Expanded(child: _PhotoPreview(url: job.afterPhotoUrl!, label: 'Sonrası')),
              ]),
            ],

            // Admin: Customer info below
            if (isAdmin) ...[
              const SizedBox(height: 8),
              _DetailCard(title: l10n.translate('job_customer_name'), value: job.customerName ?? '-', icon: Icons.person_outline, onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job)))),
              _DetailCard(title: l10n.translate('job_customer_phone'), value: job.customerPhone ?? '-', icon: Icons.phone_outlined, onTap: job.customerPhone != null ? () => _makeCall(job.customerPhone!) : null, onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job)))),
              _DetailCard(title: l10n.translate('job_address'), value: job.address, icon: Icons.location_on_outlined, onTap: () => _launchMaps(job.address), isLink: true, onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobEditScreen(job: job)))),
            ],

            const SizedBox(height: 32),

            // Action Button
            if (!isAdmin && job.status != JobStatus.closed && job.status != JobStatus.workCompleted)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobChecklistScreen(job: job))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  job.status == JobStatus.notStarted 
                    ? l10n.translate('job_start_checklist') 
                    : l10n.translate('job_continue_checklist'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                        label: const Text('İşi Düzenle / Yeniden Aç'),
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
                  style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.notStarted: return Colors.grey;
      case JobStatus.inProgress: return Colors.blue;
      case JobStatus.workCompleted: return Colors.green;
      case JobStatus.closed: return Colors.deepPurple;
    }
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
      color: const Color(0xFF1A2A3A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF4FC3F7), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: isLink ? const Color(0xFF4FC3F7) : Colors.white,
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
                  icon: const Icon(Icons.edit, color: Color(0xFF90A4AE), size: 20),
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

class _PhotoPreview extends StatelessWidget {
  final String url;
  final String label;
  const _PhotoPreview({required this.url, required this.label});

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
                  },
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text('Fotoğraf yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE))),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white, size: 28),
                    tooltip: 'İndir',
                    onPressed: () => launchUrl(Uri.parse(url)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => _showFullScreen(context),
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  url,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: const Color(0xFF1A2A3A),
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    height: 120,
                    color: const Color(0xFF1A2A3A),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.red, size: 32),
                          SizedBox(height: 4),
                          Text('Yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
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
        Text(label, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
      ],
    );
  }
}

class _DescriptionImagePreview extends StatelessWidget {
  final String imageUrl;
  const _DescriptionImagePreview({required this.imageUrl});

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)));
                  },
                  errorBuilder: (ctx, err, stack) => const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text('Fotoğraf yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE))),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white, size: 28),
                    tooltip: 'İndir',
                    onPressed: () => launchUrl(Uri.parse(imageUrl)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showFullScreen(context),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 120,
                  color: const Color(0xFF1A2A3A),
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                height: 120,
                color: const Color(0xFF1A2A3A),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.red, size: 32),
                      SizedBox(height: 4),
                      Text('Yüklenemedi', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
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
