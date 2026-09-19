# Local alerts and optional Android alarms

Status: owner approved scope, implementation 2026-09-19; physical/store gates remain open.

## Decision

Extend C11/C13 with per-vehicle/category reminder settings in Drift. Obligation dates and restriction datasets remain authoritative. Old settings are inherited until an explicit override is saved. Normal notifications remain the default; rich rendering and alarm mode are opt-in. No documents, GPS or identities enter notification assets or logs.

Android alarm scheduling uses an isolated MethodChannel and native projection of future events. This projection is reconstructible, app-private/no-backup, and contains identifiers/times only, not plate images or private document metadata. Cancellation is scoped by category. Permissions are requested only upon explicit activation; no USE_EXACT_ALARM claim of clock-app status. SCHEDULE_EXACT_ALARM/full-screen special access are checked separately. Missing authorization is visible and does not silently switch modes.

Alarm sound uses the system alarm tone, without changing system volume or DND. One active sound, 120-second limit, Stop and Snooze 10 minutes. Stop is available on lockscreen; private navigation requires unlock. Native receiver/service/activity are not exported. Reboot restores only future events; missed events never ring in a burst. No guaranteed delivery after force-stop or power-off.

Notification rich content uses a locally drawn plate, never a document photo. The installed Flutter notification plugin cannot set a generic public version: ordinary and enriched Android notifications therefore use SECRET visibility, hiding the whole notification on the lockscreen. Native alarms supply generic private/public content, without plate images. No new runtime package planned. iOS alarm availability is explicit unsupported, ordinary notifications retain existing contract. Rich lockscreen privacy is an Android deliverable, not an iOS implementation claim.

## Verification

Migration and legacy defaults, deterministic identities, category cancellation, permission denial/revocation, delayed writes, reboot/clock changes, expiry, sound cutoff, snooze, private lockscreen, repeated navigation and actual OS scheduling must be tested. Android 14+ full-screen eligibility and Play declarations remain a release gate, not an assumed approval.
