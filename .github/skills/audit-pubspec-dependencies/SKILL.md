---
name: audit-pubspec-dependencies
description: 'Deep audit of pubspec.yaml dependencies for Flutter/Dart projects. Use when: checking for outdated packages, finding unused dependencies, reviewing version constraints, detecting transitive conflicts, verifying Firebase SDK alignment, auditing license compatibility, scanning for security advisories, pre-upgrade dependency review, cleaning up pubspec.yaml.'
argument-hint: 'Deep audit of pubspec.yaml with upgrade recommendations'
---

# Pubspec Dependency Audit

Performs a comprehensive audit of `pubspec.yaml` dependencies — version freshness, constraint quality, unused packages, transitive conflicts, Firebase SDK alignment, and upgrade safety. Produces a scored report with specific fix recommendations.

## When to Use

- **Routine maintenance**: "Check if my dependencies are up to date"
- **Pre-upgrade**: "What happens if I upgrade firebase_core to v5?"
- **Cleanup**: "Do I have unused packages bloating my build?"
- **Security check**: "Are any of my dependencies flagged with known vulnerabilities?"
- **CI gate**: "Does pubspec pass our dependency policy?"
- **Onboarding**: "Is this project's dependency setup following best practices?"

## Procedure

### Step 1: Gather Dependency Data

Run these commands and capture output:

```bash
# Outdated packages (direct + transitive)
flutter pub outdated --no-transitive-dependents

# Dependency tree (shows what depends on what)
flutter pub deps --style=tree

# List all direct dependencies with installed versions
flutter pub deps --style=compact --direct

# Check for dependency resolution issues
flutter pub get --dry-run
```

Also read `pubspec.lock` to get the full resolved version set and `pubspec.yaml` for constraint declarations.

### Step 2: Audit Categories

Run each of the checks below. See [audit_checks.md](./references/audit_checks.md) for detailed detection patterns per category.

#### A. Version Freshness

Compare declared constraints against latest published versions. Use `flutter pub outdated` output.

- **Major behind**: Package has a newer major version available (breaking changes likely)
- **Minor behind**: Same major, newer minor/patch (safe to upgrade usually)
- **Current**: On latest compatible version
- **Pre-release**: Pinned to a pre-release version (not recommended for production)

**Scoring**:
- 🟢 All packages within 1 minor of latest: +0
- 🟡 1-2 packages a major version behind: -5
- 🔴 3+ packages a major version behind, or any package 2+ majors behind: -15

#### B. Constraint Quality

Review how version constraints are declared:

| Pattern | Quality | Recommendation |
|---------|---------|---------------|
| `^X.Y.Z` | ✅ Good | Standard caret — allows compatible updates |
| `>=X.Y.Z <X+1.0.0` | ✅ Good | Explicit range — equivalent to caret |
| `>=X.Y.Z` | ⚠️ Loose | Accepts any future version, including breaking majors |
| `any` | 🔴 Bad | No constraint — any version accepted |
| `X.Y.Z` (exact) | ⚠️ Tight | Pinned exact — no updates, good for known-broken versions |
| No upper bound | ⚠️ Risky | May pull in incompatible major versions |

**For this project**: All constraints should use caret (`^`). Firebase packages should be kept within the same major family for compatibility.

#### C. Unused Dependencies

Cross-reference `pubspec.yaml` dependencies with actual imports in `lib/`:

1. For each direct dependency, search for `import 'package:<name>/` in `lib/**/*.dart`
2. Flag any dependency with zero imports
3. Check `dev_dependencies` against `test/**` imports

**Common false positives**:
- Packages used only in platform-specific code (e.g., `dart:html` stubs)
- Packages used only in generated code
- Firebase plugins — used via platform channels, not direct imports
- `flutter_test` — used by test framework, may not have explicit imports

#### D. Transitive Dependency Conflicts

Analyze the lockfile for version conflicts:

1. **Diamond dependency**: Two direct deps require incompatible versions of the same transitive dep
2. **Version overrides**: `dependency_overrides` in pubspec — flags a conflict that was manually resolved
3. **Duplicate packages**: Same package appearing at multiple versions (indicates a conflict)

Run: `flutter pub deps --style=tree` and look for packages listed under multiple version paths.

#### E. Firebase SDK Alignment

For projects using multiple Firebase packages, verify they're on compatible versions:

