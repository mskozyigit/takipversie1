import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_queue_provider.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/job_template.dart';
import '../widgets/web_safe_image.dart';
import '../theme/app_theme.dart';

class JobCreationScreen extends ConsumerStatefulWidget {
  const JobCreationScreen({super.key});

  @override
  ConsumerState<JobCreationScreen> createState() => _JobCreationScreenState();
}

class _JobCreationScreenState extends ConsumerState<JobCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _distanceController = TextEditingController();
  final _feeController = TextEditingController();
  final _missionNumberController = TextEditingController();
  final List<TextEditingController> _extraDescControllers = [];
  final _customerNameFocus = FocusNode();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  AppUser? _selectedWorker;
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _showFeeField = false;
  String? _paymentQrUrl;
  bool _customerDialogShown = false;
  int _durationHours = 2;

  @override
  void initState() {
    super.initState();
    // Müşteri adı alanından çıkınca, yeni isimse otomatik dialog aç
    _customerNameFocus.addListener(() {
      if (!_customerNameFocus.hasFocus && !_customerDialogShown) {
        _checkAndAutoOpenCustomerDialog();
      }
    });
  }

  @override
  void dispose() {
    _customerNameFocus.dispose();
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _distanceController.dispose();
    _feeController.dispose();
    _missionNumberController.dispose();
    for (var c in _extraDescControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addDescriptionBlock() {
    setState(() {
      _extraDescControllers.add(TextEditingController());
    });
  }

  /// Müşteri adı yazılıp başka alana geçildiğinde, CRM'de yoksa otomatik dialog açar
  void _checkAndAutoOpenCustomerDialog() {
    final typedName = _customerNameController.text.trim();
    if (typedName.isEmpty) return;
    
    final customersAsync = ref.read(customersProvider);
    customersAsync.whenData((customers) {
      final exists = customers.any((c) => c.name.toLowerCase() == typedName.toLowerCase());
      if (!exists && mounted && !_customerDialogShown) {
        _customerDialogShown = true;
        // Dialog'un kapanmasını bekle, sonra form alanlarını doldur
        _showAutoAddCustomerDialog(typedName);
      }
    });
  }

  /// Otomatik açılan müşteri ekleme dialogu — kaydedince form alanlarını doldurur
  void _showAutoAddCustomerDialog(String prefillName) {
    final l10n = ref.read(translationProvider.notifier);
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.person_add, color: Color(0xFF4FC3F7), size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.translate('crm_save_new_customer'), style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(prefillName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl, 
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white), 
              decoration: InputDecoration(
                labelText: l10n.translate('customer_phone_label'), 
                labelStyle: TextStyle(color: context.appExt.textSecondary),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF4FC3F7)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl, 
              maxLines: 2,
              style: const TextStyle(color: Colors.white), 
              decoration: InputDecoration(
                labelText: l10n.translate('customer_address_label'), 
                labelStyle: TextStyle(color: context.appExt.textSecondary),
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF4FC3F7)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _customerDialogShown = false;
              Navigator.pop(ctx);
            }, 
            child: Text(l10n.translate('button_skip'), style: TextStyle(color: context.appExt.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (prefillName.isEmpty) return;
              await ref.read(jobOperationsProvider.notifier).createCustomer(
                name: prefillName,
                address: addressCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              // Form alanlarını doldur
              setState(() {
                _customerNameController.text = prefillName;
                _customerPhoneController.text = phoneCtrl.text.trim();
                _addressController.text = addressCtrl.text.trim();
                _customerDialogShown = false;
              });
            },
            icon: const Icon(Icons.save, size: 18),
            label: Text(l10n.translate('customer_save_and_continue')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref, {String? prefillName}) {
    final l10n = ref.read(translationProvider.notifier);
    final nameCtrl = TextEditingController(text: prefillName);
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('customer_add_new_title'), style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.translate('customer_name_label'),
                labelStyle: TextStyle(color: context.appExt.textSecondary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.translate('customer_phone_label'),
                labelStyle: TextStyle(color: context.appExt.textSecondary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.translate('customer_address_label'),
                labelStyle: TextStyle(color: context.appExt.textSecondary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('button_cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(jobOperationsProvider.notifier).createCustomer(
                name: nameCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              // Form alanlarını doldur
              _customerNameController.text = nameCtrl.text.trim();
              _customerPhoneController.text = phoneCtrl.text.trim();
              _addressController.text = addressCtrl.text.trim();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: Text(l10n.translate('button_add')),
          ),
        ],
      ),
    );
  }

  void _uploadQrForJob(BuildContext context) async {
    final l10n = ref.read(translationProvider.notifier);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 600);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(currentOrganizationProvider).value?.id;
      if (orgId == null || orgId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('org_info_not_loaded')), backgroundColor: Colors.orange),
          );
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final url = await ref.read(mediaProvider.notifier).uploadPaymentQr(orgId);
      if (url != null) {
        setState(() => _paymentQrUrl = url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('qr_uploaded')), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('qr_upload_failed')), backgroundColor: Colors.red),
        );
      }
      debugPrint('QR upload failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = ref.read(translationProvider.notifier);
    setState(() => _isLoading = true);

    try {
      final distance = double.tryParse(_distanceController.text);
      final fee = double.tryParse(_feeController.text);
      
      // Separate attached images from description blocks
      final attachedImages = <String>[];
      final descBlocks = <String>[];
      for (final c in _extraDescControllers) {
        final text = c.text.trim();
        if (text.startsWith('[RESIM]')) {
          attachedImages.add(text.substring(7));
        } else if (text.isNotEmpty) {
          descBlocks.add(text);
        }
      }
      
      final isOnline = ref.read(connectivityProvider);

      if (isOnline) {
        await ref.read(jobOperationsProvider.notifier).createJob(
              title: _titleController.text.trim(),
              description: _descController.text.trim(),
              descriptionBlocks: descBlocks,
              attachedImages: attachedImages,
              assignedWorkerId: _selectedWorker?.id ?? 'unassigned',
              assignedWorkerName: _selectedWorker?.name ?? l10n.translate('unassigned'),
              address: _addressController.text.trim(),
              customerName: _customerNameController.text.trim(),
              customerPhone: _customerPhoneController.text.trim(),
              customerId: _selectedCustomer?.id,
              scheduledDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute),
              distanceKm: distance,
              fee: fee,
              durationHours: _durationHours,
              missionNumber: _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('job_created_success')), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
          );
          Navigator.pop(context);
        }
      } else {
        // Çevrimdışı: kuyruğa ekle
        await ref.read(offlineQueueProvider.notifier).enqueue({
          'type': 'createJob',
          'data': {
            'title': _titleController.text.trim(),
            'description': _descController.text.trim(),
            'assignedWorkerId': _selectedWorker?.id ?? 'unassigned',
            'assignedWorkerName': _selectedWorker?.name ?? l10n.translate('unassigned'),
            'address': _addressController.text.trim(),
            'customerName': _customerNameController.text.trim(),
            'customerPhone': _customerPhoneController.text.trim(),
            'scheduledDate': DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute).toIso8601String(),
            'missionNumber': _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
            'distanceKm': distance,
            'fee': fee,
            'durationHours': _durationHours,
            'descriptionBlocks': descBlocks,
          },
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('job_queued_offline')), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns true if the user has entered any data into the form.
  bool _hasUnsavedChanges() {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_descController.text.trim().isNotEmpty) return true;
    if (_addressController.text.trim().isNotEmpty) return true;
    if (_customerNameController.text.trim().isNotEmpty) return true;
    if (_customerPhoneController.text.trim().isNotEmpty) return true;
    if (_distanceController.text.trim().isNotEmpty) return true;
    if (_feeController.text.trim().isNotEmpty) return true;
    if (_missionNumberController.text.trim().isNotEmpty) return true;
    if (_extraDescControllers.any((c) => c.text.trim().isNotEmpty)) return true;
    if (_selectedWorker != null) return true;
    if (_selectedCustomer != null) return true;
    if (_showFeeField) return true;
    if (_durationHours != 2) return true;
    if (_paymentQrUrl != null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(organizationWorkersProvider);
    final customersAsync = ref.watch(customersProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_hasUnsavedChanges()) {
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(ctx).colorScheme.surface,
                title: Text(l10n.translate('exit_unsaved_title'), style: const TextStyle(color: Colors.white)),
                content: Text(l10n.translate('exit_unsaved_message'), style: TextStyle(color: context.appExt.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.translate('button_cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.translate('button_ok'), style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (shouldPop == true && context.mounted) {
              Navigator.pop(context);
            }
          } else {
            if (context.mounted) Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('job_create_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : Theme.of(context).colorScheme.primary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // JOB-07: Template selector
              _buildTemplateSelector(l10n),
              const SizedBox(height: 16),

              // 1. 🏷 Görev No (opsiyonel — boş bırakılırsa otomatik atanır)
              _buildField(l10n.translate('job_mission_number'), _missionNumberController, Icons.tag, isRequired: false),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 12),
                child: Text(
                  l10n.translate('mission_number_hint'),
                  style: TextStyle(color: context.appExt.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),

              // 2. 👤 Müşteri Adı
              _buildField(l10n.translate('job_customer_name'), _customerNameController, Icons.person, 
                onChanged: (_) { if (_customerDialogShown) _customerDialogShown = false; setState(() {}); },
                focusNode: _customerNameFocus,
                onFieldSubmitted: (_) => _customerNameFocus.unfocus(),
              ),
              const SizedBox(height: 8),
              // Yeni müşteriyi hemen kaydet butonu
              customersAsync.when(
                data: (customers) {
                  final typedName = _customerNameController.text.trim();
                  final exists = typedName.isNotEmpty && customers.any((c) => c.name.toLowerCase() == typedName.toLowerCase());
                  if (typedName.isEmpty) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: exists ? null : () => _showAddCustomerDialog(context, ref, prefillName: typedName),
                      icon: Icon(exists ? Icons.check_circle : Icons.save, size: 18),
                      label: Text(l10n.translate(exists ? 'customer_registered' : 'customer_save')),
                      style: ElevatedButton.styleFrom(backgroundColor: exists ? Colors.green.withOpacity(0.2) : const Color(0xFF1565C0), foregroundColor: exists ? Colors.green : Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red, fontSize: 11)),
                ),
              ),
              // CRM: Mevcut müşterilerden seç
              customersAsync.when(
                data: (customers) => customers.isEmpty ? const SizedBox() : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Customer?>(value: _selectedCustomer, hint: Text(l10n.translate('crm_customer_search'), style: const TextStyle(color: Colors.grey, fontSize: 13)), dropdownColor: Theme.of(context).colorScheme.surface, isExpanded: true, style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [DropdownMenuItem(value: null, child: Text(l10n.translate('customer_select_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13))), ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13))))],
                      onChanged: (val) { setState(() { _selectedCustomer = val; if (val != null) { _customerNameController.text = val.name; _customerPhoneController.text = val.phone; _addressController.text = val.address; } }); },
                    ),
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 12),

              // 3. 📞 Telefon
              _buildField(l10n.translate('job_customer_phone'), _customerPhoneController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),

              // 4. 📍 Adres
              _buildField(l10n.translate('job_address'), _addressController, Icons.location_on, maxLines: 2),
              const SizedBox(height: 16),

              // 5. 📅 Tarih
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('job_date')}: ${l10n.translate('date_format_short', {'day': '${_selectedDate.day}', 'month': '${_selectedDate.month}', 'year': '${_selectedDate.year}'})}', style: const TextStyle(color: Colors.white))]),
                ),
              ),
              const SizedBox(height: 12),

              // 6. 🕐 Saat
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _selectedTime,
                    builder: (context, child) => Theme(data: ThemeData.dark(useMaterial3: true).copyWith(
                      colorScheme: const ColorScheme.dark(primary: Color(0xFF4FC3F7), onPrimary: Color(0xFF0D1B2A), surface: Color(0xFF1A2A3A), onSurface: Colors.white),
                      timePickerTheme: const TimePickerThemeData(backgroundColor: Color(0xFF1A2A3A), hourMinuteTextColor: Colors.white, hourMinuteColor: Color(0xFF0D1B2A), dialHandColor: Color(0xFF4FC3F7), dialBackgroundColor: Color(0xFF0D1B2A), dialTextColor: Colors.white, entryModeIconColor: Color(0xFF4FC3F7), dayPeriodTextColor: Colors.white),
                    ), child: child!),
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.access_time, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('time_label')} ${_selectedTime.format(context)}', style: const TextStyle(color: Colors.white, fontSize: 16))]),
                ),
              ),
              const SizedBox(height: 12),

              // 7. ⏱ Süre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.timelapse, color: Color(0xFF4FC3F7)), const SizedBox(width: 12),
                  Text(l10n.translate('duration_label'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 14)), const SizedBox(width: 8),
                  DropdownButton<int>(value: _durationHours, dropdownColor: Theme.of(context).colorScheme.surface, style: const TextStyle(color: Colors.white, fontSize: 16), underline: const SizedBox(),
                    items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text(l10n.translate('template_desc_duration_hours', {'hours': '$h'}), style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _durationHours = v ?? 2),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // 8. 📝 İş Başlığı
              _buildField(l10n.translate('job_title'), _titleController, Icons.title),
              const SizedBox(height: 12),

              // 9. 📄 Açıklama
              _buildField(l10n.translate('job_description'), _descController, Icons.description, maxLines: 3),
              const SizedBox(height: 12),

              // 10. 👷 Personel (opsiyonel)
              Text(l10n.translate('job_assignee'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              workersAsync.when(
                data: (workers) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppUser?>(value: _selectedWorker, hint: Text(l10n.translate('worker_select_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13)), dropdownColor: Theme.of(context).colorScheme.surface, isExpanded: true, style: const TextStyle(color: Colors.white),
                      items: [DropdownMenuItem(value: null, child: Text(l10n.translate('worker_not_selected'), style: const TextStyle(color: Colors.grey, fontSize: 13))), ...workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name)))],
                      onChanged: (val) => setState(() => _selectedWorker = val),
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),

              // 11. 🗺 Mesafe (opsiyonel)
              _buildField(l10n.translate('log_distance_label'), _distanceController, Icons.map, keyboardType: TextInputType.number, isRequired: false),
              const SizedBox(height: 12),

              // 💰 Ücret (opsiyonel)
              if (_showFeeField) ...[
                Row(children: [
                  Expanded(child: _buildField(l10n.translate('job_fee_label'), _feeController, Icons.payments, keyboardType: TextInputType.number, isRequired: false)),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.qr_code, color: Color(0xFF4FC3F7)), tooltip: l10n.translate('qr_code_add_tooltip'), onPressed: () => _uploadQrForJob(context), style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface)),
                ]),
                const SizedBox(height: 12),
              ],
              if (!_showFeeField)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: Text(l10n.translate('add_fee_button'), style: const TextStyle(color: Color(0xFF4FC3F7))), onPressed: () => setState(() => _showFeeField = true), backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
                ),

              // 12. 📎 Açıklama Blokları
              ..._extraDescControllers.asMap().entries.map((entry) {
                final text = entry.value.text;
                if (text.startsWith('[RESIM]')) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ImagePreviewBlock(
                      imageUrl: text.substring(7),
                      onRemove: () => setState(() => _extraDescControllers.removeAt(entry.key)),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildField(l10n.translate('extra_description_label', {'number': '${entry.key + 1}'}), entry.value, Icons.add_comment),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: Text(l10n.translate('add_description_block'), style: const TextStyle(color: Color(0xFF4FC3F7))), onPressed: _addDescriptionBlock, backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
              ),

              // Resim Ekleme
              _ImageUploadField(onImagePicked: (url) { if (url != null) _extraDescControllers.add(TextEditingController(text: '[RESIM]$url')); }),

              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(l10n.translate('job_submit'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
          ),
      ),
    ),
    );
  }

  // JOB-07: Template selector widget
  Widget _buildTemplateSelector(dynamic l10n) {
    final templatesAsync = ref.watch(jobTemplatesProvider);

    return templatesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox();

        return InkWell(
          onTap: () => _showTemplatePicker(templates),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: Color(0xFF4FC3F7), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.translate('template_load_from'),
                    style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${templates.length} ${l10n.translate('template_desc_title').toLowerCase()}',
                    style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, color: Color(0xFF4FC3F7), size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTemplatePicker(List<JobTemplate> templates) {
    final l10n = ref.read(translationProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('template_select_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(l10n.translate('template_select_subtitle'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ...templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _applyTemplate(t);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Color(0xFF4FC3F7), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(_describeTemplateFields(t), style: TextStyle(color: context.appExt.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: context.appExt.textTertiary, size: 14),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _applyTemplate(JobTemplate t) {
    final l10n = ref.read(translationProvider.notifier);
    setState(() {
      if (t.includeTitle && t.defaultTitle.isNotEmpty) _titleController.text = t.defaultTitle;
      if (t.includeDescription && t.defaultDescription.isNotEmpty) _descController.text = t.defaultDescription;

      // Clear existing extra description controllers and add template ones
      for (var c in _extraDescControllers) { c.dispose(); }
      _extraDescControllers.clear();
      if (t.includeDescriptionBlocks) {
        for (var block in t.defaultDescriptionBlocks) {
          if (block.isNotEmpty) _extraDescControllers.add(TextEditingController(text: block));
        }
      }

      if (t.includeCustomerName && t.defaultCustomerName.isNotEmpty) _customerNameController.text = t.defaultCustomerName;
      if (t.includeCustomerPhone && t.defaultCustomerPhone.isNotEmpty) _customerPhoneController.text = t.defaultCustomerPhone;
      if (t.includeAddress && t.defaultAddress.isNotEmpty) _addressController.text = t.defaultAddress;

      if (t.includeFee) {
        _showFeeField = true;
        if (t.defaultFee != null) _feeController.text = t.defaultFee!.toStringAsFixed(0);
      }
      if (t.includeDistance && t.defaultDistance != null) {
        _distanceController.text = t.defaultDistance!.toStringAsFixed(1);
      }
      if (t.includeDuration) {
        _durationHours = t.defaultDurationHours;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('template_load_from')), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
      );
    }
  }

  String _describeTemplateFields(JobTemplate t) {
    final l10n = ref.read(translationProvider.notifier);
    final parts = <String>[];
    if (t.includeTitle) parts.add(l10n.translate('template_desc_title'));
    if (t.includeDescription) parts.add(l10n.translate('template_desc_description'));
    if (t.includeDescriptionBlocks) parts.add(l10n.translate('template_desc_extras'));
    if (t.includeCustomerName) parts.add(l10n.translate('template_desc_customer'));
    if (t.includeAddress) parts.add(l10n.translate('template_desc_address'));
    if (t.includeFee) parts.add(l10n.translate('template_desc_fee'));
    if (t.includeDistance) parts.add(l10n.translate('template_desc_distance'));
    if (t.includeDuration) parts.add(l10n.translate('template_desc_duration_hours', {'hours': '${t.defaultDurationHours}'}));
    return parts.join(', ');
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType, void Function(String)? onChanged, FocusNode? focusNode, void Function(String)? onFieldSubmitted, bool isRequired = true}) {
    final l10n = ref.read(translationProvider.notifier);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.appExt.textSecondary),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: isRequired ? (v) => v == null || v.trim().isEmpty ? l10n.translate('validation_required') : null : null,
    );
  }
}

class _ImagePreviewBlock extends ConsumerWidget {
  final String imageUrl;
  final VoidCallback onRemove;
  const _ImagePreviewBlock({required this.imageUrl, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: WebSafeImage(
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.image, color: Color(0xFF4FC3F7), size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(l10n.translate('image_added'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 12))),
                InkWell(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.redAccent, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageUploadField extends ConsumerStatefulWidget {
  final void Function(String?) onImagePicked;
  const _ImageUploadField({required this.onImagePicked});

  @override
  ConsumerState<_ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<_ImageUploadField> {
  String? _imageUrl;
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final l10n = ref.read(translationProvider.notifier);
    // Show source picker for mobile reliability
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('photo_add_title'), style: const TextStyle(color: Colors.white)),
        content: Text(l10n.translate('photo_add_source'), style: TextStyle(color: context.appExt.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library, color: Color(0xFF4FC3F7), size: 20),
                const SizedBox(width: 8),
                Text(l10n.translate('photo_gallery'), style: const TextStyle(color: Color(0xFF4FC3F7))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: Text(l10n.translate('photo_camera')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (source == null || !mounted) return;
    
    final picker = ImagePicker();
    setState(() => _isUploading = true);
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 65, maxWidth: 800);
      if (picked == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final org = ref.read(currentOrganizationProvider).value;
      if (org == null || org.id.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('org_info_not_loaded')), backgroundColor: Colors.orange),
          );
        }
        if (mounted) setState(() => _isUploading = false);
        return;
      }
      final url = await ref.read(mediaProvider.notifier).uploadJobPhotoFromBytes(
        orgId: org.id,
        jobId: 'creation_${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
        isBefore: true,
      );
      if (url != null) {
        setState(() => _imageUrl = url);
        widget.onImagePicked(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_photo_error', {'error': '$e'})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    return InkWell(
      onTap: _isUploading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.3), width: 1),
        ),
        child: _isUploading
            ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary)))
            : _imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: WebSafeImage(url: _imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, color: Color(0xFF4FC3F7), size: 28),
                      const SizedBox(width: 12),
                      Text(l10n.translate('photo_add_button'), style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
      ),
    );
  }
}
