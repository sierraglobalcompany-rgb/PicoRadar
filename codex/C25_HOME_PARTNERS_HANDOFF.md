# C25 Home Partners Handoff

## Status
`DONE`

## Lot
`Lot D / C25 - Home partner inquiry slice`

The incorrect-data report portion of the broader C25 lot was not part of this
delegation and remains untouched.

## Git
- Branch: `codex/lot-d-home-partners`
- Implementation HEAD: `cbce7b389ec26a84cd9b006512aa2c355894fe56`
- Base HEAD: `d26ba84b1e1aeb7738e7dc965a3ad4adca16d917`
- Worktree: `C:\Users\felip\.codex\worktrees\owner-home-partners\PicoRadar_ Pico y Placa`
- Final branch HEAD includes this handoff commit and is reported in the owner delivery.
- No push or merge performed.

## Outcome
- Added a manual four-slide Home carousel directly below the compact header and
  before the vehicle carousel.
- Slides 1-3 are local-only demonstrations for automotor, insurance and
  appraisal. They open explanatory sheets and never submit data.
- Slide 4 opens a complete partner inquiry form only when the HTTPS, current
  privacy notice and administrative-review gates are satisfied.
- Added an explicit link to the configured privacy notice and consent that names
  PicoRadar as the recipient and purpose owner.
- Added `POST /api/v1/partner-inquiries`, an authenticated administrative inbox,
  status workflow, append-only non-PII status audit and the scheduled 180-day
  purge of unapproved inquiries.

## Configuration Gate

Production server requirements:

- `APP_URL=https://...`
- `PARTNER_INQUIRIES_ENABLED=true`
- `PARTNER_INQUIRIES_ADMIN_INBOX_ENABLED=true`
- `PARTNER_INQUIRIES_PRIVACY_VERSION=<current-version>`
- `PARTNER_INQUIRIES_PRIVACY_URL=https://...`
- `PARTNER_INQUIRIES_ALLOW_INSECURE_LOCAL=false`

Production mobile build requirements:

- `API_BASE_URL=https://...`
- `PICORADAR_PARTNER_INQUIRIES_ENABLED=true`
- `PICORADAR_PARTNER_ADMIN_REVIEW_CONFIGURED=true`
- `PICORADAR_PARTNER_PRIVACY_VERSION=<same-current-version>`
- `PICORADAR_PARTNER_PRIVACY_URL=https://...`

Local development may use an HTTP `localhost`, `127.0.0.1` or loopback IPv6 API
only with `APP_ENV=dev` and
`PICORADAR_PARTNER_INQUIRIES_ALLOW_INSECURE_DEV=true`; the server separately
requires a local/testing environment plus
`PARTNER_INQUIRIES_ALLOW_INSECURE_LOCAL=true`. External HTTP hosts remain denied.
All gates default to OFF.

## Files / Areas Changed
- `mobile/lib/features/home/`: partner configuration, minimal HTTP client,
  carousel, local explanations and consented inquiry form.
- `mobile/assets/home/partners/`: four stable 1200x480 placeholder PNGs.
- `mobile/test/features/home/`: transport, gate, interaction, placement,
  responsive and existing Home regression coverage.
- `server/app/Http`, `server/app/Models`, `server/app/Services`: validated public
  intake and authenticated administrative workflow.
- `server/database/migrations`: `partner_inquiries` schema.
- `server/resources/views/admin`: inbox and status-audit views.
- `server/routes`, `server/config`, `server/.env.example`: endpoint, scheduler,
  throttling and fail-closed configuration.

## Tests Executed
| Command / test | Result |
|---|---|
| `flutter test --no-pub` for partner client/config/carousel plus complete `home_screen_test.dart` | PASS, 205 tests |
| Final focused partner client/config/carousel run | PASS, 11 tests |
| Home viewport matrix: 360x800, 390x844, 412x915, text scale 1.0/1.5/2.0 | PASS |
| `flutter analyze --no-pub` | PASS, no issues |
| `dart format --output=none --set-exit-if-changed .` | PASS, 371 files checked, 0 changed |
| Partner API/admin PHPUnit files | PASS, 10 tests / 63 assertions |
| Complete server PHPUnit suite | PASS, 503 tests / 2056 assertions |
| `php vendor/bin/pint --test` | PASS |
| `git diff --check` before commit | PASS |

