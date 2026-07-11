import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/app_user.dart';
import '../models/job.dart';
import 'job_creation_screen.dart';

class AdminDashboard extends ConsumerWidget {
  final AppUser adminUser;

  const AdminDashboard({super.key, required this.adminUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('${l10n.translate('admin_panel_title')} — ${adminUser.name}'),
        backgroundColor: const Color(0xFF1565C0),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Organizasyon Bilgi Kartı (Join Code buraya eklendi)
          orgAsync.when(
            data: (org) => org == null
                ? const SizedBox()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2A3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1565C0), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${l10n.translate('admin_join_code')}: ',
                              style: const TextStyle(color: Color(0xFF90A4AE)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1B2A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                org.joinCode,
                                style: const TextStyle(
                                  color: Color(0xFF4FC3F7),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Color(0xFF4FC3F7), size: 20),
                              onPressed: () {
                                // Opsiyonel: Panoya kopyalama eklenebilir
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kod kopyalandı!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
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
          const SizedBox(height: 16),
          JobEditScreen(job: adminUser.jobs.first),
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
  late DateTime _selectedDate;
  AppUser? _selectedWorker;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _descController = TextEditingController(text: widget.job.description);
    _addressController = TextEditingController(text: widget.job.address);
    _selectedDate = widget.job.scheduledDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
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
        scheduledDate: _selectedDate,
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

    // Initial worker selection fix
    workersAsync.whenData((workers) {
      if (_selectedWorker == null) {
        _selectedWorker = workers.cast<AppUser?>().firstWhere((w) => w?.id == widget.job.assignedWorkerId, orElse: () => null);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(title: Text(l10n.translate('job_title') + ' Düzenle'), backgroundColor: const Color(0xFF1565C0)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(l10n.translate('job_title'), _titleController, Icons.title),
              const SizedBox(height: 16),
              _buildField(l10n.translate('job_description'), _descController, Icons.description, maxLines: 3),
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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
