# C15 native platform handoff

## Status

PARTIAL: native implementation ready for main integration. Native Gradle compile,
unit tests and Dart bridge tests pass. Full app gates/physical QA remain with main.

## Lot

C15 - Private wallet native platform portion only, 2026-09-13.

## Git

- Branch, HEAD and base: not queried; user explicitly prohibited Git operations.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa/temp/VIAJE-R1-real-planner`.
- Git status: not queried. Existing WIP was preserved; no commit/push/merge.

## Outcome

- `WalletPlatform` uses `co.picoradar.app/wallet`. No Dart PDF plugin.
- `WalletCaptureFile({required File file, required String originalName,
  required String mimeType})`; `path` is a convenience getter.
- `scan({int maxPages = 2})`: nullable list; cancellation is null, not unsupported.
- `deleteScanTemps(List<String> paths)`: validates the entire list first; accepts
  only `no_backup/wallet_capture/scan-<UUID>.jpg`, never imported or encrypted files.
- `setSecure(bool enabled)`: sets/clears the host window flag without UI decisions.
- `noBackupDirectory()`: absolute no-backup root as String.
- `openPdf(String path)`: `WalletPdfDocument(id, pageCount)`.
- `renderPdfPage(String id, int page, int width)`: Uint8List PNG, zero-based page.
- `closePdf(String id)`: releases the session and cancels an outstanding render.
- `WalletPlatformException.code` carries sanitized native errors. Unsupported
  OS/missing native plugin/scanner unavailable use `unsupported`.
- ML Kit 16.0.0, BASE, gallery enabled, JPEG only, 1-2 scanner pages. Existing PDFs
  have NO page-count cap; rendering checks against the actual document page count.
- PDF OPEN visits every page with openPage/use before returning a session. It
  checks positive dimensions, stable page count/index and bounded-raster metadata;
  invalid later pages reject the whole OPEN and close the renderer. No raster is
  allocated during this validation. Content-stream rendering can still fail later.
- Single PDF session, one operation at a time (`busy` otherwise), 25 MiB inputs,
  width 1-2048, height <=4096, <=4,194,304 pixels, <=20 MiB PNG. Path must be
  app-private. No URLs, external viewers, network calls or per-page plugins.
- PDF bytes are copied into an already-unlinked temporary file. The isolated,
  unexported service receives a read-only seekable FD and one output FD; no paths
  or arbitrary file access. Pages, bitmaps and descriptors close after use.
- Twenty-second IPC timeout/service death fails closed; unbinding destroys the
  dedicated isolated process, including a renderer stuck in native parsing.
- MainActivity.onStop invalidates all PDF sessions and tears down the renderer.
  The isolated UID has no app INTERNET/storage permissions. A resumed viewer must
  reauthorize and reopen; main's secure-window reference count is unchanged.

## Main integration obligations

- Main owns pubspec/local_auth 3.0.2, session, encryption, UI and secure refcounts.
- Await secure=true before showing ANY Dart viewer/preview, and for a protected
  wallet while unlocked. Clear only when all sensitive scopes have hidden content.
- FLAG_SECURE applies to the Flutter host window, not a guarantee about the
  SDK-controlled scanner's own scan/edit activity. Check scanner UI physically.
- Scanner results are transient plaintext in app-private no-backup storage.
  Main MUST immediately encrypt pending captures before Dart preview, even when
  auth was revoked during the scan. Call deleteScanTemps in finally; pending
  encrypted content must not depend on the old UI authorization remaining valid.
- Main owns deletion of the original decrypted PDF input path, displayed PNG
  bytes/image cache, and any legacy viewer-cache cleanup on revocation/disposal.
- Main must close a PDF returned after its route/session became stale. Do not
  render multiple pages concurrently. Reopen after native transport/session failure.

## Files / areas changed

- `mobile/android/app/build.gradle.kts`: scanner and JUnit dependency.
- `mobile/android/app/src/main/AndroidManifest.xml`: biometric permission, backup
  rules and isolated PDF service.
- `mobile/android/app/src/main/kotlin/co/picoradar/app/MainActivity.kt`:
  FlutterFragmentActivity, wallet lifecycle/result forwarding. Existing startup,
  TTS/driving, widget updates and picoIntent logic preserved.
- New `wallet/WalletBridge.kt`, `WalletLimits.kt`, `DocumentPdfClient.kt`,
  `DocumentPdfService.kt` under the same Kotlin package root.
- AppCompat parent themes in values, values-night and both v31 variants.
- `res/xml/wallet_backup_rules.xml`, `wallet_data_extraction_rules.xml`.
- New `mobile/lib/features/documents/platform/wallet_platform.dart` only in lib.
- Android bridge_tests scripts/Dart tests and WalletLimitsTest.kt.

## Tests executed

Commands relative to `mobile/android` unless specified:

| Command / test | Result |
|---|---|
| `./bridge_tests/run_native_unit_tests.ps1` | PASS, initial 5 JUnit tests; also compiles PDF client/service with Kotlin 2.4.0 + local Android jar, no Gradle |
| `./bridge_tests/verify_backup_rules.ps1` | PASS, 60 path/scope checks plus isolated-service/biometric manifest checks |
| Direct bundled `dart.exe format` on new lib file and bridge Dart test | PASS |
| `./gradlew.bat :app:compileDevDebugKotlin :app:testDevDebugUnitTest -x :app:compileFlutterBuildDevDebug --console=plain` | PASS, scanner/MainActivity/PDF and initial 5 unit tests; Flutter compilation excluded, no APK |
| Same Gradle command with `--quiet`, after SDK cleanup/background teardown | PASS, 6 tests, 0 skipped/failures/errors in JUnit XML |
| Same Gradle command with `--quiet`, after all-page OPEN metadata validation | PASS, 9 tests, 0 skipped/failures/errors; covers 350 pages, invalid later-page metadata/open failure and bounded-raster dimensions; Flutter compilation excluded |
| `flutter test --no-pub android/bridge_tests/wallet_platform_test.dart` from mobile | PASS, 9 tests, including legacy 350-page PDF contract |
| Direct bundled `dart.exe analyze lib/features/documents/platform/wallet_platform.dart android/bridge_tests/wallet_platform_test.dart` from mobile | PASS, no issues |
| Direct bundled `dart.exe format --output=none --set-exit-if-changed` on those two files | PASS, 0 changes |
| Merged devDebug manifest inspection | PASS, isolated/unexported document_pdf service and allowBackup=false retained |
| `flutter analyze`, full tests, dev Android build | Main owns final gates |

The standalone compiler setup initially lacked kotlin-reflect, then referenced
android-37 instead of the installed android-37.0 folder. Both were corrected in
the reproducible script before the passing run. These were harness setup errors.
Four initial Dart style notices were corrected before the final clean analysis
and 9-test rerun. Native Gradle emitted existing AGP/plugin deprecations and the
preserved TTS Locale constructor warning; no compilation errors. No APK built.

## Manual and physical Android QA

REQUIRED, not performed here. No device evidence is claimed.

- Camera/gallery/cancel; inspect returned source URIs and residual SDK cache.
- Biometric allow/deny, screen lock, scanner background/return, process death,
  restart, stale-result encrypted staging and deletion of returned plaintext.
- Dart viewer/preview and protected-wallet screenshots/recents; secure flag clears
  only after main releases all scopes. Check Android <=8 theme behavior.
- Legacy multi-page PDF including pages >100; malformed/password PDF; oversized
  image page; cancellation and renderer death; no external app launched.
- TTS/driving and widget regression smoke after FragmentActivity change.
- Backup/transfer on physical supported Android; XML checks alone are not proof
  of an OEM's transfer behavior. No personal phone data was touched here.

## Data / backup assumptions

- Existing PrivateVehicleDocumentStore uses getApplicationSupportDirectory:
  Android `files/vehicle_documents`. Explicit alternate legacy exclusions include
  `app_flutter/vehicle_documents`, `documents`, `app_flutter/documents`, and
  `flutter_secure_storage` under files and app_flutter.
- Drift 0.3.1 default `driftDatabase(name: 'picoradar')` uses
  `app_flutter/picoradar.sqlite`. The DB and -wal/-shm/-journal sidecars are
  explicitly excluded there and under files; the entire database domain is also
  excluded to cover native/default database locations.
- All sharedpref files are excluded, covering FlutterSecureStorage.xml,
  FlutterSecureKeyStorage.xml, secure-storage config/namespaced variations,
  FlutterSharedPreferences.xml, wallet protection state and widget plate data.
- SharedPreferencesAsync's DataStore files/datastore directory is excluded;
  device-protected preferences/databases/DataStore are covered as well.
- The same exclusions apply to pre-31 backup, Android 31+ cloud and device transfer.
  allowBackup=false additionally disables app cloud backup. cache/no_backup are
  platform-excluded. No existing encrypted document or database was migrated/deleted.
- Scanner outputs are accepted only as file URIs canonically within the app cache;
  specifically `mlkit_docscan_ui_client/<elapsedRealtimeNanos>.jpg`. This layout
  was verified in the downloaded 16.0.0 ResultHelper bytecode (`zzh.zzd`).
  Both returned and partial SDK JPEGs are removed after copy/cancel/invalid result
  and on startup. Different URI forms fail closed. Unrelated cache contents are
  never blindly erased. Google Play Services' own process cleanup and dynamic
  scanner UI still require physical verification.
- Previously abandoned bridge-owned scan files are removed once per process;
  activity recreation does not erase files already handed to a live Dart workflow.

## Dependencies

- Approved native ML Kit Document Scanner 16.0.0: required baseline scanner UI,
  crop/rotation/gallery; Android camera intents alone do not supply that flow.
  Android only; future iOS implementation stays behind the Dart contract. Google
  maintains the Play Services SDK under its SDK terms. Devices without the module
  or supported Play Services fail explicitly; first-use module availability needs QA.
- JUnit 4.13.2 is test-only (EPL-1.0); verifies ownership/limits without Android UI.
  Existing Flutter tests cannot execute these native boundary functions.
- AppCompat/Fragment/biometric infrastructure is supplied transitively by the
  main-owned local_auth Android plugin; no extra runtime framework was introduced.
- Official references: https://developers.google.com/ml-kit/vision/doc-scanner/android
  and https://developer.android.com/reference/android/graphics/pdf/PdfRenderer .

## Known risks / debt and next step

Physical QA and main's full app gates remain open. Native-only work does not close
C15 or certify encrypt-before-preview
until main's workflow and device evidence pass. Next unlocked work is main's C15
viewer/workflow integration and serialized Android validation. No new lot is closed.
