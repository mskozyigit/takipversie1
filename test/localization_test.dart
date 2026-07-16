import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Validates: (1) key parity across 3 language files,
/// (2) placeholder consistency, (3) QR management keys,
/// (4) no hardcoded Turkish text in UI Dart files,
/// (5) all l10n.translate() keys in Dart code exist in JSON files.

void main() {
  late Map<String, dynamic> tr;
  late Map<String, dynamic> en;
  late Map<String, dynamic> nl;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tr = jsonDecode(await rootBundle.loadString('assets/lang/tr.json'));
    en = jsonDecode(await rootBundle.loadString('assets/lang/en.json'));
    nl = jsonDecode(await rootBundle.loadString('assets/lang/nl.json'));
  });

  // ─── Key parity ───
  group('Localization key parity', () {
    test('all TR keys exist in EN', () {
      final missing = tr.keys.where((k) => !en.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'Missing EN: ${missing.join(', ')}');
    });
    test('all TR keys exist in NL', () {
      final missing = tr.keys.where((k) => !nl.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'Missing NL: ${missing.join(', ')}');
    });
    test('all EN keys exist in TR', () {
      final extra = en.keys.where((k) => !tr.containsKey(k)).toList();
      expect(extra, isEmpty, reason: 'Extra EN (not in TR): ${extra.join(', ')}');
    });
    test('all NL keys exist in TR', () {
      final extra = nl.keys.where((k) => !tr.containsKey(k)).toList();
      expect(extra, isEmpty, reason: 'Extra NL (not in TR): ${extra.join(', ')}');
    });
    test('all 3 files have same key count', () {
      expect(en.length, tr.length, reason: 'EN=${en.length} TR=${tr.length}');
      expect(nl.length, tr.length, reason: 'NL=${nl.length} TR=${tr.length}');
    });
  });

  // ─── Placeholder match ───
  group('Placeholder validation', () {
    test('{param} placeholders match across all languages', () {
      for (final key in tr.keys) {
        final trVal = tr[key] as String?;
        if (trVal == null || !trVal.contains('{')) continue;

        final trParams = _placeholders(trVal);
        final enVal = en[key] as String?;
        final nlVal = nl[key] as String?;

        if (enVal != null) {
          final enParams = _placeholders(enVal);
          expect(enParams, trParams,
              reason: 'Placeholder mismatch "$key": TR=$trParams EN=$enParams');
        }
        if (nlVal != null) {
          final nlParams = _placeholders(nlVal);
          expect(nlParams, trParams,
              reason: 'Placeholder mismatch "$key": TR=$trParams NL=$nlParams');
        }
      }
    });
  });

  // ─── QR management keys ───
  group('QR management keys (PAY-03)', () {
    const qrKeys = [
      'qr_management_title', 'qr_management_desc', 'qr_remove',
      'qr_remove_confirm', 'qr_not_uploaded', 'qr_upload',
      'qr_replace', 'qr_uploaded', 'qr_upload_error',
    ];
    for (final key in qrKeys) {
      test('$key exists in all languages', () {
        for (final lang in [tr, en, nl]) {
          expect(lang[key], isA<String>(), reason: 'Missing: $key');
          expect((lang[key] as String).isNotEmpty, isTrue, reason: 'Empty: $key');
        }
      });
    }
  });

  // ─── Hardcoded UI text scanner (all languages) ───
  group('UI hardcoded text scan', () {
    final _violations = <String>[];

    setUpAll(() {
      _violations.clear();
      final dirs = ['lib/screens', 'lib/widgets'];

      // Patterns that indicate a string is NOT a UI label:
      final _isCode = RegExp(
        r'^[a-z]+(_[a-z]+)+$|'        // snake_case (field names, keys)
        r'^[#\[]|'                     // starts with # or [
        r'^[0-9\s\.,:;!?+\-*/%=<>()\[\]{}@&\^|~`]+$|' // symbols only
        r'^(true|false|null)$|'        // literals
        r'^(GET|POST|PUT|DELETE)$'     // HTTP methods
      );

      // Known data values that look like text but aren't UI labels
      final _dataValues = {
        'tr', 'en', 'nl',              // language codes
        'qr', 'cash', 'admin', 'worker', // enum values
        'notStarted', 'inProgress', 'workCompleted', 'closed', // status
        'approved', 'pending', 'rejected', // approval status
        'before', 'after',             // photo labels
        'temp',                        // placeholder
        'Ratel Solutions',             // brand name
      };

      for (final dir in dirs) {
        final d = Directory(dir);
        if (!d.existsSync()) continue;
        for (final file in d.listSync(recursive: true)) {
          if (file is! File || !file.path.endsWith('.dart')) continue;
          final content = file.readAsStringSync();
          final lines = content.split('\n');
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            final t = line.trimLeft();
            if (t.startsWith('//') || t.startsWith('import ') ||
                t.startsWith('*') || t.isEmpty) continue;
            if (line.contains('l10n.translate') || line.contains('.translate(')) continue;

            // Catch ALL quoted strings that look like UI text:
            // Single quotes, double quotes, and triple-quoted strings
            final matches = [
              // Widget patterns: Text('...'), label: '...', tooltip: '...', etc.
              ...RegExp(
                r"(?:Text|label|tooltip|hintText|title|content|subtitle|message"
                r"|hint|header|placeholder|empty|errorText|helperText"
                r"|child|icon|prefix|suffix|name|value|text)"
                r"\s*[:\(]\s*'([^']+)'",
              ).allMatches(line),
              // Double-quoted: Text("..."), label: "..."
              ...RegExp(
                r'(?:Text|label|tooltip|hintText|title|content|subtitle|message'
                r'|hint|header|placeholder|empty|errorText|helperText'
                r'|child|icon|prefix|suffix|name|value|text)'
                r'\s*[:\(]\s*"([^"]+)"',
              ).allMatches(line),
              // Triple-quoted single: '''...'''
              ...RegExp(r"'''([^']+)'''").allMatches(content),
              // Triple-quoted double: """..."""
              ...RegExp(r'"""([^"]+)"""').allMatches(content),
            ];

            for (final m in matches) {
              final text = m.group(1)!;
              if (text.length < 2) continue;
              if (_isCode.hasMatch(text)) continue;
              if (_dataValues.contains(text)) continue;
              if (text.contains('\$')) continue;
              if (text.startsWith('http') || text.startsWith('gs://')) continue;
              if (text == 'Ratel Solutions') continue; // brand name
              _violations.add('${file.path}:${i + 1} → "$text"');
            }
          }
        }
      }
    });

    test('no hardcoded UI text (use l10n.translate)', () {
      if (_violations.isEmpty) return;
      fail(
        'Found ${_violations.length} hardcoded UI string(s).\n'
        'Use l10n.translate() with a localization key instead.\n\n'
        '${_violations.take(20).join('\n')}'
        '${_violations.length > 20 ? '\n... and ${_violations.length - 20} more' : ''}',
      );
    });
  });

  // ─── Dart code → JSON key coverage ───
  group('Dart code l10n.translate() key coverage', () {
    final _missingKeys = <String, List<String>>{}; // key → [files]

    setUpAll(() {
      _missingKeys.clear();
      final dirs = ['lib/screens', 'lib/widgets', 'lib/providers', 'lib/main.dart'];

      // Extract all l10n.translate('key') calls across the codebase
      final usedKeys = <String>{};
      final keyLocations = <String, List<String>>{};

      for (final dir in dirs) {
        if (dir.endsWith('.dart')) {
          _scanFile(File(dir), usedKeys, keyLocations);
        } else {
          final d = Directory(dir);
          if (!d.existsSync()) continue;
          for (final file in d.listSync(recursive: true)) {
            if (file is! File || !file.path.endsWith('.dart')) continue;
            _scanFile(file, usedKeys, keyLocations);
          }
        }
      }

      // Check each used key exists in all 3 language files
      for (final key in usedKeys) {
        final missing = <String>[];
        if (tr[key] == null) missing.add('TR');
        if (en[key] == null) missing.add('EN');
        if (nl[key] == null) missing.add('NL');
        if (missing.isNotEmpty) {
          _missingKeys[key] = [
            ...keyLocations[key] ?? ['unknown'],
            'Missing: ${missing.join(', ')}',
          ];
        }
      }
    });

    test('every l10n.translate() key exists in all 3 language files', () {
      if (_missingKeys.isEmpty) return;
      final report = StringBuffer();
      report.writeln('${_missingKeys.length} localization key(s) used in Dart code '
          'but missing from language files:\n');
      for (final entry in _missingKeys.entries) {
        report.writeln('  "${entry.key}"');
        for (final loc in entry.value) {
          report.writeln('    → $loc');
        }
      }
      report.writeln('\nAdd the missing key(s) to assets/lang/tr.json, en.json, nl.json');
      fail(report.toString());
    });
  });
}

/// Extracts {placeholder} names from a localization string.
Set<String> _placeholders(String value) {
  return RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet();
}

/// Scans a Dart file for l10n.translate('key') calls and records used keys.
void _scanFile(File file, Set<String> usedKeys, Map<String, List<String>> keyLocations) {
  final content = file.readAsStringSync();
  // Match: l10n.translate('key') or .translate('key')
  final regex = RegExp(r"(?:l10n\.)?translate\('([^']+)'\)");
  for (final match in regex.allMatches(content)) {
    final key = match.group(1)!;
    // Skip dynamic keys with interpolation: 'prefix_${variable}'
    if (key.contains('\$')) continue;
    usedKeys.add(key);
    keyLocations.putIfAbsent(key, () => []).add(file.path);
  }
}
