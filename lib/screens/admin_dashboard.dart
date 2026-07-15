import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../models/app_user.dart';
import 'module_settings_screen.dart';
import 'job_template_screen.dart';
import '../widgets/calendar/join_code_card.dart';
import '../widgets/web_safe_image.dart';
import '../theme/app_theme.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  final AppUser adminUser;

  const AdminDashboard({super.key, required this.adminUser});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String? _processingUserId;

  @override
  Widget build(BuildContext context) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final orgAsync = ref.watch(currentOrganizationProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);
    final currentLang = ref.watch(translationProvider).value ?? 'tr';

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.translate('admin_panel_title')} — ${widget.adminUser.name}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.translate('module_settings_tooltip'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: l10n.translate('template_tooltip'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobTemplateScreen())),
          ),
          // ADM-02: Language toggle (Calendar ile aynı yapı)
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: l10n.translate('language_tooltip'),
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Theme.of(ctx).colorScheme.surface,
                    title: Text(l10n.translate('logout'), style: const TextStyle(color: Colors.white)),
                    content: Text(l10n.translate('logout_confirm'), style: TextStyle(color: context.appExt.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('logout'), style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).signOut();
                }
              } else {
                ref.read(translationProvider.notifier).setLanguage(value);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'tr',
                child: Row(children: [
                  Text(l10n.translate('lang_turkish'), style: TextStyle(fontWeight: currentLang == 'tr' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'tr') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(children: [
                  Text(l10n.translate('lang_english'), style: TextStyle(fontWeight: currentLang == 'en' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'en') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
              PopupMenuItem(
                value: 'nl',
                child: Row(children: [
                  Text(l10n.translate('lang_dutch'), style: TextStyle(fontWeight: currentLang == 'nl' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'nl') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text(l10n.translate('logout'))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organizasyon Bilgi Kartı
          orgAsync.when(
            data: (org) => org == null ? const SizedBox() : Column(children: [
              JoinCodeCard(org: org, showCode: true),
              // QR Kod Yükleme
              _PaymentQrSection(orgId: org.id, currentQrUrl: org.paymentQrUrl),
            ]),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              l10n.translate('admin_pending_users'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: pendingUsersAsync.when(
              data: (users) => users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            l10n.translate('admin_no_pending'),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    )
                  : RepaintBoundary(
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          color: Theme.of(context).colorScheme.surface,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(user.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                            subtitle: Text(user.email, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _processingUserId != null ? null : () async {
                                    setState(() => _processingUserId = user.id);
                                    try {
                                      await ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.rejected);
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('worker_rejected')), backgroundColor: Colors.orange, duration: const Duration(seconds: 2)));
                                    } catch (_) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('generic_error', {'error': 'Failed'})), backgroundColor: Colors.red));
                                    } finally {
                                      if (mounted) setState(() => _processingUserId = null);
                                    }
                                  },
                                  child: _processingUserId == user.id
                                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.secondary))
                                      : Text(l10n.translate('admin_reject'), style: const TextStyle(color: Colors.redAccent)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _processingUserId != null ? null : () async {
                                    setState(() => _processingUserId = user.id);
                                    try {
                                      await ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.approved);
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('worker_approved')), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
                                    } catch (_) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('generic_error', {'error': 'Failed'})), backgroundColor: Colors.red));
                                    } finally {
                                      if (mounted) setState(() => _processingUserId = null);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: _processingUserId == user.id
                                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text(l10n.translate('admin_approve')),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)),
              error: (err, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$err'}), style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PaymentQrSection extends ConsumerStatefulWidget {
  final String orgId;
  final String? currentQrUrl;
  const _PaymentQrSection({required this.orgId, this.currentQrUrl});

  @override
  ConsumerState<_PaymentQrSection> createState() => _PaymentQrSectionState();
}

class _PaymentQrSectionState extends ConsumerState<_PaymentQrSection> {
  bool _isUploading = false;

  Future<void> _uploadQr() async {
    final l10n = ref.read(translationProvider.notifier);
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadPaymentQr(widget.orgId);
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('qr_uploaded_short')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.currentQrUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: WebSafeImage(url: widget.currentQrUrl!, fit: BoxFit.contain),
                    )
                  : Icon(Icons.qr_code, color: context.appExt.textTertiary, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.translate('payment_qr_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translate(widget.currentQrUrl != null ? 'qr_loaded' : 'qr_not_loaded'),
                    style: TextStyle(color: widget.currentQrUrl != null ? Colors.green : context.appExt.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _isUploading
                ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary, strokeWidth: 2))
                : IconButton(
                    icon: Icon(widget.currentQrUrl != null ? Icons.refresh : Icons.upload, color: const Color(0xFF4FC3F7)),
                    onPressed: _uploadQr,
                    tooltip: l10n.translate('qr_code_add_tooltip'),
                  ),
          ],
        ),
      ),
    );
  }
}
