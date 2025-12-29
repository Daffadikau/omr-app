## Purpose
Short, actionable guidance for AI coding agents working on this repository (a Flutter multi-platform app).

## Big picture
- Multi-platform Flutter app (Android, iOS, macOS, Linux, Windows, Web). App code lives under [lib](lib).
- Entry point: [lib/main.dart](lib/main.dart#L1-L200) — note: this file currently contains small syntax/name errors (e.g. `Futere`, `Firebase.intializeApp`) so check and run the analyzer before large edits.
- Firebase integration: generated config in [lib/firebase_options.dart](lib/firebase_options.dart#L1-L200). Native config files exist under `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` / `macos/Runner/GoogleService-Info.plist`.

## Key files and conventions
- Main UI and app wiring: `lib/main.dart` and widgets inside `lib/`.
- Generated Firebase settings: `lib/firebase_options.dart` — produced by the FlutterFire CLI; re-run FlutterFire CLI to regenerate.
- Linting: `analysis_options.yaml` + `flutter_lints` in `pubspec.yaml` — follow those rules.
- Native build configs: `android/build.gradle.kts`, `android/app/build.gradle.kts`, and Xcode projects under `ios/` and `macos/`.

## Build / test / debug workflows
- Install deps: `flutter pub get`.
- Run on device/emulator: `flutter run -d <device>` (hot reload supported via `r` or IDE hot reload).
- Build artifacts:
  - Android APK/AAB: `flutter build apk` / `flutter build appbundle` (Gradle Kotlin scripts present).
  - iOS: open [ios/Runner.xcworkspace](ios/Runner.xcworkspace) in Xcode for signing, or `flutter build ios` on macOS.
  - macOS: `flutter build macos` (requires macOS host).
  - Web: `flutter build web`.
- Tests: `flutter test` (unit/widget tests live in `test/`).
- Static analysis: `flutter analyze` and `flutter format .` before commits.

## Integration notes / external dependencies
- Firebase: configuration is central — `lib/firebase_options.dart` is authoritative for runtime options; don't hard-code options elsewhere.
- Platform-specific credentials are present in `android/app/` and `ios/Runner/` — updating them may require corresponding native console updates.
- Generated plugin registration files exist per platform (iOS/macOS/Windows) — avoid editing generated files directly.

## Project-specific patterns agents should follow
- Prefer minimal, focused PRs. Keep changes scoped (fix one bug, add one feature).
- When modifying initialization logic (for example Firebase), ensure safe ordering: initialize plugins before `runApp`.
- Respect existing lint configuration (`analysis_options.yaml`). Run `flutter analyze` and fix reported issues.
- If you change Firebase setup, run the FlutterFire CLI to re-generate `lib/firebase_options.dart`.

## Common pitfalls discovered in repo
- `lib/main.dart` currently has obvious typos/compile errors; run `dart analyze` / `flutter analyze` immediately after edits.
- The project is configured for many platforms; building iOS or macOS requires macOS host and proper code-signing setup in Xcode.

## Example quick tasks
- Fix main initialization bugs: open [lib/main.dart](lib/main.dart#L1-L40), correct `Future<void> main() async {` and `Firebase.initializeApp(...)`, run `flutter analyze` and `flutter run`.
- Regenerate Firebase options: `dart pub global activate flutterfire_cli` then `flutterfire configure` (follow Firebase project prompts).

## When in doubt
- Run `flutter analyze` and `flutter test` — errors are usually specific and actionable.
- For native platform issues, open the platform project in its native IDE (Android Studio / Xcode) and inspect build logs.

If anything here is unclear or you want more detail for CI, review process, or testing setup, tell me which area to expand.
