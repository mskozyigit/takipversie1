# Audit Checks — Detailed Detection Patterns

Step-by-step instructions for each audit category. Run these against the project's `pubspec.yaml` and `pubspec.lock`.

---

## A. Version Freshness

### A1. Run outdated check

```bash
flutter pub outdated --no-transitive-dependents
```

Parse the output table:

| Column | Meaning |
|--------|---------|
| Current | Version resolved in `pubspec.lock` |
| Upgradable | Latest version within your constraint |
| Resolvable | Latest version that resolves with all other constraints |
| Latest | Absolute latest published version |

### A2. Classify each package

```
For each direct dependency:
  if Latest.major > Current.major AND Latest.major - Current.major >= 2:
    → 🔴 Critical staleness (2+ majors behind)
  elif Latest.major > Current.major:
    → 🟡 Behind by 1 major (breaking changes likely)
  elif Upgradable.major > Current.major or Upgradable.minor > Current.minor:
    → 🔵 Minor/patch update available (safe)
  else:
    → ✅ Current
```

### A3. Special cases

- **Pre-1.0 packages** (0.x.y): Every minor bump may be breaking. Treat `0.X → 0.(X+1)` as equivalent to a major bump.
- **Flutter SDK packages** (`flutter`, `flutter_test`): Tied to Flutter SDK version. Compare against Flutter SDK constraint.
- **Prerelease suffixes** (`-dev`, `-beta`, `-alpha`): Flag with ⚠️. Prereleases should not be used in production without explicit pinning.

---

## B. Constraint Quality

### B1. Scan version constraints in pubspec.yaml

Extract all version strings from `dependencies:` and `dev_dependencies:`.

```regex
(\w+):\s*[\^]?([\d.]+(?:\+[\w.-]+)?)
```

### B2. Classify each constraint

| Constraint Pattern | Classification | Deduction |
|--------------------|---------------|-----------|
| `^X.Y.Z` | ✅ Ideal | 0 |
| `>=X.Y.Z <(X+1).0.0` | ✅ Equivalent to caret | 0 |
| `>=X.Y.Z <X.(Y+1).0` | ✅ Tight range (acceptable for pre-1.0) | 0 |
| `>=X.Y.Z` (no upper bound) | ⚠️ Unbounded | -3 per occurrence |
| `any` | 🔴 No constraint | -5 per occurrence |
| `X.Y.Z` (bare version) | ⚠️ Pinned exact | -2 per occurrence |
| `>=X.Y.Z <A.B.C` where A > X+1 | ⚠️ Overly wide range | -2 per occurrence |

### B3. Constraint consistency check

- All dependencies should use the same constraint style (caret preferred)
- Mixed styles (some `^`, some `>=`) is a 🟡 warning — standardize

### B4. Upper bound policy

For libraries/packages that are published to pub.dev, upper bounds are recommended. For applications (this project — `publish_to: 'none'`), caret constraints without explicit upper bounds are acceptable since the lockfile pins exact versions.

---

## C. Unused Dependencies

### C1. Collect imports

```bash
# Get all unique package imports from lib/
grep -roh "import 'package:[^']*" lib/ | sed "s/import 'package://" | cut -d'/' -f1 | sort -u

# Get all unique package imports from test/
grep -roh "import 'package:[^']*" test/ | sed "s/import 'package://" | cut -d'/' -f1 | sort -u
```

### C2. Compare against direct dependencies

| Dependency | Found in lib/ | Found in test/ | Status |
|-----------|--------------|----------------|--------|
| firebase_core | ✅ Yes | — | Used |
| cupertino_icons | ❌ No | — | 🟡 Possibly unused |

### C3. Known false positives (do NOT flag)

- `flutter_test` in dev_dependencies — used by test framework, may not have explicit imports
- `flutter_lints` in dev_dependencies — referenced by `analysis_options.yaml`, not Dart imports
- `flutter` SDK — implicit, not imported as a package
- Firebase plugins — may be initialized via platform channels without direct Dart imports in some files (but `firebase_core` is typically imported in `main.dart`)

### C4. Missing dependency detection

Search for imports of packages NOT listed in pubspec:

```bash
# Find imports referencing packages not in pubspec.yaml
for pkg in $(grep -roh "import 'package:[^/]*" lib/ test/ | sed "s/import 'package://" | sort -u); do
  if ! grep -q "$pkg" pubspec.yaml; then
    echo "🔴 Missing: $pkg"
  fi
done
```

This catches cases where a transitive dependency is imported directly — it should be added as a direct dependency.

---

## D. Transitive Conflicts

### D1. Check for version overrides

```bash
grep -A 5 "dependency_overrides" pubspec.yaml
```

If `dependency_overrides` exists in the committed `pubspec.yaml`:
- 🔴 Each override represents an unresolved conflict
- Document why each override is needed and link to the issue tracking its resolution

