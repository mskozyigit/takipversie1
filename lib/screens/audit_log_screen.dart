import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AuditLogScreen extends ConsumerWidget {
  final String jobId;
  const AuditLogScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogsAsync = ref.watch(auditLogProvider(jobId));
    final branding = ref.watch(brandingProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('audit_log_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      body: SafeArea(
        child: auditLogsAsync.when(
        data: (logs) => logs.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_toggle_off, size: 48, color: context.appExt.textTertiary),
                    const SizedBox(height: 12),
                    Text(l10n.translate('audit_log_empty'), style: TextStyle(color: context.appExt.textSecondary)),
                  ],
                ),
              )
            : RepaintBoundary(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, i) {
                  final log = logs[i];
                  return Card(
                    color: Theme.of(context).colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(log.actorName, style: const TextStyle(color: Color(0xFF4FC3F7), fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(
                              '${log.timestamp.day}/${log.timestamp.month} ${log.timestamp.hour}:${log.timestamp.minute}',
                              style: TextStyle(color: context.appExt.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(log.actionType, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        if (log.metadata != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            log.metadata.toString(),
                            style: TextStyle(color: context.appExt.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                    ),
                  );
                },
              ),
            ),
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red))),
      ),
      ),
    );
  }
}
