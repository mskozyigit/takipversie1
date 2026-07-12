import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../models/job_template.dart';
import '../theme/app_theme.dart';

class JobTemplateScreen extends ConsumerStatefulWidget {
  const JobTemplateScreen({super.key});

  @override
  ConsumerState<JobTemplateScreen> createState() => _JobTemplateScreenState();
}

class _JobTemplateScreenState extends ConsumerState<JobTemplateScreen> {
  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(jobTemplatesProvider);
    final branding = ref.watch(brandingProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('template_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: templatesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red))),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 64, color: Color(0xFF546E7A)),
                  const SizedBox(height: 16),
                  Text(l10n.translate('template_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return RepaintBoundary(
            child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (_, i) {
              final t = templates[i];
              return Card(
                color: Theme.of(context).colorScheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _describeTemplate(t),
                    style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(t),
                  ),
                ),
              );
            },
          ),
          );
        },
      ),
    );
  }

  String _describeTemplate(JobTemplate t) {
    final l10n = ref.read(translationProvider.notifier);
    final parts = <String>[];
    if (t.includeTitle) parts.add('${l10n.translate('template_desc_title')}${t.defaultTitle.isNotEmpty ? " (${t.defaultTitle})" : ""}');
    if (t.includeDescription) parts.add(l10n.translate('template_desc_description'));
    if (t.includeDescriptionBlocks) parts.add(l10n.translate('template_desc_extra_blocks'));
    if (t.includeCustomerName) parts.add('${l10n.translate('template_desc_customer')}${t.defaultCustomerName.isNotEmpty ? " (${t.defaultCustomerName})" : ""}');
    if (t.includeCustomerPhone) parts.add(l10n.translate('template_desc_phone'));
    if (t.includeAddress) parts.add(l10n.translate('template_desc_address'));
    if (t.includeFee) parts.add(t.defaultFee != null ? '${l10n.translate('template_desc_fee')} (${t.defaultFee!.toStringAsFixed(0)}₺)' : l10n.translate('template_desc_fee'));
    if (t.includeDistance) parts.add(t.defaultDistance != null ? '${l10n.translate('template_desc_distance')} (${t.defaultDistance!.toStringAsFixed(1)} km)' : l10n.translate('template_desc_distance'));
    if (t.includeDuration) parts.add(l10n.translate('template_desc_duration_hours', {'hours': '${t.defaultDurationHours}'}));
    return parts.join(' • ');
  }

  void _confirmDelete(JobTemplate template) async {
    final l10n = ref.read(translationProvider.notifier);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('template_delete_title'), style: const TextStyle(color: Colors.white)),
        content: Text(l10n.translate('template_delete_confirm', {'name': template.name}),
          style: const TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('button_delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(templateOperationsProvider.notifier).deleteTemplate(template.id);
    }
  }

  void _showCreateDialog(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    final nameCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final descBlockCtrl = TextEditingController();
    final custNameCtrl = TextEditingController();
    final custPhoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final distCtrl = TextEditingController();

    bool inclTitle = true;
    bool inclDesc = true;
    bool inclDescBlocks = false;
    bool inclCustName = false;
    bool inclCustPhone = false;
    bool inclAddr = false;
    bool inclFee = false;
    bool inclDist = false;
    bool inclDuration = false;
    int defaultDur = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          title: Text(l10n.translate('template_create_title'), style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDarkField(l10n.translate('template_name_required'), nameCtrl),
                const SizedBox(height: 16),
                Text(l10n.translate('template_fields_to_include'), style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                const SizedBox(height: 8),
                _toggle(l10n.translate('template_field_title'), inclTitle, (v) => setDialogState(() => inclTitle = v)),
                if (inclTitle) _buildDarkField(l10n.translate('template_default_title'), titleCtrl),
                _toggle(l10n.translate('template_field_description'), inclDesc, (v) => setDialogState(() => inclDesc = v)),
                if (inclDesc) _buildDarkField(l10n.translate('template_default_description'), descCtrl),
                _toggle(l10n.translate('template_field_extra_blocks'), inclDescBlocks, (v) => setDialogState(() => inclDescBlocks = v)),
                if (inclDescBlocks) _buildDarkField(l10n.translate('template_default_extra'), descBlockCtrl),
                _toggle(l10n.translate('template_field_customer_name'), inclCustName, (v) => setDialogState(() => inclCustName = v)),
                if (inclCustName) _buildDarkField(l10n.translate('template_default_customer'), custNameCtrl),
                _toggle(l10n.translate('template_field_phone'), inclCustPhone, (v) => setDialogState(() => inclCustPhone = v)),
                if (inclCustPhone) _buildDarkField(l10n.translate('template_default_phone'), custPhoneCtrl),
                _toggle(l10n.translate('template_field_address'), inclAddr, (v) => setDialogState(() => inclAddr = v)),
                if (inclAddr) _buildDarkField(l10n.translate('template_default_address'), addrCtrl),
                _toggle(l10n.translate('template_field_fee'), inclFee, (v) => setDialogState(() => inclFee = v)),
                if (inclFee) _buildDarkField(l10n.translate('template_default_fee'), feeCtrl, keyboardType: TextInputType.number),
                _toggle(l10n.translate('template_field_distance'), inclDist, (v) => setDialogState(() => inclDist = v)),
                if (inclDist) _buildDarkField(l10n.translate('template_default_distance'), distCtrl, keyboardType: TextInputType.number),
                _toggle(l10n.translate('template_field_duration'), inclDuration, (v) => setDialogState(() => inclDuration = v)),
                if (inclDuration)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(l10n.translate('template_default_duration'), style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: defaultDur,
                          dropdownColor: const Color(0xFF0D1B2A),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          underline: const SizedBox(),
                          items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(l10n.translate('template_desc_duration_hours', {'hours': '$h'}), style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (v) => setDialogState(() => defaultDur = v ?? 2),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('button_cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(templateOperationsProvider.notifier).createTemplate(
                  name: nameCtrl.text.trim(),
                  includeTitle: inclTitle,
                  includeDescription: inclDesc,
                  includeDescriptionBlocks: inclDescBlocks,
                  includeCustomerName: inclCustName,
                  includeCustomerPhone: inclCustPhone,
                  includeAddress: inclAddr,
                  includeFee: inclFee,
                  includeDistance: inclDist,
                  includeDuration: inclDuration,
                  defaultTitle: titleCtrl.text.trim(),
                  defaultDescription: descCtrl.text.trim(),
                  defaultDescriptionBlocks: descBlockCtrl.text.trim().isNotEmpty ? [descBlockCtrl.text.trim()] : [],
                  defaultCustomerName: custNameCtrl.text.trim(),
                  defaultCustomerPhone: custPhoneCtrl.text.trim(),
                  defaultAddress: addrCtrl.text.trim(),
                  defaultFee: double.tryParse(feeCtrl.text),
                  defaultDistance: double.tryParse(distCtrl.text),
                  defaultDurationHours: defaultDur,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              child: Text(l10n.translate('button_create')),
            ),
          ],
        ),
      ),
    );
    // Controllers are disposed automatically when dialog closes
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      onChanged: onChanged,
      dense: true,
      activeColor: const Color(0xFF4FC3F7),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDarkField(String label, TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
