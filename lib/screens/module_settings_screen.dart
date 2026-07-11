import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/module_provider.dart';
import '../providers/auth_provider.dart';
import 'branding_settings_screen.dart';

class ModuleSettingsScreen extends ConsumerWidget {
  const ModuleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(moduleRegistryProvider);
    final l10n = ref.read(translationProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: const Text('Modül Yönetimi'),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: availableModules.length,
              itemBuilder: (context, i) {
                final module = availableModules[i];
                final isEnabled = registry[module.id] ?? false;

                return Card(
                  color: const Color(0xFF1A2A3A),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    title: Text(module.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(module.description, style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 12)),
                    value: isEnabled,
                    onChanged: module.isCore ? null : (val) {
                      ref.read(moduleOperationsProvider.notifier).toggleModule(module.id, val);
                    },
                    activeColor: const Color(0xFF4FC3F7),
                    inactiveThumbColor: Colors.grey,
                  ),
                );
              },
            ),
          ),
          // Branding button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandingSettingsScreen())),
                icon: const Icon(Icons.brush, color: Color(0xFF4FC3F7)),
                label: const Text('Marka Özelleştirme', style: TextStyle(color: Color(0xFF4FC3F7))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4FC3F7)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
