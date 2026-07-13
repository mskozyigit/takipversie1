# AGENTS.md — Ratel Solutions FSM

Field Service Management app. Flutter + Firebase + Riverpod, multi-platform (Android, iOS, Web, Windows, Linux, macOS).

## Build & Test

```bash
flutter pub get          # Install dependencies
flutter analyze --no-fatal-infos --no-fatal-warnings  # Static analysis (flutter_lints)
flutter test --no-pub    # Run tests (with graceful fallback if none)
flutter build web --release --base-href "/takipversie1/"  # Web deploy (gh-pages)
flutter build apk        # Android
```

CI (`.github/workflows/deploy.yml`) — two-stage pipeline on push to `main`:
1. **Validate**: checkout → Flutter 3.29.x → pub cache → `flutter pub get` → `flutter analyze` → `flutter test` → web asset validation (index.html, manifest.json, firebase-messaging-sw.js)
2. **Build & Deploy**: checkout → Flutter 3.29.x → pub cache → `flutter build web --release --base-href "/takipversie1/"` → deploy to `gh-pages` via `peaceiris/actions-gh-pages@v4`

Supports `workflow_dispatch` for manual trigger.

## Architecture

| Layer | Location | Pattern |
|-------|----------|---------|
| Models | `lib/models/` (7 files) | Immutable classes with `fromFirestore(DocumentSnapshot)` factory |
| State | `lib/providers/` (8 files + 2 platform stubs) | Riverpod: `AsyncNotifier`, `StreamProvider.family`, `Notifier`, `FutureProvider` |
| Screens | `lib/screens/` (13 files) | `ConsumerWidget` / `ConsumerStatefulWidget` |
| Widgets | `lib/widgets/` | Reusable components organized in subdirectories (`calendar/`, `checklist/`) + shared widgets |
| Theme | `lib/theme/app_theme.dart` | `ThemeExtension<AppThemeExt>` — single source for all colors |
| Locale | `assets/lang/` | `tr.json`, `en.json`, `nl.json` — accessed via `translationProvider` |

### Auth State Machine (`lib/providers/auth_provider.dart`)
Sealed class hierarchy: `Unauthenticated → NeedsOrg → PendingApproval → ApprovedAdmin|ApprovedWorker` (+ `AuthError`).
- Google Sign-In: popup (`signInWithPopup`) on web, credential auth (`GoogleSignIn.instance.authenticate()`) on mobile.
- Operations: `signInWithGoogle`, `createOrganization`, `joinOrganization`, `updateUserStatus`, `cancelJoinRequest`, `leaveOrganization`, `signOut`.
- Providers: `authProvider`, `pendingUsersProvider`, `currentOrganizationProvider`, `currentUserProvider`, `translationProvider`.

### Module System (`lib/providers/module_provider.dart`)
26 feature modules defined in `availableModules`. Core modules (14) always enabled; optional modules gated by `org.enabledModules` in Firestore. `moduleRegistryProvider` is cached with `keepAlive`. `ModuleNotifier` handles toggle via `moduleOperationsProvider`.

### Provider Inventory

| File | Providers / Notifiers |
|------|----------------------|
| `auth_provider.dart` | `authProvider`, `pendingUsersProvider`, `currentOrganizationProvider`, `currentUserProvider`, `translationProvider` |
| `job_provider.dart` | `auditLogProvider`, `commentsProvider`, `allJobsProvider`, `workerJobsProvider`, `organizationWorkersProvider`, `customersProvider`, `jobOperationsProvider`, `jobTemplatesProvider` |
| `module_provider.dart` | `moduleRegistryProvider`, `moduleOperationsProvider` |
| `analytics_provider.dart` | `analyticsProvider` (FutureProvider with 5-min TTL cache, 90-day window) |
| `media_provider.dart` | `mediaOperationsProvider` (image pick, compress, upload to Firebase Storage) |
| `notification_provider.dart` | `notificationProvider` (FCM token management, permission requests) |
| `browser_language_stub.dart` / `browser_language_web.dart` | Platform-conditional browser language detection |

