import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class OrgSetupScreen extends ConsumerStatefulWidget {
  final User firebaseUser;

  const OrgSetupScreen({super.key, required this.firebaseUser});

  @override
  ConsumerState<OrgSetupScreen> createState() => _OrgSetupScreenState();
}

class _OrgSetupScreenState extends ConsumerState<OrgSetupScreen> {
  // 'create' veya 'join'
  String _mode = 'create';

  final _orgNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _orgNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);

    if (_mode == 'create') {
      await notifier.createOrganization(
        firebaseUser: widget.firebaseUser,
        orgName: _orgNameController.text.trim(),
      );
    } else {
      await notifier.joinOrganization(
        firebaseUser: widget.firebaseUser,
        joinCode: _joinCodeController.text.trim(),
      );
    }

    // Hata durumunda SnackBar
    if (!mounted) return;
    final authState = ref.read(authProvider).value;
    if (authState is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF90A4AE)),
          tooltip: l10n.translate('logout'),
          onPressed: () => ref.read(authProvider.notifier).signOut(),
        ),
        title: Text(
          l10n.translate('org_setup_title'),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Karşılama mesajı
              Text(
                '${l10n.translate('org_setup_welcome')}, ${widget.firebaseUser.displayName?.split(' ').first ?? 'Kullanıcı'}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('org_setup_subtitle'),
                style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Mod seçici
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _ModeTab(
                      label: l10n.translate('org_setup_create'),
                      icon: Icons.add_business,
                      isSelected: _mode == 'create',
                      onTap: () => setState(() => _mode = 'create'),
                    ),
                    _ModeTab(
                      label: l10n.translate('org_setup_join'),
                      icon: Icons.group_add,
                      isSelected: _mode == 'join',
                      onTap: () => setState(() => _mode = 'join'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Dinamik form alanı
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _mode == 'create'
                    ? _CreateOrgForm(controller: _orgNameController)
                    : _JoinOrgForm(controller: _joinCodeController),
              ),
              const SizedBox(height: 32),

              // Gönder butonu
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _mode == 'create' ? l10n.translate('org_setup_submit_create') : l10n.translate('org_setup_submit_join'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Tab widget
// -----------------------------------------------------------------------

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected ? Colors.white : const Color(0xFF90A4AE),
                  size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF90A4AE),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Create Org Form
// -----------------------------------------------------------------------

class _CreateOrgForm extends ConsumerWidget {
  final TextEditingController controller;

  const _CreateOrgForm({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      key: const ValueKey('create'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.translate('org_setup_name_label')),
        const SizedBox(height: 8),
        _StyledField(
          controller: controller,
          hint: l10n.translate('org_setup_name_hint'),
          prefixIcon: Icons.business,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l10n.translate('org_setup_name_label') : null,
        ),
        const SizedBox(height: 16),
        const _InfoBox(
          icon: Icons.info_outline,
          text:
              'Siz organizasyonu oluşturan Admin olacaksınız. Katılım kodu otomatik olarak oluşturulacak ve Dashboard\'da görüntülenebilecek.',
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Join Org Form
// -----------------------------------------------------------------------

class _JoinOrgForm extends ConsumerWidget {
  final TextEditingController controller;

  const _JoinOrgForm({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.read(translationProvider.notifier);
    return Column(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.translate('org_setup_join_label')),
        const SizedBox(height: 8),
        _StyledField(
          controller: controller,
          hint: l10n.translate('org_setup_join_hint'),
          prefixIcon: Icons.vpn_key,
          textCapitalization: TextCapitalization.characters,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.translate('org_setup_join_label');
            if (v.trim().length != 6) return 'Kod 6 karakter olmalıdır';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const _InfoBox(
          icon: Icons.schedule,
          text:
              'Kodunu girdikten sonra hesabınız Admin onayına gönderilecek. Onay süreci tamamlanana kadar sisteme giriş yapamazsınız.',
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Shared sub-widgets
// -----------------------------------------------------------------------

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF90A4AE),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF546E7A)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF4FC3F7)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Color(0xFFEF9A9A)),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4FC3F7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
