# Optional Android alarms: coordinator integration

Scope: approved `docs/ADR_ALERTS_ANDROID.md`, C11 native implementation only.
No MainActivity, manifest, Gradle, Dart, or database edits are owned by this change.

## MainActivity

In `mobile/android/app/src/main/kotlin/co/picoradar/app/MainActivity.kt`:

```kotlin
import co.picoradar.app.alerts.AlertsBridge

// Member of MainActivity:
private var alertsBridge: AlertsBridge? = null

// configureFlutterEngine, after super.configureFlutterEngine(flutterEngine):
alertsBridge?.dispose()
alertsBridge = AlertsBridge(this, flutterEngine.dartExecutor.binaryMessenger)

// onDestroy, before super.onDestroy():
alertsBridge?.dispose()
alertsBridge = null
```

No activity-result or notification-permission forwarding is needed for AlertsBridge.
Requery capabilities when returning from system settings. The existing explicit
`picoradar:///...` MainActivity deep-link handling remains the route integration.

## Manifest

Add only missing permissions at manifest root (POST_NOTIFICATIONS and
RECEIVE_BOOT_COMPLETED already exist). Do not add USE_EXACT_ALARM.

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Inside application, in the default app process, credential-protected (not directBootAware):

```xml
<receiver android:name=".alerts.AlertReceiver" android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.TIME_SET" />
        <action android:name="android.intent.action.TIMEZONE_CHANGED" />
        <action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" />
    </intent-filter>
</receiver>
<service android:name=".alerts.AlertRingingService"
    android:exported="false"
    android:foregroundServiceType="mediaPlayback" />
<activity android:name=".alerts.AlertActivity"
    android:exported="false"
    android:excludeFromRecents="true"
    android:launchMode="singleTop"
    android:taskAffinity=""
    android:theme="@android:style/Theme.Material.Light.NoActionBar" />
```

Do not put unconditional showWhenLocked/turnScreenOn on the activity: native code
enables those only for an active generic alarm with approved full-screen access.
The receiver only restores future alarms on reboot; it never starts mediaPlayback
from BOOT_COMPLETED. OS/store eligibility is still a physical/release gate.

## Gradle

No edits or dependencies required. Existing Kotlin, Android SDK, Flutter embedding
and `testImplementation("junit:junit:4.13.2")` suffice. Do not change SDK targets.

## MethodChannel

Channel: `co.picoradar.app/alerts`; constructor and dispose match the requested contract.

| Method | Arguments | Result |
| --- | --- | --- |
| capabilities | none | supported, notifications, exact, fullScreen booleans |
| requestPermissions | none | current capabilities; opens exact access first, retry requests notification permission/settings |
| requestFullScreen | none | current capabilities; opens full-screen access only on this explicit call |
| openNotificationSettings | none | null; opens app notification settings (app details on API 24-25) |
| reschedule | scope, events | installed future IDs plus retained matching ringing/snoozed/due IDs; unmatched recent past and MISSED may be absent |
| cancel | scope | null; affects that scope only, including ringing state |
| pending | none | future confirmed and current ringing/due IDs, excluding MISSED/test; throws typed error on revoked access/unobserved failure |
| test | none | null after foreground start requested; explicit fictional test only |
| status | none | testState and nullable failureCode; explicit observation consumes the failure latch |

Corresponding coordinator-owned Dart methods:

```dart
Future<void> requestFullScreen() => channel.invokeMethod<void>('requestFullScreen');
Future<void> openNotificationSettings() =>
    channel.invokeMethod<void>('openNotificationSettings');
```

`canSchedule` = supported && notifications && exact. Full-screen access is optional,
reported independently, and never requested or assumed automatically. Missing
notification/exact access fails with a typed code; no inexact or ordinary-notification
fallback. Native notification text and its public version are always generic.
Normal rich plugin notifications remain coordinator-owned; hide plate content
entirely on lockscreen when that plugin cannot supply a generic public version.