## Conventions (must follow)

### Theme & Colors
- **Never hardcode colors in screens.** Use:
  - `Theme.of(context).colorScheme` for Material colors (primary: `#1565C0`, secondary: `#4FC3F7`, surface: `#1A2A3A`, error: redAccent)
  - `context.appExt` / `context.cs` for app-specific colors (see `lib/theme/app_theme.dart`)
  - `context.appExt.statusColor(job.status)` for job status colors — **the single source of truth**
- **Scaffold `backgroundColor`**: `Color(0xFF0D1B2A)` — inherited from theme, do NOT set per screen.
- **Card/surface colors**: Use `Theme.of(context).colorScheme.surface` (`#1A2A3A`). Never hardcode.
- **CircularProgressIndicator**: `Theme.of(context).colorScheme.secondary` for data loading; `Colors.white` only for button overlays.
- **FAB color**: `Color(0xFF1565C0)` (blue) consistently across all screens.
- **Status colors** (from `AppThemeExt.defaultDark`):
  - Not Started: `#9E9E9E` (Grey) | In Progress: `#FF9800` (Orange) | Work Completed: `#2196F3` (Blue) | Closed: `#4CAF50` (Green)

### UI Consistency
- **Border radius**: Standard is **12** for cards, input fields, chips, QR boxes.
- **Body padding**: `EdgeInsets.all(16)` on all screens.
- **AlertDialog dark theme**: Always set `backgroundColor: Theme.of(context).colorScheme.surface` and style TextFields with filled dark theme (`filled: true`, `fillColor`).
- **TimePicker theme**: Wrap with dark `ThemeData.dark()`.
- **Language selector**: `Icons.language` button with `tr`/`en`/`nl` values, bold+check for selected language. Identical pattern on both `calendar_home_screen.dart` and `admin_dashboard.dart`.
- **Full-screen images**: Use shared `FullScreenImageViewer.show(context, url)` — do NOT duplicate.
- **Network images**: Use `WebSafeImage` widget (thumbnail decoding at cacheWidth: 400, shimmer loading, error fallback).

### Models
- Use `fromFirestore(DocumentSnapshot)` factory, not `fromJson`/`fromMap`.
- Parse enums from string fields with a private helper (e.g., `_parseApprovalStatus`, `_parseStatus`).
- Provide a `copyWith` when needed for immutable updates.
- All models have `toFirestore()` for writes.

### Providers
- Firestore streams: `StreamProvider.family<List<T>, Param>` — filter by `organizationId` from `authProvider`.
- Auth-gated: check `authState is ApprovedAdmin` (or `ApprovedWorker`) at the top of the provider; return empty stream/value if unauthorized.
- Platform checks: use `kIsWeb` for web-specific code paths (auth, Firestore settings, image compression).
- Image compression: skipped on web (`kIsWeb`), uses `image` package with maxWidth 600, quality 65 on mobile.

### Platform-Specific
- Firestore offline persistence: enabled on non-web only (`!kIsWeb`).
- Google Sign-In initialization: skip `GoogleSignIn.instance.initialize()` on web (`kIsWeb`).
- FCM notifications: `requestPermission` params differ between web (explicit `alert/badge/sound`) and mobile (simple call).

### Localization
- All user-facing strings via `ref.read(translationProvider.notifier).translate('key')`.
- Keys are snake_case and exist in all three JSON files (`tr.json`, `en.json`, `nl.json`).
- `TranslationNotifier` caches JSON maps per language to avoid re-reading assets on `setLanguage()`.
- Default/fallback language is `nl` (Dutch).

## Firestore Structure

