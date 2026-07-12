import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../widgets/web_safe_image.dart';

class BrandingSettingsScreen extends ConsumerStatefulWidget {
  const BrandingSettingsScreen({super.key});

  @override
  ConsumerState<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends ConsumerState<BrandingSettingsScreen> {
  final _logoController = TextEditingController();
  final _colorController = TextEditingController();
  bool _useBranding = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final org = ref.read(currentOrganizationProvider).value;
    if (org != null) {
      _useBranding = org.useBranding;
      _logoController.text = org.logoUrl ?? '';
      _colorController.text = org.primaryColorHex ?? '#1565C0';
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final org = ref.read(currentOrganizationProvider).value;
    if (org == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(org.id).update({
        'useBranding': _useBranding,
        'logoUrl': _logoController.text.trim().isEmpty ? null : _logoController.text.trim(),
        'primaryColorHex': _colorController.text.trim().isEmpty ? '#1565C0' : _colorController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marka ayarları kaydedildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.read(translationProvider.notifier);
    final branding = ref.watch(brandingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('Marka Özelleştirme'),
        backgroundColor: branding.useBranding ? branding.primaryColor : const Color(0xFF1565C0),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Enable toggle
            Card(
              color: const Color(0xFF1A2A3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                title: const Text('Özel Markalama', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Logo ve renk özelleştirmesini aktifleştir', style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
                value: _useBranding,
                onChanged: (v) => setState(() => _useBranding = v),
                activeColor: const Color(0xFF4FC3F7),
              ),
            ),
            const SizedBox(height: 24),

            if (_useBranding) ...[
              // Logo URL
              Text('Logo URL', style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _logoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://example.com/logo.png',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A2A3A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.image, color: Color(0xFF4FC3F7)),
                ),
              ),
              const SizedBox(height: 16),

              // Color
              Text('Ana Renk', style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(_colorController.text),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _colorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '#1565C0',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A2A3A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showColorPicker(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF1A2A3A), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.colorize, color: Color(0xFF4FC3F7)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Preview
              Text('Önizleme', style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: _parseColor(_colorController.text),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: _logoController.text.isNotEmpty
                      ? WebSafeImage(url: _logoController.text, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white, size: 32))
                      : const Text('Ratel Solutions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      0xFF1565C0, 0xFF0D47A1, 0xFF1B5E20, 0xFFB71C1C, 0xFF4A148C,
      0xFFE65100, 0xFF004D40, 0xFF37474F, 0xFF4FC3F7, 0xFF69F0AE,
      0xFFFF5252, 0xFFFFD740, 0xFF7C4DFF, 0xFF00BCD4, 0xFFFF4081,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2A3A),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) => GestureDetector(
            onTap: () {
              _colorController.text = '#${c.toRadixString(16).substring(2).toUpperCase()}';
              Navigator.pop(ctx);
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white24, width: 2)),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
