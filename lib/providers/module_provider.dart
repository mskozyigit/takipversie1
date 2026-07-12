import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class Module {
  final String id;
  final String name;
  final String description;
  final bool isCore;
  final List<String> dependsOn;

  const Module({
    required this.id,
    required this.name,
    required this.description,
    this.isCore = false,
    this.dependsOn = const [],
  });
}

const List<Module> availableModules = [
  Module(id: 'AUTH-01', name: 'Google Login', description: 'Google OAuth2 login for all users', isCore: true),
  Module(id: 'ORG-01', name: 'Organization', description: 'Organization creation + join code', isCore: true),
  Module(id: 'ORG-02', name: 'Approval Queue', description: 'Pending-approval queue for new members', isCore: true),
  Module(id: 'RBAC-01', name: 'RBAC', description: 'Role-based access control', isCore: true),
  Module(id: 'CAL-01', name: 'Calendar', description: 'Calendar home screen', isCore: true),
  Module(id: 'CAL-02', name: 'Status Colors', description: 'Live status color-coding', isCore: true),
  Module(id: 'CAL-03', name: 'Worker Filter', description: 'Admin filter-by-worker view'),
  Module(id: 'JOB-01', name: 'Job Creation', description: 'Admin job creation', isCore: true),
  Module(id: 'JOB-02', name: 'Checklist', description: 'Worker guided checklist', isCore: true),
  Module(id: 'JOB-03', name: 'Mandatory Gates', description: 'Required photos and payment gates', dependsOn: ['MEDIA-01', 'PAY-01']),
  Module(id: 'JOB-04', name: 'Extra Fields', description: '"+" optional-field picker for job creation', isCore: true),
  Module(id: 'JOB-06', name: 'Mission Numbers', description: 'Auto-generated, editable Mission Numbers', isCore: true),
  Module(id: 'JOB-07', name: 'Job Templates', description: 'Admin creates reusable job templates with default values', isCore: true),
  Module(id: 'MEDIA-01', name: 'Photos', description: 'Before/after photo capture'),
  Module(id: 'MEDIA-02', name: 'Compression', description: 'Client-side photo compression', dependsOn: ['MEDIA-01']),
  Module(id: 'MEDIA-05', name: 'Digital Signature', description: 'On-screen digital signature capture'),
  Module(id: 'LOG-01', name: 'Travel Estimates', description: 'Distance-based travel-time estimates', isCore: true),
  Module(id: 'PAY-01', name: 'Payments (1-slot)', description: 'Static image/QR or cash override'),
  Module(id: 'PAY-02', name: 'Payments (3-slot)', description: 'Three independent payment slots', dependsOn: ['PAY-01']),
  Module(id: 'CRM-01', name: 'Customer Directory', description: 'Reusable address + contact records'),
  Module(id: 'INV-01', name: 'Inventory', description: 'Materials/parts line-items'),
  Module(id: 'SAFE-01', name: 'Safety Checklist', description: 'Configurable safety/compliance checklist'),
  Module(id: 'TEAM-01', name: 'Comments', description: 'Task-level comments'),
  Module(id: 'REP-01', name: 'Analytics', description: 'Admin analytics dashboard'),
  Module(id: 'TEAM-02', name: 'Push Notifications', description: 'Real-time push notifications via FCM', isCore: true),
  Module(id: 'ADM-01', name: 'Branding', description: 'Custom logo and primary color'),
  Module(id: 'ADM-02', name: 'Multi-language', description: 'TR/EN/NL language toggle for all users', isCore: true),
  Module(id: 'ADM-03', name: 'Audit Log', description: 'Who changed what, when'),
];

final moduleRegistryProvider = Provider<Map<String, bool>>((ref) {
  final org = ref.watch(currentOrganizationProvider).value;
  if (org == null) return {};

  final Map<String, bool> registry = {};
  for (var module in availableModules) {
    if (module.isCore) {
      registry[module.id] = true;
    } else {
      registry[module.id] = org.enabledModules[module.id] ?? false;
    }
  }
  return registry;
});

class ModuleNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> toggleModule(String moduleId, bool enabled) async {
    final org = ref.read(currentOrganizationProvider).value;
    if (org == null) return;

    final updatedModules = Map<String, bool>.from(org.enabledModules);
    updatedModules[moduleId] = enabled;

    await FirebaseFirestore.instance
        .collection('organizations')
        .doc(org.id)
        .update({'enabledModules': updatedModules});
  }
}

final moduleOperationsProvider = NotifierProvider<ModuleNotifier, void>(() => ModuleNotifier());
