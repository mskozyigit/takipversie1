import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../models/app_user.dart';
import '../models/job.dart';
import '../providers/job_provider.dart';
import 'module_settings_screen.dart';
import 'job_template_screen.dart';
import '../widgets/calendar/join_code_card.dart';
import '../widgets/web_safe_image.dart';

class AdminDashboard extends ConsumerWidget {
  final AppUser adminUser;

  const AdminDashboard({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);
    final currentLang = ref.watch(translationProvider).value ?? 'tr';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${l10n.translate('admin_panel_title')} — ${adminUser.name}'),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
        actions: [
          // ADM-02: Language toggle
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: 'Dil / Language / Taal',
            onSelected: (lang) => ref.read(translationProvider.notifier).setLanguage(lang),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'tr',
                child: Row(children: [
                  Text('🇹🇷  Türkçe', style: TextStyle(fontWeight: currentLang == 'tr' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'tr') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
              PopupMenuItem(
                value: 'en',
                child: Row(children: [
                  Text('🇬🇧  English', style: TextStyle(fontWeight: currentLang == 'en' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'en') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
              PopupMenuItem(
                value: 'nl',
                child: Row(children: [
                  Text('🇳🇱  Nederlands', style: TextStyle(fontWeight: currentLang == 'nl' ? FontWeight.bold : FontWeight.normal)),
                  if (currentLang == 'nl') const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check, size: 16, color: Colors.green)),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            tooltip: 'Modül Ayarları',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModuleSettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Görev Şablonları',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobTemplateScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
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
            error: (_, __) => const SizedBox(),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              l10n.translate('admin_pending_users'),
              style: const TextStyle(
                color: Colors.white,
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
                      child: Text(
                        l10n.translate('admin_no_pending'),
                        style: const TextStyle(color: Color(0xFF90A4AE)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          color: const Color(0xFF1A2A3A),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            title: Text(user.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(user.email, style: const TextStyle(color: Color(0xFF90A4AE))),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.rejected),
                                  child: Text(l10n.translate('admin_reject'), style: const TextStyle(color: Colors.redAccent)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => ref.read(authProvider.notifier).updateUserStatus(user.id, ApprovalStatus.approved),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: Text(l10n.translate('admin_approve')),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Hata: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}

class JobEditScreen extends ConsumerStatefulWidget {
  final Job job;
  const JobEditScreen({super.key, required this.job});

  @override
  ConsumerState<JobEditScreen> createState() => _JobEditScreenState();
}

class _JobEditScreenState extends ConsumerState<JobEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _missionNumberController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  AppUser? _selectedWorker;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _descController = TextEditingController(text: widget.job.description);
    _addressController = TextEditingController(text: widget.job.address);
    _customerNameController = TextEditingController(text: widget.job.customerName);
    _customerPhoneController = TextEditingController(text: widget.job.customerPhone);
    _missionNumberController = TextEditingController(text: widget.job.missionNumber);
    _selectedDate = widget.job.scheduledDate;
    _selectedTime = TimeOfDay.fromDateTime(widget.job.scheduledDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _missionNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedWorker == null) {
      if (_selectedWorker == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir personel seçin')));
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(jobOperationsProvider.notifier).updateJob(
        jobId: widget.job.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        assignedWorkerId: _selectedWorker!.id,
        assignedWorkerName: _selectedWorker!.name,
        address: _addressController.text.trim(),
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        scheduledDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute),
        missionNumber: _missionNumberController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(organizationWorkersProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    // Initial worker selection fix
    workersAsync.whenData((workers) {
      if (_selectedWorker == null) {
        _selectedWorker = workers.cast<AppUser?>().firstWhere((w) => w?.id == widget.job.assignedWorkerId, orElse: () => null);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(title: Text(l10n.translate('job_title') + ' Düzenle'), backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField('Görev No', _missionNumberController, Icons.tag),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_title'), _titleController, Icons.title),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_description'), _descController, Icons.description, maxLines: 3),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_customer_name'), _customerNameController, Icons.person),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_customer_phone'), _customerPhoneController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_address'), _addressController, Icons.location_on, maxLines: 2),
              const SizedBox(height: 24),
              Text(l10n.translate('job_assignee'), style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
              const SizedBox(height: 8),
              workersAsync.when(
                data: (workers) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFF1A2A3A), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppUser>(
                      value: _selectedWorker,
                      dropdownColor: const Color(0xFF1A2A3A),
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name))).toList(),
                      onChanged: (val) => setState(() => _selectedWorker = val),
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Hata: $e'),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1A2A3A), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('job_date')}: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(color: Colors.white))]),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark(useMaterial3: true).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF4FC3F7),
                            onPrimary: Color(0xFF0D1B2A),
                            surface: Color(0xFF1A2A3A),
                            onSurface: Colors.white,
                          ),
                          timePickerTheme: const TimePickerThemeData(
                            backgroundColor: Color(0xFF1A2A3A),
                            hourMinuteTextColor: Colors.white,
                            hourMinuteColor: Color(0xFF0D1B2A),
                            dialHandColor: Color(0xFF4FC3F7),
                            dialBackgroundColor: Color(0xFF0D1B2A),
                            dialTextColor: Colors.white,
                            entryModeIconColor: Color(0xFF4FC3F7),
                            dayPeriodTextColor: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1A2A3A), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.access_time, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('Saat: ${_selectedTime.format(context)}', style: const TextStyle(color: Colors.white))]),
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Güncelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
        prefixIcon: Icon(icon, color: const Color(0xFF4FC3F7)),
        filled: true,
        fillColor: const Color(0xFF1A2A3A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Bu alan zorunludur' : null,
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
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadPaymentQr(widget.orgId);
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Kod yüklendi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A2A3A),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.currentQrUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: WebSafeImage(url: widget.currentQrUrl!, fit: BoxFit.contain),
                    )
                  : const Icon(Icons.qr_code, color: Color(0xFF546E7A), size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ödeme QR Kodu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    widget.currentQrUrl != null ? 'QR kod yüklendi ✓' : 'Henüz QR kod yüklenmedi',
                    style: TextStyle(color: widget.currentQrUrl != null ? Colors.green : const Color(0xFF90A4AE), fontSize: 12),
                  ),
                ],
              ),
            ),
            _isUploading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF4FC3F7), strokeWidth: 2))
                : IconButton(
                    icon: Icon(widget.currentQrUrl != null ? Icons.refresh : Icons.upload, color: const Color(0xFF4FC3F7)),
                    onPressed: _uploadQr,
                    tooltip: widget.currentQrUrl != null ? 'QR Kodu Değiştir' : 'QR Kod Yükle',
                  ),
          ],
        ),
      ),
    );
  }
}