Events: `{id: int, at: UTC milliseconds, expiresAt: UTC milliseconds, route: String}`.
Scope is exactly `pico` or `obligations`; IDs must be positive 32-bit, unique across
both scopes, unchanged from coordinator IDs. Test uses reserved -1 in its own extra
slot. Maximum 128 projected normal events across both scopes, not 128 per scope.
Past events are not scheduled; duplicate/colliding IDs
reject before mutation. ExpiresAt is exclusive; snooze must remain within it.

### Reconciliation identity

Ordinary reconciliation MUST NOT call cancel first. Send all still-valid,
alarm-enabled identities, including original targets with an unexpired eligibility
window of at most 15 minutes. Native bounds expiresAt - at to 1..900000 ms.
Only an existing record matching id + originalAt + expiresAt + canonical owner route
can retain RINGING, SNOOZED or MISSED. The persisted originalAt does not change on
snooze; at becomes now + 10 minutes, strictly before the original expiresAt.
An already scheduled due callback within the existing 120-second grace keeps its
token. An unmatched past input (including newly enabled alarm mode) never installs
or rings. Missing/changed identities are canceled. Explicit cancel(scope) remains
destructive; disable/delete/date/time/owner edits must remove/change that identity.

The accepted result includes future installs and retained ringing/snoozed/due IDs;
MISSED is retained silently but absent from accepted/pending. Dart requires all
future IDs, permits absent recent-past IDs, and rejects foreign IDs. Two independent
scope updates are serialized but are not a cross-scope transaction: an increase
submitted before another scope's decrease can explicitly hit TOO_MANY_EVENTS.
Preflight preserves both scopes; no silent truncation or future-only workaround.

### Test status and failure observation

status has no arguments and returns exactly:
`{testState: idle|starting|ringing|snoozed|missed|stopped|failed, failureCode: String?}`.
test acknowledgement means requested, never successful playback. starting becomes
ringing only after MediaPlayer.start succeeds. Async playback errors set failed.
The first unobserved sanitized failure survives successful reschedule/cancel/test,
pending queries and process recreation. Only a successful explicit status call
clears it. A status persistence error does not acknowledge the original failure.
Test state is process-local; persisted failure still reports an interrupted test
after restart. Failure codes are allowlisted in AlertEngine; unknown input maps to
ALARM_OPERATION_FAILED. Do not display raw native details. Permission codes are
NOTIFICATIONS_REQUIRED, EXACT_ACCESS_REQUIRED, ACCESS_REVOKED and
PERMISSION_CHECK_FAILED. Audio codes include AUDIO_FOCUS_DENIED, AUDIO_FOCUS_LOST,
PLAYBACK_FAILED, RING_FAILED and TONE_UNAVAILABLE; remaining failures are generic.

Goodall owns gateway/UI observation: bounded polling after an explicit test, no
success from the initial acknowledgement, cancel observation on background/dispose;
the alert center observes before sync so a later retry can proceed. Parfit owns
the approved full-identity planner/provider/scheduler changes. Native pending IDs
alone cannot preserve a snooze after a destructive Dart cancel.

### Missed alarms and visible activity

Cutoff and observed OS interruption release playback, focus and wake resources,
remove the foreground notification, and persist a non-ringable MISSED phase. They
post a separate tagged, generic, silent low-importance notice: no full-screen,
sound, vibration or snooze action. Group alert suppression also silences a
customized channel. Explicit Stop/Snooze/cancel never posts a missed notice.
Stale generation callbacks cannot stop the next alarm or overwrite its failure.
Opening a missed notice requires unlock and revalidates owner/expiry. Dismissal
removes the projection; expiry pruning or explicit reconciliation can remove the
notice. The notice itself is generic and may outlive the private route's expiry.

An open AlertActivity refreshes at resume and every 500 ms only while resumed.
It rerenders only a changed event/phase, removes Stop/Snooze and above-lock flags
on MISSED, and closes for deleted/expired identities. Permission changes update
above-lock flags without repeated rendering or keyguard requests. Pause/destroy
remove polling callbacks. Validate this transition physically at the 120s cutoff.