## Manual QA
- Inspected all four local placeholder bitmaps at source resolution.
- Confirmed the left copy-safe area, right-aligned subject, no embedded text,
  no manufacturer/insurer/official logos and no decorative orb treatment.
- Widget tests cover manual-only paging, local-only first three slides, the
  enabled form, the disabled gate, consent enforcement, privacy link presence,
  successful receipt and responsive layout.

## Physical Android QA
`Not required`
- Device: Not run.
- Android: Not applicable.
- Evidence: C25 declares physical QA not required; no camera, GPS, background,
  Bluetooth, TTS, HUD or sensitive lifecycle behavior changed.

## Data / Migration Impact
- Adds `partner_inquiries` with public ID, hashed idempotency key, request
  fingerprint, voluntary contact fields, consent version/time, status and
  timestamps.
- Statuses: `pending`, `reviewing`, `contacted`, `approved`, `rejected`.
- `partner-inquiries:purge` runs daily at 02:15 and deletes only unapproved
  records older than 180 days. Approved records are excluded.
- Existing schemas and user-local mobile data are unchanged.

## Security / Privacy Review
- Public endpoint validates an exact allowlist and explicitly prohibits plate,
  GPS/coordinates, documents and attachments.
- Five new attempts per hashed IP per hour; idempotency keys are hashed at rest
  and conflicting payload reuse returns 409.
- Mobile sends no plate, GPS, document or attachment fields and logs no inquiry
  PII. Server code adds no PII logging.
- Administrative inbox/status/audit routes require authentication, active
  operator middleware and role gates.
- Audit metadata contains only public inquiry ID and status transition.
- Production readiness fails closed without HTTPS, a current privacy version,
  an HTTPS privacy URL and enabled administrative review.

## Dependencies Added / Changed
- No runtime package added.
- Existing Dio, Riverpod and `url_launcher` dependencies are reused.
- Local dependency installation (`composer install`, `flutter pub get`) changed
  no tracked lockfile.

## Asset Gaps / Exact Replacement Requirements
Replace the four placeholder files in place, preserving filenames and these
requirements:

- Canvas: exactly 1200x480 px (2.5:1), opaque PNG or lossless WebP after a
  coordinated pubspec/code update; sRGB; target <= 250 KB each.
- Composition: keep the left 55% low-detail and dark enough for white overlay
  copy; place the primary subject in the right 45%; no embedded words or CTA.
- `automotor_placeholder.png`: generic unbranded passenger vehicle or neutral
  dealership scene; no readable plate, dealer identity or manufacturer logo.
- `insurance_placeholder.png`: generic vehicle-protection concept; no insurer,
  regulator or official/accredited mark and no policy-document details.
- `appraisal_placeholder.png`: generic vehicle inspection/peritaje scene with
  tools or inspection gesture; no readable VIN, plate, report or personal data.
- `recruitment_placeholder.png`: inclusive small-business partnership scene;
  no third-party logo and no implication that an unapproved partner is active.
- Licensing: PicoRadar-owned generation or documented commercial reuse rights;
  retain source/license evidence outside the app bundle as required by SOP.
- Accessibility: imagery remains supplementary; all meaning and actions stay in
  local visible text and semantics.

## Known Risks / Debt
- The four committed images are deliberately generic placeholders, not final
  campaign creative.
- Production remains OFF until a real HTTPS endpoint, published privacy notice,
  matching consent version and staffed administrative inbox are configured.
- No physical-device visual pass was required or performed.
- The separate incorrect-data report flow in C25 remains for its owning lot.

## Stop Conditions Encountered
- None. No credential, policy, package, migration-safety or architecture blocker
  was encountered.

## Next Lot(s) Unblocked
- Production partner-program activation after legal/privacy approval, final
  creative delivery and administrative operating readiness.
- The independently scoped C25 incorrect-data report flow.

## Do Not Forget
- No merge performed. No push performed. Human approval is still required for
  either action.