| Rule | Rationale |
|------|-----------|
| All `firebase_*` packages should share the same major version | Firebase native SDKs are tied — mismatched majors cause runtime crashes |
| `firebase_core` version ≥ all other Firebase packages | Core provides the native bridge; plugins depend on it |
| No mixed `firebase_*` from different major families | e.g., `firebase_auth: ^5.x` with `firebase_core: ^4.x` is incompatible |

Check the `_flutterfire_internals` transitive dependency version — all Firebase plugins should depend on the same internal version.

#### F. Dart SDK Constraint

Verify `environment.sdk` in pubspec:

- [ ] Constraint uses caret (`^3.6.0`) or range (`>=3.6.0 <4.0.0`)
- [ ] Matches the SDK version in CI (`.github/workflows/deploy.yml`: Flutter 3.29.x)
- [ ] Not overly restrictive (e.g., `>=3.6.0 <3.7.0` is too tight)
- [ ] Not overly loose (e.g., `>=2.12.0` allows ancient Dart versions)

#### G. Missing Recommended Dependencies

Based on the project's code and conventions, suggest dependencies that should be present:

| If codebase uses... | Should have dev dependency... |
|--------------------|------------------------------|
| Firestore | `fake_cloud_firestore` for unit testing |
| Riverpod | `flutter_riverpod` (already present); `riverpod_test` for test utilities |
| Firebase Auth | Mock auth setup or `firebase_auth_mocks` |
| Code generation | `build_runner`, `json_serializable` |
| Custom lint rules | Document in `analysis_options.yaml` |

### Step 3: Generate Scored Report

Produce a scored report. Start score at 100, apply deductions per category:

```markdown
## Pubspec Dependency Audit — takipversie1

**Date**: 2026-07-14 | **Score**: {score}/100

### Score Breakdown
| Category | Deduction | Reason |
|----------|-----------|--------|
| Version Freshness | -{n} | {m} packages behind latest |
| Constraint Quality | -{n} | {issues} |
| Unused Dependencies | -{n} | {count} unused packages |
| Transitive Conflicts | -{n} | {conflicts} |
| Firebase Alignment | 0 | All Firebase packages aligned |
| Dart SDK | 0 | Constraint is correct |
| Missing Recs | -{n} | Missing {packages} |

### 🔴 Critical (score impact: -15 each)
- **Firebase version mismatch**: `firebase_auth ^6.5.4` requires `firebase_core ^4.x`. Confirm compatibility.
- ...

### 🟡 Warnings (score impact: -5 each)
- **Package X is 2 majors behind**: current ^A.B, latest ^C.D. Breaking changes: [link to changelog]
- ...

### 🔵 Suggestions (no score impact)
- Consider adding `fake_cloud_firestore` to dev_dependencies for unit testing
- ...

### Upgrade Path
1. **Safe (no breaking changes)**: Run `flutter pub upgrade` — updates within caret ranges
2. **Minor risks**: Run `flutter pub upgrade <package>` one at a time, test after each
3. **Major risks**: Read changelog, update code for breaking API changes, then upgrade

### Recommended Command
```bash
# Safe upgrades first
flutter pub upgrade

# Then review major upgrades one at a time
flutter pub outdated
```

**Verdict**: {✅ Healthy / ⚠️ Needs attention / 🔴 Critical issues}
```

### Step 4: Propose Specific Fixes

For each finding that needs action, propose the exact `pubspec.yaml` change:

```yaml
# Before
firebase_core: ^4.11.0

# After — verified compatible with firebase_auth ^6.x
firebase_core: ^5.0.0
```

Group fixes into:
1. **Apply now** — safe, non-breaking
2. **Review then apply** — needs changelog review
3. **Defer** — major refactor required, file an issue

## Common Pitfalls

- **`flutter pub outdated` shows transitive packages**: By default it includes transitive deps. Use `--no-transitive-dependents` to focus on direct deps. Transitive updates are managed by direct dep upgrades.
- **Caret `^` allows minor/patch only** (pre-1.0.0): For packages <1.0.0, `^0.X.Y` allows `>=0.X.Y <0.(X+1).0`. This is more restrictive than post-1.0 caret.
- **Firebase native SDK ties**: Upgrading `firebase_core` may require updating `google-services.json`, `GoogleService-Info.plist`, and native build files. A pure Dart upgrade may not be sufficient.
- **`dependency_overrides` is a temporary fix**: It's meant for local development resolution. Overrides in committed `pubspec.yaml` indicate an unresolved conflict that should be fixed properly.
- **Lockfile not committed?**: `pubspec.lock` should be committed for applications (not packages) to ensure reproducible builds. Verify it's tracked in git.
