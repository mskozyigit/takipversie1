import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
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
              decoration: const InputDecoration(
                labelText: 'Telefon', 
                labelStyle: TextStyle(color: Color(0xFF90A4AE)),
                prefixIcon: Icon(Icons.phone, color: Color(0xFF4FC3F7)),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl, 
              maxLines: 2,
              style: const TextStyle(color: Colors.white), 
              decoration: const InputDecoration(
                labelText: 'Adres', 
                labelStyle: TextStyle(color: Color(0xFF90A4AE)),
                prefixIcon: Icon(Icons.location_on, color: Color(0xFF4FC3F7)),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
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
            child: const Text('Atla', style: TextStyle(color: Color(0xFF90A4AE))),
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
            label: const Text('Kaydet ve Devam Et'),
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
    final nameCtrl = TextEditingController(text: prefillName);
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Yeni Müşteri Ekle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Ad',
                labelStyle: TextStyle(color: Color(0xFF90A4AE)),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Telefon',
                labelStyle: TextStyle(color: Color(0xFF90A4AE)),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: addressCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Adres',
                labelStyle: TextStyle(color: Color(0xFF90A4AE)),
                filled: true,
                fillColor: Color(0xFF0D1B2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
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
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _uploadQrForJob(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 600);
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await picked.readAsBytes();
      final orgId = ref.read(currentOrganizationProvider).value?.id ?? 'temp';
      final refStorage = FirebaseStorage.instance.ref().child('$orgId/settings/payment_qr.jpg');
      await refStorage.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await refStorage.getDownloadURL();
      
      // Update organization doc
      await FirebaseFirestore.instance.collection('organizations').doc(orgId).update({'paymentQrUrl': url});
      
      setState(() => _paymentQrUrl = url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Kod yüklendi ✓'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Kod yüklenemedi'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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
      
      await ref.read(jobOperationsProvider.notifier).createJob(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            descriptionBlocks: descBlocks,
            attachedImages: attachedImages,
            assignedWorkerId: _selectedWorker?.id ?? 'unassigned',
            assignedWorkerName: _selectedWorker?.name ?? 'Atanmadı',
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(organizationWorkersProvider);
    final customersAsync = ref.watch(customersProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('job_create_title')),
        backgroundColor: branding.useBranding ? branding.primaryColor : Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
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
                  '💡 Boş bırakılırsa otomatik görev numarası atanır.',
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
                      label: Text(exists ? 'Müşteri kayıtlı ✓' : 'Müşteriyi Kaydet'),
                      style: ElevatedButton.styleFrom(backgroundColor: exists ? Colors.green.withOpacity(0.2) : const Color(0xFF1565C0), foregroundColor: exists ? Colors.green : Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              // CRM: Mevcut müşterilerden seç
              customersAsync.when(
                data: (customers) => customers.isEmpty ? const SizedBox() : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Customer?>(value: _selectedCustomer, hint: Text(l10n.translate('crm_customer_search'), style: const TextStyle(color: Colors.grey, fontSize: 13)), dropdownColor: Theme.of(context).colorScheme.surface, isExpanded: true, style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [const DropdownMenuItem(value: null, child: Text('Kayıtlı müşteri seç...', style: TextStyle(color: Colors.grey, fontSize: 13))), ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13))))],
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
                  child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('job_date')}: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(color: Colors.white))]),
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
                  child: Row(children: [const Icon(Icons.access_time, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('Saat: ${_selectedTime.format(context)}', style: const TextStyle(color: Colors.white, fontSize: 16))]),
                ),
              ),
              const SizedBox(height: 12),

              // 7. ⏱ Süre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.timelapse, color: Color(0xFF4FC3F7)), const SizedBox(width: 12),
                  const Text('Süre:', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14)), const SizedBox(width: 8),
                  DropdownButton<int>(value: _durationHours, dropdownColor: Theme.of(context).colorScheme.surface, style: const TextStyle(color: Colors.white, fontSize: 16), underline: const SizedBox(),
                    items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text('$h saat', style: const TextStyle(color: Colors.white)))).toList(),
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
              Text(l10n.translate('job_assignee'), style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
              const SizedBox(height: 8),
              workersAsync.when(
                data: (workers) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppUser?>(value: _selectedWorker, hint: const Text('Sonradan atanabilir', style: TextStyle(color: Colors.grey, fontSize: 13)), dropdownColor: Theme.of(context).colorScheme.surface, isExpanded: true, style: const TextStyle(color: Colors.white),
                      items: [const DropdownMenuItem(value: null, child: Text('Personel seçilmedi', style: TextStyle(color: Colors.grey, fontSize: 13))), ...workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name)))],
                      onChanged: (val) => setState(() => _selectedWorker = val),
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Hata: $e', style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),

              // 11. 🗺 Mesafe (opsiyonel)
              _buildField(l10n.translate('log_distance_label'), _distanceController, Icons.map, keyboardType: TextInputType.number, isRequired: false),
              const SizedBox(height: 12),

              // 💰 Ücret (opsiyonel)
              if (_showFeeField) ...[
                Row(children: [
                  Expanded(child: _buildField('İş Ücreti', _feeController, Icons.payments, keyboardType: TextInputType.number, isRequired: false)),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.qr_code, color: Color(0xFF4FC3F7)), tooltip: 'QR Kod Ekle', onPressed: () => _uploadQrForJob(context), style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface)),
                ]),
                const SizedBox(height: 12),
              ],
              if (!_showFeeField)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: const Text('Ücret Ekle', style: TextStyle(color: Color(0xFF4FC3F7))), onPressed: () => setState(() => _showFeeField = true), backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
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
                  child: _buildField('Ek Açıklama ${entry.key + 1}', entry.value, Icons.add_comment),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: const Text('Açıklama Bloğu Ekle', style: TextStyle(color: Color(0xFF4FC3F7))), onPressed: _addDescriptionBlock, backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
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
                    '${templates.length} şablon',
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
            const Text('Şablon Seç', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Seçilen şablon form alanlarını dolduracaktır.', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13)),
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
                            Text(_describeTemplateFields(t), style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF546E7A), size: 14),
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
        SnackBar(content: Text('"${t.name}" şablonu uygulandı ✓'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
      );
    }
  }

  String _describeTemplateFields(JobTemplate t) {
    final parts = <String>[];
    if (t.includeTitle) parts.add('Başlık');
    if (t.includeDescription) parts.add('Açıklama');
    if (t.includeDescriptionBlocks) parts.add('Ek Blok');
    if (t.includeCustomerName) parts.add('Müşteri');
    if (t.includeAddress) parts.add('Adres');
    if (t.includeFee) parts.add('Ücret');
    if (t.includeDistance) parts.add('Mesafe');
    if (t.includeDuration) parts.add('${t.defaultDurationHours}s');
    return parts.join(', ');
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType, void Function(String)? onChanged, FocusNode? focusNode, void Function(String)? onFieldSubmitted, bool isRequired = true}) {
    final l10n = ref.read(translationProvider.notifier);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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

class _ImagePreviewBlock extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onRemove;
  const _ImagePreviewBlock({required this.imageUrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
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
                      Text('Yüklenemedi', style: TextStyle(color: context.appExt.textSecondary, fontSize: 11)),
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
                const Expanded(child: Text('Resim eklendi', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12))),
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
    // Show source picker for mobile reliability
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('Fotoğraf Ekle', style: TextStyle(color: Colors.white)),
        content: const Text('Nereden fotoğraf eklemek istersiniz?', style: TextStyle(color: Color(0xFF90A4AE))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library, color: Color(0xFF4FC3F7), size: 20),
                SizedBox(width: 8),
                Text('Galeri', style: TextStyle(color: Color(0xFF4FC3F7))),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Kamera'),
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
            const SnackBar(content: Text('Organizasyon bilgisi henüz yüklenmedi. Lütfen tekrar deneyin.'), backgroundColor: Colors.orange),
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
          SnackBar(content: Text('Fotoğraf yüklenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    children: const [
                      Icon(Icons.add_a_photo, color: Color(0xFF4FC3F7), size: 28),
                      SizedBox(width: 12),
                      Text('Fotoğraf Ekle', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 15, fontWeight: FontWeight.w500)),
                    ],
                  ),
      ),
    );
  }
}
