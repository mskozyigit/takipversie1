import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../providers/job_provider.dart';
import '../models/app_user.dart';
import '../models/job.dart';
import 'module_settings_screen.dart';
import 'job_template_screen.dart';
import '../widgets/calendar/join_code_card.dart';
import '../widgets/web_safe_image.dart';
import '../widgets/checklist/multi_photo_picker.dart';
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
  final _distanceController = TextEditingController();
  final _feeController = TextEditingController();
  final List<TextEditingController> _extraDescControllers = [];
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  AppUser? _selectedWorker;
  bool _isLoading = false;
  bool _showFeeField = false;
  int _durationHours = 2;
  List<String> _attachedImages = [];
  bool _isImageUploading = false;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _titleController = TextEditingController(text: j.title);
    _descController = TextEditingController(text: j.description);
    _addressController = TextEditingController(text: j.address);
    _customerNameController = TextEditingController(text: j.customerName);
    _customerPhoneController = TextEditingController(text: j.customerPhone);
    _missionNumberController = TextEditingController(text: j.missionNumber);
    _selectedDate = j.scheduledDate;
    _selectedTime = TimeOfDay.fromDateTime(j.scheduledDate);
    _durationHours = j.durationHours;
    _attachedImages = List.from(j.attachedImages);
    if (j.fee != null) {
      _feeController.text = j.fee!.toStringAsFixed(0);
      _showFeeField = true;
    }
    // Load existing description blocks (text only — images handled separately)
    for (final block in j.descriptionBlocks) {
      _extraDescControllers.add(TextEditingController(text: block));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _missionNumberController.dispose();
    _distanceController.dispose();
    _feeController.dispose();
    for (var c in _extraDescControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final l10n = ref.read(translationProvider.notifier);
    try {
      final distance = double.tryParse(_distanceController.text);
      final fee = double.tryParse(_feeController.text);
      final descBlocks = _extraDescControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

      await ref.read(jobOperationsProvider.notifier).updateJob(
        jobId: widget.job.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        assignedWorkerId: _selectedWorker?.id ?? 'unassigned',
        assignedWorkerName: _selectedWorker?.name ?? l10n.translate('unassigned'),
        address: _addressController.text.trim(),
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        scheduledDate: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute),
        missionNumber: _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
        distanceKm: distance,
        fee: fee,
        durationHours: _durationHours,
        descriptionBlocks: descBlocks,
        attachedImages: _attachedImages,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addDescriptionBlock() {
    setState(() => _extraDescControllers.add(TextEditingController()));
  }

  /// Pick and upload an image for job edit. Returns the download URL.
  Future<String?> _pickAndUploadImage() async {
    final l10n = ref.read(translationProvider.notifier);

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

    if (source == null || !mounted) return null;

    setState(() => _isImageUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadJobPhoto(
        jobId: widget.job.id,
        isBefore: true,
        source: source,
      );
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('photo_before_uploaded')), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
        return url;
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final msg = e.code == 'unavailable'
            ? l10n.translate('checklist_photo_offline')
            : l10n.translate('job_checklist_photo_error', {'error': e.message ?? 'Unknown error'});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('job_checklist_photo_error', {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImageUploading = false);
    }
    return null;
  }

  /// Returns true if the user has modified any field from the original job.
  bool _hasUnsavedChanges() {
    final j = widget.job;
    if (_titleController.text.trim() != j.title) return true;
    if (_descController.text.trim() != j.description) return true;
    if (_addressController.text.trim() != j.address) return true;
    if (_customerNameController.text.trim() != (j.customerName ?? '')) return true;
    if (_customerPhoneController.text.trim() != (j.customerPhone ?? '')) return true;
    if (_missionNumberController.text.trim() != j.missionNumber) return true;
    if (_distanceController.text.trim().isNotEmpty) return true;
    if (_feeController.text.trim() != (j.fee?.toStringAsFixed(0) ?? '')) return true;
    if ((_selectedWorker?.id ?? 'unassigned') != j.assignedWorkerId) return true;
    if (_durationHours != j.durationHours) return true;
    if (_showFeeField != (j.fee != null)) return true;
    final origDate = j.scheduledDate;
    if (_selectedDate.day != origDate.day || _selectedDate.month != origDate.month || _selectedDate.year != origDate.year) return true;
    if (_selectedTime.hour != origDate.hour || _selectedTime.minute != origDate.minute) return true;
    final origBlocks = j.descriptionBlocks.where((b) => !b.startsWith('[RESIM]')).toList();
    final currentBlocks = _extraDescControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (origBlocks.length != currentBlocks.length) return true;
    for (int i = 0; i < origBlocks.length; i++) {
      if (origBlocks[i] != currentBlocks[i]) return true;
    }
    // Check attached images
    final origImages = j.attachedImages;
    if (origImages.length != _attachedImages.length) return true;
    for (int i = 0; i < origImages.length; i++) {
      if (origImages[i] != _attachedImages[i]) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(organizationWorkersProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    // Initial worker selection
    workersAsync.whenData((workers) {
      if (_selectedWorker == null) {
        _selectedWorker = workers.cast<AppUser?>().firstWhere((w) => w?.id == widget.job.assignedWorkerId, orElse: () => null);
      }
    });

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
      appBar: AppBar(title: Text(l10n.translate('job_edit_title')), backgroundColor: branding.useBranding ? branding.primaryColor : Theme.of(context).colorScheme.primary),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Görev No (opsiyonel)
              _buildField(l10n.translate('job_mission_number'), _missionNumberController, Icons.tag, isRequired: false),
              const SizedBox(height: 12),

              // 2. Müşteri Adı
              _buildField(l10n.translate('job_customer_name'), _customerNameController, Icons.person),
              const SizedBox(height: 12),

              // 3. Telefon
              _buildField(l10n.translate('job_customer_phone'), _customerPhoneController, Icons.phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),

              // 4. Adres
              _buildField(l10n.translate('job_address'), _addressController, Icons.location_on, maxLines: 2),
              const SizedBox(height: 16),

              // 5. Tarih
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('job_date')}: ${l10n.translate('date_format_short', {'day': '${_selectedDate.day}', 'month': '${_selectedDate.month}', 'year': '${_selectedDate.year}'})}', style: const TextStyle(color: Colors.white))]),
                ),
              ),
              const SizedBox(height: 12),

              // 6. Saat
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context, initialTime: _selectedTime,
                    builder: (context, child) => Theme(data: ThemeData.dark(useMaterial3: true).copyWith(
                      colorScheme: const ColorScheme.dark(primary: Color(0xFF4FC3F7), onPrimary: Color(0xFF0D1B2A), surface: Color(0xFF1A2A3A), onSurface: Colors.white),
                      timePickerTheme: const TimePickerThemeData(backgroundColor: Color(0xFF1A2A3A), hourMinuteTextColor: Colors.white, hourMinuteColor: Color(0xFF0D1B2A), dialHandColor: Color(0xFF4FC3F7), dialBackgroundColor: Color(0xFF0D1B2A), dialTextColor: Colors.white, entryModeIconColor: Color(0xFF4FC3F7), dayPeriodTextColor: Colors.white),
                    ), child: child!),
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.access_time, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('time_label')} ${_selectedTime.format(context)}', style: const TextStyle(color: Colors.white))]),
                ),
              ),
              const SizedBox(height: 12),

              // 7. Süre
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.timelapse, color: Color(0xFF4FC3F7)), const SizedBox(width: 12),
                  Text(l10n.translate('duration_label'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 14)), const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _durationHours, dropdownColor: Theme.of(context).colorScheme.surface,
                    style: const TextStyle(color: Colors.white, fontSize: 16), underline: const SizedBox(),
                    items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text(l10n.translate('template_desc_duration_hours', {'hours': '$h'}), style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _durationHours = v ?? 2),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // 8. İş Başlığı
              _buildField(l10n.translate('job_title'), _titleController, Icons.title),
              const SizedBox(height: 12),

              // 9. Açıklama
              _buildField(l10n.translate('job_description'), _descController, Icons.description, maxLines: 3),
              const SizedBox(height: 12),

              // 10. Personel (opsiyonel)
              Text(l10n.translate('job_assignee'), style: TextStyle(color: context.appExt.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              workersAsync.when(
                data: (workers) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppUser?>(
                      value: _selectedWorker,
                      hint: Text(l10n.translate('worker_select_hint'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      dropdownColor: Theme.of(context).colorScheme.surface, isExpanded: true,
                      style: const TextStyle(color: Colors.white),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.translate('worker_not_selected'), style: const TextStyle(color: Colors.grey, fontSize: 13))),
                        ...workers.map((w) => DropdownMenuItem(value: w, child: Text(w.name))),
                      ],
                      onChanged: (val) => setState(() => _selectedWorker = val),
                    ),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(l10n.translate('generic_error', {'error': '$e'})),
              ),
              const SizedBox(height: 16),

              // 11. Mesafe (opsiyonel)
              _buildField(l10n.translate('log_distance_label'), _distanceController, Icons.map, keyboardType: TextInputType.number, isRequired: false),
              const SizedBox(height: 12),

              // Ücret (opsiyonel)
              if (_showFeeField) ...[
                _buildField(l10n.translate('job_fee_label'), _feeController, Icons.payments, keyboardType: TextInputType.number, isRequired: false),
                const SizedBox(height: 12),
              ],
              if (!_showFeeField)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)),
                    label: Text(l10n.translate('add_fee_button'), style: const TextStyle(color: Color(0xFF4FC3F7))),
                    onPressed: () => setState(() => _showFeeField = true),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5),
                  ),
                ),

              // 12. Açıklama Blokları
              ..._extraDescControllers.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(l10n.translate('extra_description_label', {'number': '${entry.key + 1}'}), entry.value, Icons.add_comment, isRequired: false),
              )),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)),
                  label: Text(l10n.translate('add_description_block'), style: const TextStyle(color: Color(0xFF4FC3F7))),
                  onPressed: _addDescriptionBlock,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5),
                ),
              ),

              // 13. Ekli Görseller
              MultiPhotoPicker(
                photoUrls: _attachedImages,
                label: l10n.translate('attached_images'),
                isUploading: _isImageUploading,
                onPickPhoto: _pickAndUploadImage,
                onPhotosChanged: (urls) => setState(() => _attachedImages = urls),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(l10n.translate('button_update'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType, bool isRequired = true}) {
    final l10n = ref.read(translationProvider.notifier);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
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
