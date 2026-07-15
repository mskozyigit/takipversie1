import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/web_safe_image.dart';

/// Admin screen to upload per-amount QR payment codes (150€, 200€, 250€, 300€).
class QrManagementScreen extends ConsumerStatefulWidget {
  const QrManagementScreen({super.key});

  @override
  ConsumerState<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends ConsumerState<QrManagementScreen> {
  static const _amounts = [150.0, 200.0, 250.0, 300.0];
  final Map<String, bool> _uploading = {};

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(currentOrganizationProvider).value;
    final branding = ref.watch(brandingProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text(l10n.translate('qr_management_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.translate('qr_management_desc'),
            style: TextStyle(color: context.appExt.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ..._amounts.map((amount) {
            final key = amount.toStringAsFixed(0);
            final currentUrl = org?.qrPaymentUrls[key];
            final isUploading = _uploading[key] == true;

            return Card(
              color: const Color(0xFF1A2A3A),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$key €',
                          style: const TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (currentUrl != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: l10n.translate('qr_remove'),
                            onPressed: isUploading ? null : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A2A3A),
                                  title: Text(l10n.translate('qr_remove'), style: const TextStyle(color: Colors.white)),
                                  content: Text(l10n.translate('qr_remove_confirm', {'amount': key}), style: const TextStyle(color: Color(0xFF90A4AE))),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('button_delete'), style: const TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true && org != null) {
                                final urls = Map<String, String>.from(org.qrPaymentUrls);
                                urls.remove(key);
                                await FirebaseFirestore.instance
                                    .collection('organizations')
                                    .doc(org.id)
                                    .update({'qrPaymentUrls': urls});
                                // Refresh org data
                                ref.invalidate(currentOrganizationProvider);
                                if (mounted) setState(() {});
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isUploading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                        ),
                      )
                    else if (currentUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: WebSafeImage(
                          url: currentUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          showLoading: true,
                        ),
                      )
                    else
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF37474F)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code, size: 32, color: Color(0xFF546E7A)),
                              SizedBox(height: 4),
                              Text(l10n.translate('qr_not_uploaded'), style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isUploading ? null : () => _uploadQr(amount, key),
                        icon: Icon(currentUrl != null ? Icons.swap_horiz : Icons.upload, size: 18),
                        label: Text(currentUrl != null ? l10n.translate('qr_replace') : l10n.translate('qr_upload')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4FC3F7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF4FC3F7)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _uploadQr(double amount, String key) async {
    final org = ref.read(currentOrganizationProvider).value;
    if (org == null) return;

    setState(() => _uploading[key] = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadOrgQrByAmount(
        orgId: org.id,
        amount: amount,
      );
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('qr_uploaded', {'amount': key})), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
        setState(() {}); // Refresh to show new image
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('qr_upload_error', {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading[key] = null);
    }
  }
}
