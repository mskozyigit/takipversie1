import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/job_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/media_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_queue_provider.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../models/job_template.dart';
import '../models/job.dart';
import 'checklist/multi_photo_picker.dart';
import '../theme/app_theme.dart';

/// Shared job form used by both Create and Edit screens.
/// Eliminates ~80% code duplication between JobCreationScreen and JobEditScreen.
enum JobFormMode { create, edit }

class JobForm extends ConsumerStatefulWidget {
  final JobFormMode mode;
  final Job? initialJob; // Required for edit mode

  const JobForm({super.key, required this.mode, this.initialJob});

  @override
  ConsumerState<JobForm> createState() => _JobFormState();
}

class _JobFormState extends ConsumerState<JobForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _distanceController;
  late final TextEditingController _feeController;
  late final TextEditingController _missionNumberController;
  final List<TextEditingController> _extraDescControllers = [];
  final _customerNameFocus = FocusNode();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  AppUser? _selectedWorker;
  Customer? _selectedCustomer;
  bool _isLoading = false;
  bool _showFeeField = false;
  String? _paymentQrUrl;
  bool _customerDialogShown = false;
  int _durationHours = 2;
  List<String> _attachedImages = [];
  bool _isImageUploading = false;
  /// Pre-generated job ID for create mode — used for image uploads before job exists.
  late final String? _pendingJobId;

  bool get isEdit => widget.mode == JobFormMode.edit;
  Job? get job => widget.initialJob;

  @override
  void initState() {
    super.initState();
    final j = job;

    if (isEdit && j != null) {
      _pendingJobId = j.id;
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
        _feeController = TextEditingController(text: j.fee!.toStringAsFixed(0));
        _showFeeField = true;
      } else {
        _feeController = TextEditingController();
      }
      for (final block in j.descriptionBlocks) {
        _extraDescControllers.add(TextEditingController(text: block));
      }
      // CRUD parity: load customer from customerId so edit pre-selects linked customer
      if (j.customerId != null) {
        _loadCustomerById(j.customerId!);
      }
    } else {
      // Create mode
      _pendingJobId = FirebaseFirestore.instance.collection('jobs').doc().id;
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _addressController = TextEditingController();
      _customerNameController = TextEditingController();
      _customerPhoneController = TextEditingController();
      _missionNumberController = TextEditingController();
      _feeController = TextEditingController();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
    _distanceController = TextEditingController();

    // Create-only: auto-detect new customer when leaving customer name field
    if (!isEdit) {
      _customerNameFocus.addListener(() {
        if (!_customerNameFocus.hasFocus && !_customerDialogShown) {
          _checkAndAutoOpenCustomerDialog();
        }
      });
    }
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

  // ─── Image Picker (shared) ───

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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.photo_library, color: Color(0xFF4FC3F7), size: 20),
              const SizedBox(width: 8),
              Text(l10n.translate('photo_gallery'), style: const TextStyle(color: Color(0xFF4FC3F7))),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: Text(l10n.translate('photo_camera')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (source == null || !mounted) return null;

    setState(() => _isImageUploading = true);
    try {
      final url = await ref.read(mediaProvider.notifier).uploadJobPhoto(
        jobId: _pendingJobId!,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_checklist_photo_error', {'error': e.toString()})), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isImageUploading = false);
    }
    return null;
  }

  // ─── Description Blocks ───

  void _addDescriptionBlock() {
    setState(() => _extraDescControllers.add(TextEditingController()));
  }

  // ─── Customer Auto-Detect (create only) ───

  /// Loads a customer by ID and pre-selects it in the dropdown.
  /// Used in edit mode to restore customer association.
  void _loadCustomerById(String customerId) {
    final customersAsync = ref.read(customersProvider);
    customersAsync.whenData((customers) {
    final matches = customers.where((c) => c.id == customerId);
    if (matches.isNotEmpty && mounted) {
      setState(() => _selectedCustomer = matches.first);
      }
    });
  }

  void _checkAndAutoOpenCustomerDialog() {
    if (isEdit) return;
    final typedName = _customerNameController.text.trim();
    if (typedName.isEmpty) return;
    final customersAsync = ref.read(customersProvider);
    customersAsync.whenData((customers) {
      final exists = customers.any((c) => c.name.toLowerCase() == typedName.toLowerCase());
      if (!exists && mounted && !_customerDialogShown) {
        _customerDialogShown = true;
        _showAutoAddCustomerDialog(typedName);
      }
    });
  }

  void _showAutoAddCustomerDialog(String prefillName) {
    final l10n = ref.read(translationProvider.notifier);
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Row(children: [
          const Icon(Icons.person_add, color: Color(0xFF4FC3F7), size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.translate('crm_save_new_customer'), style: const TextStyle(color: Colors.white, fontSize: 18))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF0D1B2A), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.person, color: Color(0xFF4FC3F7), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(prefillName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 16),
          _dialogField(phoneCtrl, l10n.translate('customer_phone_label'), Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _dialogField(addressCtrl, l10n.translate('customer_address_label'), Icons.location_on, maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () { _customerDialogShown = false; Navigator.pop(ctx); }, child: Text(l10n.translate('button_skip'), style: TextStyle(color: context.appExt.textSecondary))),
          ElevatedButton.icon(
            onPressed: () async {
              if (prefillName.isEmpty) return;
              await ref.read(jobOperationsProvider.notifier).createCustomer(name: prefillName, address: addressCtrl.text.trim(), phone: phoneCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {
                _customerNameController.text = prefillName;
                _customerPhoneController.text = phoneCtrl.text.trim();
                _addressController.text = addressCtrl.text.trim();
                _customerDialogShown = false;
              });
            },
            icon: const Icon(Icons.save, size: 18),
            label: Text(l10n.translate('customer_save_and_continue')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog({String? prefillName}) {
    final l10n = ref.read(translationProvider.notifier);
    final nameCtrl = TextEditingController(text: prefillName);
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(l10n.translate('customer_add_new_title'), style: const TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(nameCtrl, l10n.translate('customer_name_label'), Icons.person),
          const SizedBox(height: 8),
          _dialogField(phoneCtrl, l10n.translate('customer_phone_label'), Icons.phone),
          const SizedBox(height: 8),
          _dialogField(addressCtrl, l10n.translate('customer_address_label'), Icons.location_on),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('button_cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(jobOperationsProvider.notifier).createCustomer(name: nameCtrl.text.trim(), address: addressCtrl.text.trim(), phone: phoneCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
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

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl, keyboardType: keyboardType, maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: context.appExt.textSecondary),
        filled: true, fillColor: Theme.of(context).colorScheme.surface,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
      ),
    );
  }

  // ─── QR Upload (create only) ───

  Future<void> _uploadQrForJob() async {
    final l10n = ref.read(translationProvider.notifier);
    setState(() => _isLoading = true);
    try {
      final orgId = ref.read(currentOrganizationProvider).value?.id;
      if (orgId == null || orgId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('org_info_not_loaded')), backgroundColor: Colors.orange));
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final url = await ref.read(mediaProvider.notifier).uploadPaymentQr(orgId);
      if (url != null) {
        setState(() => _paymentQrUrl = url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('qr_uploaded')), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('qr_upload_failed')), backgroundColor: Colors.red));
      debugPrint('QR upload failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Submit ───

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = ref.read(translationProvider.notifier);
    setState(() => _isLoading = true);

    try {
      final distance = double.tryParse(_distanceController.text);
      final fee = double.tryParse(_feeController.text);
      final attachedImages = List<String>.from(_attachedImages);
      final descBlocks = _extraDescControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      final scheduledDt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

      if (isEdit) {
        await ref.read(jobOperationsProvider.notifier).updateJob(
          jobId: job!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          assignedWorkerId: _selectedWorker?.id ?? 'unassigned',
          assignedWorkerName: _selectedWorker?.name ?? l10n.translate('unassigned'),
          address: _addressController.text.trim(),
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.trim(),
          customerId: _selectedCustomer?.id,
          scheduledDate: scheduledDt,
          missionNumber: _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
          distanceKm: distance,
          fee: fee,
          durationHours: _durationHours,
          descriptionBlocks: descBlocks,
          attachedImages: attachedImages,
        );
        if (mounted) Navigator.pop(context);
      } else {
        final isOnline = ref.read(connectivityProvider);
        if (isOnline) {
          await ref.read(jobOperationsProvider.notifier).createJob(
            id: _pendingJobId,
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
            scheduledDate: scheduledDt,
            distanceKm: distance,
            fee: fee,
            durationHours: _durationHours,
            missionNumber: _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_created_success')), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
            Navigator.pop(context);
          }
        } else {
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
              'scheduledDate': scheduledDt.toIso8601String(),
              'missionNumber': _missionNumberController.text.trim().isEmpty ? null : _missionNumberController.text.trim(),
              'distanceKm': distance,
              'fee': fee,
              'durationHours': _durationHours,
              'descriptionBlocks': descBlocks,
            },
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('job_queued_offline')), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('generic_error', {'error': '$e'})), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Unsaved Changes Detection ───

  bool _hasUnsavedChanges() {
    if (isEdit && job != null) {
      final j = job!;
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
      final origBlocks = j.descriptionBlocks;
      final currentBlocks = _extraDescControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (origBlocks.length != currentBlocks.length) return true;
      for (int i = 0; i < origBlocks.length; i++) {
        if (origBlocks[i] != currentBlocks[i]) return true;
      }
      final origImages = j.attachedImages;
      if (origImages.length != _attachedImages.length) return true;
      for (int i = 0; i < origImages.length; i++) {
        if (origImages[i] != _attachedImages[i]) return true;
      }
      return false;
    }
    // Create mode: any data entered = unsaved
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
    if (_attachedImages.isNotEmpty) return true;
    return false;
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(organizationWorkersProvider);
    final customersAsync = ref.watch(customersProvider);
    ref.watch(translationProvider);
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    // Initial worker selection for edit mode
    if (isEdit && job != null) {
      workersAsync.whenData((workers) {
        if (_selectedWorker == null) {
          _selectedWorker = workers.cast<AppUser?>().firstWhere((w) => w?.id == job!.assignedWorkerId, orElse: () => null);
        }
      });
    }

    final titleText = isEdit ? l10n.translate('job_edit_title') : l10n.translate('job_create_title');
    final submitLabel = isEdit ? l10n.translate('button_update') : l10n.translate('job_submit');

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
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.translate('button_cancel'))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.translate('button_ok'), style: const TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (shouldPop == true && context.mounted) Navigator.pop(context);
          } else {
            if (context.mounted) Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Template selector (create only)
                  if (!isEdit) ...[
                    _buildTemplateSelector(l10n),
                    const SizedBox(height: 16),
                  ],

                  // Mission Number
                  _buildField(l10n.translate('job_mission_number'), _missionNumberController, Icons.tag, isRequired: false),
                  const SizedBox(height: 12),

                  // Customer Name
                  _buildField(l10n.translate('job_customer_name'), _customerNameController, Icons.person,
                    onChanged: isEdit ? null : (_) { if (_customerDialogShown) _customerDialogShown = false; setState(() {}); },
                    focusNode: isEdit ? null : _customerNameFocus,
                    onFieldSubmitted: isEdit ? null : (_) => _customerNameFocus.unfocus(),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 8),
                    customersAsync.when(
                      data: (customers) {
                        final typedName = _customerNameController.text.trim();
                        final exists = typedName.isNotEmpty && customers.any((c) => c.name.toLowerCase() == typedName.toLowerCase());
                        if (typedName.isEmpty) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton.icon(
                            onPressed: exists ? null : () => _showAddCustomerDialog(prefillName: typedName),
                            icon: Icon(exists ? Icons.check_circle : Icons.save, size: 18),
                            label: Text(l10n.translate(exists ? 'customer_registered' : 'customer_save')),
                            style: ElevatedButton.styleFrom(backgroundColor: exists ? Colors.green.withOpacity(0.2) : const Color(0xFF1565C0), foregroundColor: exists ? Colors.green : Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        );
                      },
                      loading: () => const SizedBox(),
                      error: (e, _) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l10n.translate('generic_error', {'error': '$e'}), style: const TextStyle(color: Colors.red, fontSize: 11))),
                    ),
                    // CRM customer dropdown
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
                  ],
                  const SizedBox(height: 12),

                  // Phone
                  _buildField(l10n.translate('job_customer_phone'), _customerPhoneController, Icons.phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),

                  // Address
                  _buildField(l10n.translate('job_address'), _addressController, Icons.location_on, maxLines: 2),
                  const SizedBox(height: 16),

                  // Date
                  _buildDatePicker(l10n),
                  const SizedBox(height: 12),

                  // Time
                  _buildTimePicker(l10n),
                  const SizedBox(height: 12),

                  // Duration
                  _buildDurationDropdown(l10n),
                  const SizedBox(height: 24),

                  // Title
                  _buildField(l10n.translate('job_title'), _titleController, Icons.title),
                  const SizedBox(height: 12),

                  // Description
                  _buildField(l10n.translate('job_description'), _descController, Icons.description, maxLines: 3),
                  const SizedBox(height: 12),

                  // Worker
                  _buildWorkerDropdown(l10n, workersAsync),
                  const SizedBox(height: 24),

                  // Distance
                  _buildField(l10n.translate('log_distance_label'), _distanceController, Icons.map, keyboardType: TextInputType.number, isRequired: false),
                  const SizedBox(height: 12),

                  // Fee
                  if (_showFeeField) ...[
                    Row(children: [
                      Expanded(child: _buildField(l10n.translate('job_fee_label'), _feeController, Icons.payments, keyboardType: TextInputType.number, isRequired: false)),
                      if (!isEdit) ...[
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.qr_code, color: Color(0xFF4FC3F7)), tooltip: l10n.translate('qr_code_add_tooltip'), onPressed: _uploadQrForJob, style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface)),
                      ],
                    ]),
                    const SizedBox(height: 12),
                  ],
                  if (!_showFeeField)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: Text(l10n.translate('add_fee_button'), style: const TextStyle(color: Color(0xFF4FC3F7))), onPressed: () => setState(() => _showFeeField = true), backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
                    ),

                  // Description Blocks
                  ..._extraDescControllers.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildField(l10n.translate('extra_description_label', {'number': '${entry.key + 1}'}), entry.value, Icons.add_comment, isRequired: false),
                  )),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ActionChip(avatar: const Icon(Icons.add, size: 16, color: Color(0xFF4FC3F7)), label: Text(l10n.translate('add_description_block'), style: const TextStyle(color: Color(0xFF4FC3F7))), onPressed: _addDescriptionBlock, backgroundColor: Theme.of(context).colorScheme.surface, side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5)),
                  ),

                  // Attached Images
                  MultiPhotoPicker(
                    photoUrls: _attachedImages,
                    label: l10n.translate('attached_images'),
                    isUploading: _isImageUploading,
                    onPickPhoto: _pickAndUploadImage,
                    onPhotosChanged: (urls) => setState(() => _attachedImages = urls),
                  ),

                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(submitLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sub-Widgets ───

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType, bool isRequired = true, FocusNode? focusNode, ValueChanged<String>? onChanged, ValueChanged<String>? onFieldSubmitted}) {
    final l10n = ref.read(translationProvider.notifier);
    return TextFormField(
      controller: controller, maxLines: maxLines, keyboardType: keyboardType, focusNode: focusNode,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      onChanged: onChanged, onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(color: context.appExt.textSecondary),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        filled: true, fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: isRequired ? (v) => v == null || v.trim().isEmpty ? l10n.translate('validation_required') : null : null,
    );
  }

  Widget _buildDatePicker(dynamic l10n) {
    return InkWell(
      onTap: () async {
        final firstDate = isEdit ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: firstDate, lastDate: DateTime.now().add(const Duration(days: 365)));
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [const Icon(Icons.calendar_today, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text('${l10n.translate('job_date')}: ${l10n.translate('date_format_short', {'day': '${_selectedDate.day}', 'month': '${_selectedDate.month}', 'year': '${_selectedDate.year}'})}', style: const TextStyle(color: Colors.white))]),
      ),
    );
  }

  Widget _buildTimePicker(dynamic l10n) {
    return InkWell(
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
    );
  }

  Widget _buildDurationDropdown(dynamic l10n) {
    return Container(
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
    );
  }

  Widget _buildWorkerDropdown(dynamic l10n, AsyncValue<List<AppUser>> workersAsync) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
    ]);
  }

  // ─── Template Selector (create only) ───

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
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.4))),
            child: Row(children: [const Icon(Icons.bookmark_outline, color: Color(0xFF4FC3F7)), const SizedBox(width: 12), Text(l10n.translate('template_select_hint'), style: const TextStyle(color: Color(0xFF4FC3F7)))],),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => ListView.separated(
        shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const Divider(color: Color(0xFF37474F), height: 1),
        itemBuilder: (ctx, i) {
          final t = templates[i];
          return ListTile(
            leading: const Icon(Icons.description, color: Color(0xFF4FC3F7)),
            title: Text(t.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(l10n.translate('template_fields_count', {'count': '${_countTemplateFields(t)}'}), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _applyTemplate(t); },
          );
        },
      ),
    );
  }

  int _countTemplateFields(JobTemplate t) {
    int count = 0;
    if (t.includeTitle) count++;
    if (t.includeDescription) count++;
    if (t.includeDescriptionBlocks) count++;
    if (t.includeCustomerName) count++;
    if (t.includeCustomerPhone) count++;
    if (t.includeAddress) count++;
    if (t.includeFee) count++;
    if (t.includeDistance) count++;
    if (t.includeDuration) count++;
    return count;
  }

  void _applyTemplate(JobTemplate t) {
    setState(() {
      if (t.includeTitle) _titleController.text = t.defaultTitle;
      if (t.includeDescription) _descController.text = t.defaultDescription;
      if (t.includeCustomerName) _customerNameController.text = t.defaultCustomerName;
      if (t.includeCustomerPhone) _customerPhoneController.text = t.defaultCustomerPhone;
      if (t.includeAddress) _addressController.text = t.defaultAddress;
      if (t.includeFee && t.defaultFee != null) { _feeController.text = t.defaultFee!.toStringAsFixed(0); _showFeeField = true; }
      if (t.includeDuration) _durationHours = t.defaultDurationHours;
      if (t.includeDescriptionBlocks && t.defaultDescriptionBlocks.isNotEmpty) {
        for (final block in t.defaultDescriptionBlocks) {
          _extraDescControllers.add(TextEditingController(text: block));
        }
      }
    });
  }
}