Observed onDestroy/audio-focus/foreground timeout interruptions post the same
silent notice; the next process recovery converts an unexpired abandoned RINGING
record once. Android may kill without callbacks or prevent all execution after
force-stop/power-off: immediate missed delivery cannot be guaranteed in those cases.
Reboot restores only future scheduled/snoozed records, never MISSED or old ringing.

The 128 limit is an explicit native projection budget, not an Android guarantee.
An incoming batch of 129 or a replacement exceeding the shared budget throws
TOO_MANY_EVENTS before native cancellation/writes/scheduling; existing events in
both scopes remain intact. No truncation, partial success or notification fallback.
The codec also rejects 129 normal events; only the fictional test may use slot 129.
The raw input batch is bounded at 128 even when it includes past events. Other
scope entries still retained in the projection count toward capacity; pending
prunes expired entries without changing future events.

Current Dart planning can exceed this budget: pico examines 14 days with up to two
alerts per restricted day per vehicle (upper bound 28); three supported obligations
with up to five configured offsets add up to 15 per vehicle. Multiple vehicles can
therefore exceed 128. The coordinator must surface TOO_MANY_EVENTS and explicitly
select/replenish a supported horizon if needed; native code never silently shortens
it. Use reschedule directly for scope replacement, not cancel-then-reschedule:
preemptive Dart cancellation would discard the previous schedule before this guard.

Route allowlist: `/pico`, `/garage`, `/apps/module/soat`,
`/apps/module/tecnomecanica`, `/apps/module/seguro_asistencia`, `/apps/module/impuestos`.
The projection retains only vehicleId from the query, validated after one URL decode
as 1-64 ASCII characters `[A-Za-z0-9_-]`. Pass only the opaque Drift vehicle ID
(production IDs are 32 hexadecimal characters), never plate, nickname, identity or
document metadata. Empty/oversized/unsafe IDs, duplicate decoded query keys, unknown
keys and malformed queries throw INVALID_ROUTE, never silently selecting a favorite.
The known source=obligation_reminder and a similarly validated jurisdictionId are
accepted as compatibility inputs but omitted from the stored route. Canonical
routes are rebuilt using java.net.URI, and the private Android deep link uses
Uri.Builder.path/appendQueryParameter after revalidation; no raw query interpolation.
Private navigation occurs only after Keyguard reports unlocked and rechecks that
the event exists and has not expired. Owner context survives persistence, restore,
claim and snooze, and is never placed in notification text or PendingIntent identity.

Coordinator requirement: include vehicleId for every per-vehicle alarm, including
pico (`/pico?vehicleId=<opaque-id>`). Native cannot recover an owner from a bare
`/pico` payload or from earlier projections that stripped the ID. Generic no-owner
routes remain accepted for compatibility/test; rebuild per-vehicle projections
from Drift after this fix. Flutter must revalidate owner existence upon navigation.

MethodChannel errors contain a stable upper-case code, a generic message and null
details; native exceptions, routes, documents and PII are never logged/returned.
Codes include INVALID_SCOPE, INVALID_ARGUMENTS, INVALID_ROUTE, TOO_MANY_EVENTS,
ID_CONFLICT, NOTIFICATIONS_REQUIRED, EXACT_ACCESS_REQUIRED, ACCESS_REVOKED,
STORAGE_FAILED, PROJECTION_CORRUPT, SCHEDULE_FAILED, CANCEL_FAILED, EVENT_EXPIRED,
ALARM_BUSY, FOREGROUND_START_FAILED, AUDIO_FOCUS_DENIED, PLAYBACK_FAILED,
ALARM_INTERRUPTED, PRIVATE_NAVIGATION_FAILED and BRIDGE_DISPOSED.

## Handoff status

- Status: PARTIAL pending physical Android/store QA; Main owns completed wiring.
- Lot: C11 approved native optional alarms extension.
- Branch: shared `codex/forensic-alerts`; no branch switch, merge or push by this owner.
- Initial native commit: `e1143c64dfe2920a7f19852c08e215bd9c7f1bb4`.
  Owner-context correction: `c03357b740d35caa4d6bef87c522217a3f9b4fce`.
  Follow-up base HEAD: `b432f4e40866904507ab4b4cc19c4dfafe614f60`; exact scoped
  follow-up commit is supplied with the final handoff. No merge or branch change.
