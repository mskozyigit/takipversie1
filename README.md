# Ratel Solutions FSM

Field Service Management web application. Flutter + Firebase + Riverpod.

**Live:** [https://mskozyigit.github.io/takipversie1/](https://mskozyigit.github.io/takipversie1/)

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Build & Deploy

```bash
# Web build (mobile-optimized)
flutter build web --release --base-href "/takipversie1/" --web-renderer auto

# Android APK
flutter build apk --release
```

CI deploys to **GitHub Pages** on push to `main` (`.github/workflows/deploy.yml`).

## Architecture

| Layer | Location | Pattern |
|-------|----------|---------|
| Models | `lib/models/` | Immutable classes, `fromFirestore(DocumentSnapshot)` |
| State | `lib/providers/` | Riverpod: `AsyncNotifier`, `StreamProvider.family` |
| Screens | `lib/screens/` | `ConsumerWidget` / `ConsumerStatefulWidget` |
| Widgets | `lib/widgets/` | Reusable checklist, calendar, image components |
| Theme | `lib/theme/app_theme.dart` | `ThemeExtension<AppThemeExt>` |
| Locale | `assets/lang/` | `tr.json`, `en.json`, `nl.json` |

## Platforms

| Platform | Status |
|----------|--------|
| **Web (PWA)** | ✅ Primary — Android Chrome/Samsung/Firefox |
| Android | ✅ APK |
| iOS | ✅ |
| Windows / Linux / macOS | ✅ Desktop |
