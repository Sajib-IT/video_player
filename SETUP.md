# CineVault Player — Platform & API Setup Notes

## 1. Playback Engine (`media_kit`)
- `MediaKit.ensureInitialized()` is invoked in `lib/main.dart` before `runApp`.
- Native `libmpv` + `FFmpeg` binaries are bundled automatically via `media_kit_libs_video`.
- **ASS/SSA Styling (`libass`):** `assets/fonts/roboto-regular.ttf` is bundled and registered in `pubspec.yaml` so Android `libass` has a fallback font when MKV attachments omit fonts.

## 2. Android Setup (`android/`)
- `android/app/build.gradle.kts` enforces `minSdk = maxOf(21, flutter.minSdkVersion)`.
- `android/app/src/main/AndroidManifest.xml` declares:
  - `INTERNET` for online subtitle search/download and network streams.
  - `READ_MEDIA_VIDEO` & `READ_MEDIA_AUDIO` for Android 13+ (API 33+).
  - `READ_EXTERNAL_STORAGE` (`maxSdkVersion="32"`) & `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="29"`) for legacy Android.
- **Release APKs:** Build with `--split-per-abi` or App Bundle (`flutter build appbundle`) to keep native `libmpv` ABI sizes compact.

## 3. iOS Setup (`ios/Runner/Info.plist`)
- `NSPhotoLibraryUsageDescription` and `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` are configured for local video library access via `photo_manager`.
- `LSSupportsOpeningDocumentsInPlace` and `UIFileSharingEnabled` allow picking local `.srt`/`.ass`/`.ssa`/`.vtt`/`.sub` files from the Files app.
- `NSAppTransportSecurity` -> `NSAllowsArbitraryLoads = true` enables HTTP media streams alongside HTTPS.

## 4. OpenSubtitles REST API v1 Configuration
- Pass your API key at build/run time:
  ```bash
  flutter run --dart-define=OPENSUBTITLES_API_KEY=your_api_key_here
  ```
- Or configure/override the API key at runtime in app settings (persisted in SQLite `playback_settings.opensubtitles_api_key`).
