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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Şablonları'),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1565C0),
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: templatesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.cs.secondary)),
        error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: Colors.red))),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: Color(0xFF546E7A)),
                  SizedBox(height: 16),
                  Text('Henüz şablon yok.\n+ butonu ile yeni şablon oluşturun.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
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
          );
        },
      ),
    );
  }

  String _describeTemplate(JobTemplate t) {
    final parts = <String>[];
    if (t.includeTitle) parts.add('Başlık${t.defaultTitle.isNotEmpty ? " (${t.defaultTitle})" : ""}');
    if (t.includeDescription) parts.add('Açıklama');
    if (t.includeDescriptionBlocks) parts.add('Ek Açıklama Blokları');
    if (t.includeCustomerName) parts.add('Müşteri${t.defaultCustomerName.isNotEmpty ? " (${t.defaultCustomerName})" : ""}');
    if (t.includeCustomerPhone) parts.add('Telefon');
    if (t.includeAddress) parts.add('Adres');
    if (t.includeFee) parts.add(t.defaultFee != null ? 'Ücret (${t.defaultFee!.toStringAsFixed(0)}₺)' : 'Ücret');
    if (t.includeDistance) parts.add(t.defaultDistance != null ? 'Mesafe (${t.defaultDistance!.toStringAsFixed(1)} km)' : 'Mesafe');
    if (t.includeDuration) parts.add('${t.defaultDurationHours} saat');
    return parts.join(' • ');
  }

  void _confirmDelete(JobTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Şablonu Sil', style: TextStyle(color: Colors.white)),
        content: Text('"${template.name}" şablonunu silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(templateOperationsProvider.notifier).deleteTemplate(template.id);
    }
  }

  void _showCreateDialog(BuildContext context) {
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
          title: const Text('Yeni Şablon', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDarkField('Şablon Adı *', nameCtrl),
                const SizedBox(height: 16),
                const Text('Dahil Edilecek Alanlar:', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                const SizedBox(height: 8),
                _toggle('İş Başlığı', inclTitle, (v) => setDialogState(() => inclTitle = v)),
                if (inclTitle) _buildDarkField('Varsayılan Başlık', titleCtrl),
                _toggle('Açıklama', inclDesc, (v) => setDialogState(() => inclDesc = v)),
                if (inclDesc) _buildDarkField('Varsayılan Açıklama', descCtrl),
                _toggle('Ek Açıklama Blokları', inclDescBlocks, (v) => setDialogState(() => inclDescBlocks = v)),
                if (inclDescBlocks) _buildDarkField('Varsayılan Ek Açıklama', descBlockCtrl),
                _toggle('Müşteri Adı', inclCustName, (v) => setDialogState(() => inclCustName = v)),
                if (inclCustName) _buildDarkField('Varsayılan Müşteri', custNameCtrl),
                _toggle('Telefon', inclCustPhone, (v) => setDialogState(() => inclCustPhone = v)),
                if (inclCustPhone) _buildDarkField('Varsayılan Telefon', custPhoneCtrl),
                _toggle('Adres', inclAddr, (v) => setDialogState(() => inclAddr = v)),
                if (inclAddr) _buildDarkField('Varsayılan Adres', addrCtrl),
                _toggle('Ücret', inclFee, (v) => setDialogState(() => inclFee = v)),
                if (inclFee) _buildDarkField('Varsayılan Ücret', feeCtrl, keyboardType: TextInputType.number),
                _toggle('Mesafe', inclDist, (v) => setDialogState(() => inclDist = v)),
                if (inclDist) _buildDarkField('Varsayılan Mesafe (km)', distCtrl, keyboardType: TextInputType.number),
                _toggle('Süre', inclDuration, (v) => setDialogState(() => inclDuration = v)),
                if (inclDuration)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Text('Varsayılan Süre:', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: defaultDur,
                          dropdownColor: const Color(0xFF0D1B2A),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          underline: const SizedBox(),
                          items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(
                            value: h,
                            child: Text('$h saat', style: const TextStyle(color: Colors.white)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
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
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
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
          fillColor: const Color(0xFF0D1B2A),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