### D2. Check for diamond dependencies

Run `flutter pub deps --style=tree` and look for packages that appear at multiple versions in the tree. A package appearing at both `v1.0.0` and `v2.0.0` indicates a diamond dependency conflict.

Common conflicting packages in Flutter:
- `collection` (often constrained by multiple packages)
- `meta` (Flutter framework vs third-party packages)
- `plugin_platform_interface` (multiple Firebase plugins)

### D3. Check pubspec.lock for duplicate entries

```bash
grep -E "^  [a-z_]+:" pubspec.lock | sort | uniq -d
```

A package appearing twice in the lockfile with different versions indicates `dependency_overrides` or a resolution conflict.

---

## E. Firebase SDK Alignment

### E1. Check Firebase package versions

Extract all `firebase_*` packages from pubspec.yaml:

```bash
grep "firebase_" pubspec.yaml
```

### E2. Verify major version alignment

All Firebase packages should share the same major version family. For example:

| Package | Version | Major Family |
|---------|---------|-------------|
| firebase_core | ^4.11.0 | 4.x |
| firebase_auth | ^6.5.4 | 6.x |
| cloud_firestore | ^6.6.0 | 6.x |
| firebase_storage | ^13.0.0 | 13.x |
| firebase_messaging | ^16.0.0 | 16.x |

🔴 **This project has mixed Firebase major versions**: `firebase_core ^4.x` but `firebase_auth ^6.x`, `cloud_firestore ^6.x`, `firebase_storage ^13.x`, `firebase_messaging ^16.x`. This is a known pattern — Firebase plugins diverge in major versions. However, check that all plugins are compatible with the installed `firebase_core` version.

### E3. Check `_flutterfire_internals` alignment

```bash
grep -A 3 "_flutterfire_internals" pubspec.lock
```

All Firebase plugins depend on `_flutterfire_internals`. Verify the resolved version is the same for all plugins.

### E4. Firebase BoM (Bill of Materials)

Firebase recommends using the Firebase BoM on native platforms. For Flutter, each plugin declares its own native SDK dependency. If plugins declare incompatible native SDK versions, the build may fail at the native level (not visible in Dart dry-run).

- 🔵 Suggestion: After Flutter pub upgrades, run native builds (`flutter build apk --debug`, `flutter build ios --debug --no-codesign`) to verify native Firebase SDK compatibility.

---

## F. Dart SDK Constraint

### F1. Read current constraint

```bash
grep -A 1 "sdk:" pubspec.yaml | grep ">="
```

### F2. Compare against Flutter SDK

Check the Flutter version in CI (`.github/workflows/deploy.yml`): `Flutter 3.29.x`.

Look up which Dart SDK version Flutter 3.29.x bundles (typically Dart 3.7.x).

### F3. Constraint quality check

| Check | Pass Condition |
|-------|---------------|
| Constraint present | `sdk: >=X.Y.Z <A.B.C` or `sdk: ^X.Y.Z` |
| Upper bound reasonable | `<4.0.0` is standard (Dart 4 is the next theoretical major) |
| Lower bound ≤ CI Dart version | If CI uses Dart 3.7.x, `>=3.6.0` is acceptable |
| Not pinned to exact version | `sdk: 3.7.0` is too restrictive |

For this project: `sdk: ^3.6.0` → expands to `>=3.6.0 <4.0.0`. This is a good constraint.

---

## G. Security & License Audit

### G1. Known vulnerabilities

Check direct dependencies against the OSV (Open Source Vulnerabilities) database. While there's no automated CLI tool bundled with Dart, check:

- GitHub Advisory Database for each dependency
- Pub.dev security tab (if available for the package)
- `dart pub audit` (if available in the installed Dart version)

### G2. License compatibility

Extract licenses from `pubspec.lock`:

```bash
# Each package entry may not include license — check pub.dev
grep -E "^\s+\w+:" pubspec.lock | head -30
```

For production applications, verify:
- No GPL-licensed packages (copyleft may not be compatible with proprietary apps)
- MIT, BSD, Apache-2.0 are generally safe
- Unlicensed packages are 🔴 critical — no license means no permission to use

---

## H. Dependency Count & Build Size

### H1. Count dependencies

```bash
# Direct dependencies
grep -c "^  [a-z]" pubspec.yaml  # Approximate

# Transitive dependencies (from lockfile)
grep -c "^  [a-z_]*:" pubspec.lock  # All packages
```

### H2. Heavy dependencies

Flag packages known to increase binary size significantly:
- `firebase_*` packages (~10-20MB each on native)
- `image` (image processing, moderate)
- `url_launcher` (small)
- `table_calendar` (moderate)

🔵 Suggestion: If binary size is a concern, consider deferred loading for non-critical features (not currently supported for all platforms).