| Collection | Key fields | Access |
|-----------|------------|--------|
| `users` | `organizationId`, `role`, `approvalStatus`, `fcmToken`, `pushEnabled` | Auth provider |
| `jobs` | `organizationId`, `assignedWorkerId`, `scheduledDate`, `status`, `missionNumber`, `fee`, `customerId` | Admin: all org; Worker: own only |
| `organizations` | `joinCode`, `activeLanguage`, `paymentQrUrl`, `lastMissionNumber`, `enabledModules`, `useBranding`, `logoUrl`, `primaryColorHex` | Auth + module providers |
| `customers` | `organizationId`, `name`, `address`, `phone` | Admin only (CRM-01) |
| `comments` | `jobId`, `organizationId`, `authorId`, `text`, `timestamp` | Per-job stream |
| `auditLogs` | `jobId`, `organizationId`, `actorId`, `actionType`, `timestamp`, `metadata` | Per-job stream |
| `jobTemplates` | `organizationId`, `name`, field include flags + default values | Admin only (JOB-07) |
| `notifications` | `userId`, `jobId`, `organizationId`, `title`, `body`, `read`, `timestamp` | System (TEAM-02) |

All queries are scoped by `organizationId`. Firestore indexes are defined in `firestore.indexes.json`.
Storage paths: `{orgId}/jobs/{jobId}/{before|after}_{timestamp}.jpg`

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Firebase init, Google Sign-In init, offline persistence, MaterialApp with dark theme + `AuthGate` |
| `lib/providers/auth_provider.dart` | Auth state machine + Google Sign-In + org CRUD + translation provider |
| `lib/providers/job_provider.dart` | All job/comment/audit/customer/template streams + `JobNotifier` (create, update, delete, status, payment, notifications) |
| `lib/theme/app_theme.dart` | `AppThemeExt` + status colors + BuildContext extensions (`context.appExt`, `context.cs`) |
| `lib/providers/module_provider.dart` | 26-module registry + `ModuleNotifier` toggle |
| `lib/providers/analytics_provider.dart` | Admin analytics: per-worker stats, completion rates, fees, 5-min TTL cache |
| `lib/providers/media_provider.dart` | Image pick (camera/gallery) → compress → upload to Firebase Storage |
| `lib/providers/notification_provider.dart` | FCM push notifications: token registration, permission handling, foreground/background handlers |
| `lib/widgets/full_screen_image_viewer.dart` | Shared zoomable image viewer with download button |
| `lib/widgets/web_safe_image.dart` | Optimized `Image.network` with thumbnail decoding + shimmer loading |
| `firestore.rules` | Firestore security rules with founder admin bypass |
| `firestore.indexes.json` | Required composite indexes |
| `firebase.json` | Firebase hosting + emulator config |

## Pitfalls

- **Flutter v3.44+**: `--web-renderer` flag may be unsupported; use `--no-wasm-dry-run` instead.
- **Google Sign-In v7.2+**: Requires explicit `GoogleSignIn.instance.initialize()` on mobile, and `signInWithPopup` on web. Do NOT call `initialize()` on web — it throws `UnimplementedError`.
- **Sign-out resilience**: Always set auth state to `Unauthenticated` immediately (before network calls) to reset the UI.
- When adding a new localization key, add it to **all three** language files (`tr.json`, `en.json`, `nl.json`).
- Firestore composite indexes must be created via `firestore.indexes.json` or Firebase CLI before queries with multiple `where` + `orderBy` clauses work.
- **Image upload**: `uploadJobPhotoFromBytes` throws `ArgumentError` if `orgId` is empty or `"temp"` — ensure organization is loaded before calling.
- **Job mission numbers**: Auto-generated sequentially via Firestore transaction on `organizations/{orgId}.lastMissionNumber`. Custom mission numbers are validated for uniqueness; collision throws exception with next available number.
- **Analytics cache**: Module-level `_CacheEntry` is NOT provider-scoped — it persists across rebuilds for 5 minutes. If real-time data is needed, restart the app or wait for cache expiry.
- **Dead code removed** (do NOT recreate): `lib/widgets/calendar/job_card.dart`, `lib/widgets/calendar/view_toggle.dart`.