- Worktree: `C:/Users/felip/Documents/ChatGPT/PicoRadar_ Pico y Placa`.
- Files: this alerts folder and corresponding `src/test/kotlin/co/picoradar/app/alerts` only.
- Outcome: serialized scope replacement/cancellation, atomic no-backup projection,
  AlarmClock scheduling, generic foreground alarm, Stop/Snooze, unlock-only routing.
- Data: reconstructible `noBackupFilesDir/optional_alerts_v1.bin`; no Drift migration,
  preferences, external data, backups, notifications history, document or GPS fields.
  Binary codec v2 adds originalAt and appends SNOOZED/MISSED phase values. Legacy
  v1 records read with originalAt = at. Old v1 snoozes did not retain originalAt and
  cannot be inferred safely; reconciliation may remove them. This feature has not
  been device-installed by this owner. No private history beyond event eligibility.
- Dependencies added/changed: none.
- Manual QA: source review only; no install, emulator, adb or physical device calls.
- Physical Android QA: REQUIRED AND NOT RUN, per instruction. Device/Android/evidence: none.
- Tests: initial direct Kotlin/JUnit rules tests GREEN (24 tests). Owner/capacity
  correction RED (7 failures in 31 tests), then GREEN (31 tests); all native source
  compiled directly against installed Android
  37 SDK + cached Flutter/AndroidX. Runtime Android behavior is not covered by JVM tests.
- Follow-up evidence: 3 behavior regressions RED (active/snooze/due identity and
  failure erased by successful writes), plus later RED for persisted first-error
  overwrite. Missing new APIs initially failed compilation. Final GREEN: 46 JVM
  tests, full native sources compiled with -CompileAndroid; only existing
  pre-26 notification-priority deprecation warnings. Tests cover owner/date/delete/
  expiry cancellation, shared snooze fixture, codec v1/v2, silent-missed engine
  effects, recovery without replay, session callback generation and status latch.
  Activity lifecycle and actual silent Android notifications still need device QA.
- Exact verification: from repo root,
  `& './mobile/android/app/src/test/kotlin/co/picoradar/app/alerts/run-pure-tests.ps1'`
  and the same command with `-CompileAndroid`.
- Initial Gradle `:app:testDevDebugUnitTest --tests co.picoradar.app.alerts.AlertRulesTest --offline --console=plain`
  was blocked in compileFlutterBuildDevDebug by unrelated
  `maintenance_screen.dart:632 ProviderContainer.disposed`; no out-of-scope fix.
- Every Gradle/Flutter invocation acquired `Local\PicoRadarFlutterGate`; later
  native-only Gradle attempts skipped execution when the mutex was busy.
- No global Flutter suite executed. Direct Kotlin runner invokes neither Gradle nor Flutter.
  This correction ran only the direct Kotlin runner with -CompileAndroid, no Gradle.
- Risks/debt: physical permission/lockscreen/sound/background/reboot/clock/tap QA,
  Android 14+ full-screen eligibility and Play declarations remain open; force-stop,
  power-off and OS scheduling restrictions do not guarantee delivery. Only one
  simultaneous event rings; colliding due callbacks are consumed, never queued as a burst.
- Failure recovery: scope replacement first invalidates old persisted tokens. A failed
  new batch is canceled, reports a typed error, and must be retried by the coordinator.
- Next work unblocked: coordinator Activity/manifest/Dart integration and focused QA;
  this does not close C11 or authorize release.
- Coordinated Dart commits: Parfit `32342ed` / `cef3f32`; Goodall status UI/gateway
  `b432f4e`. Their test claims are separate from this owner's native evidence.
- Handoff correction: the original implementation removed the notification at
  cutoff and did NOT meet the requested missed-notice behavior. This follow-up
  adds it; prior generic-foreground claims must not be read as missed-notice QA.
- Git status: other agents' shared-tree modifications/untracked artifacts preserved;
  final scoped commit/status evidence is supplied in the response.
- No merge performed.
