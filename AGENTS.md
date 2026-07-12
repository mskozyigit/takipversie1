# AGENTS.md — Ratel Solutions FSM

Field Service Management app. Flutter + Firebase + Riverpod, multi-platform (Android, iOS, Web, Windows, Linux, macOS).

## Build & Test

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis (flutter_lints)
flutter test             # Run tests
flutter build web --release --base-href "/takipversie1/"  # Web deploy (gh-pages)
flutter build apk        # Android
```

CI deploys web to `gh-pages` on push to `main` (`.github/workflows/deploy.yml`).

## Architecture

| Layer | Location | Pattern |
|-------|----------|---------|
| Models | `lib/models/` | Immutable classes with `fromFirestore(DocumentSnapshot)` factory |
| State | `lib/providers/` | Riverpod: `AsyncNotifier`, `StreamProvider.family`, `Notifier` |
| Screens | `lib/screens/` | `ConsumerWidget` / `ConsumerStatefulWidget` |
| Widgets | `lib/widgets/` | Reusable components (calendar, checklist) |
| Theme | `lib/theme/app_theme.dart` | `ThemeExtension<AppThemeExt>` — single source for all colors |
| Locale | `assets/lang/` | `tr.json`, `en.json`, `nl.json` — accessed via `translationProvider` |

**Auth state machine** (`lib/providers/auth_provider.dart`): sealed class hierarchy — `Unauthenticated → NeedsOrg → PendingApproval → ApprovedAdmin|ApprovedWorker`. Google Sign-In uses popup on web, credential auth on mobile.

**Module system** (`lib/providers/module_provider.dart`): Feature flags via `moduleRegistryProvider`. Core modules always enabled; optional modules gated by org settings.

## Conventions (must follow)

### Theme & Colors
- **Never hardcode colors in screens.** Use:
  - `Theme.of(context).colorScheme` for Material colors (primary, secondary, surface, error)
  - `context.appExt` / `context.cs` for app-specific colors (see `lib/theme/app_theme.dart`)
  - `context.appExt.statusColor(job.status)` for job status colors — **the single source of truth**
- `CircularProgressIndicator` color: `Theme.of(context).colorScheme.secondary` for data loading; `Colors.white` only for button overlays.
- Scaffold `backgroundColor` is inherited from theme — do NOT set it per screen.

### Models
- Use `fromFirestore(DocumentSnapshot)` factory, not `fromJson`/`fromMap`.
- Parse enums from string fields with a private helper (e.g., `_parseApprovalStatus`).
- Provide a `copyWith` when needed for immutable updates.

### Providers
- Firestore streams: `StreamProvider.family<List<T>, Param>` — filter by `organizationId` from `authProvider`.
- Auth-gated: check `authState is ApprovedAdmin` (or `ApprovedWorker`) at the top of the provider; return empty stream if unauthorized.
- Platform checks: use `kIsWeb` for web-specific code paths (auth, Firestore settings).

### Platform-Specific
- Firestore offline persistence: enabled on non-web only (`!kIsWeb`).
- Google Sign-In initialization: skip `GoogleSignIn.instance.initialize()` on web (`kIsWeb`).

### Localization
- All user-facing strings via `ref.read(translationProvider.notifier).translate('key')`.
- Keys are snake_case and exist in all three JSON files (`tr.json`, `en.json`, `nl.json`).

## Firestore Structure

| Collection | Key fields | Access |
|-----------|------------|--------|
| `users` | `organizationId`, `role`, `approvalStatus` | Auth provider |
| `jobs` | `organizationId`, `assignedWorkerId`, `scheduledDate`, `status` | Admin: all org; Worker: own only |
| `customers` | `organizationId` | Admin only |
| `comments` | `jobId`, `organizationId` | Per-job stream |
| `auditLogs` | `jobId` | Per-job stream |

All queries are scoped by `organizationId`. Firestore indexes are defined in `firestore.indexes.json`.

## Key Files

- `lib/main.dart` — App entry, Firebase init, theme setup, `AuthGate` router
- `lib/providers/auth_provider.dart` — Auth state machine + Google Sign-In
- `lib/providers/job_provider.dart` — All job/comment/audit/customer streams + `JobNotifier`
- `lib/theme/app_theme.dart` — `AppThemeExt` + BuildContext extensions
- `lib/providers/module_provider.dart` — Feature module registry + branding + translation providers
- `firestore.rules` — Firestore security rules with founder admin bypass
- `firestore.indexes.json` — Required composite indexes

## Pitfalls

- **Flutter v3.44+**: `--web-renderer` flag may be unsupported; use `--no-wasm-dry-run` instead.
- **Google Sign-In v7.2+**: Requires explicit `GoogleSignIn.instance.initialize()` on mobile, and `signInWithPopup` on web.
- **Sign-out resilience**: Always set auth state to `Unauthenticated` immediately (before network calls) to reset the UI.
- When adding a new localization key, add it to **all three** language files (`tr.json`, `en.json`, `nl.json`).
- Firestore composite indexes must be created via `firestore.indexes.json` or Firebase CLI before queries with multiple `where` + `orderBy` clauses work.
