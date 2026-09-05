# V01A: owner feedback and proposed visual contracts

Status: bounded usability fixes in this branch; visual alternatives below are PROPOSALS, not owner-approved designs. No merge or deployment is authorized by this document.

Authority: owner decisions reviewed against main `70d663e969f69624e2dfde228a9ac85633373982`, original `V00R_OWNER_DECISIONS.csv` SHA-256 `5273A7B8D1677D7946D4532412184E5A2A53C821E0F7A5B0ED5468140673DCAC`, and owner execution brief `PicoRadar_V01A_DECISIONES_OWNER_AJUSTES_Y_CONTRATOS_KISS.md` (2026-09-05). Exact decisions/notes and per-requirement evidence accompany the requested handoff export. All 43 original priorities are empty; technical ordering is not an owner priority.

## Scope boundaries

- 4 KEEP, 32 POLISH, 7 REDESIGN. KEEP: R03, R17, R18, X01. REDESIGN: R07, R08, R09, R10, R12, R15, R16. Other rows remain POLISH.
- Concrete V01A work: truthful compact Home location, closing Alerts to its origin, focused Garage detail/action order, creation back and subtype compatibility, Pico presentation, Driving informational notice/no-target copy, local Trip selection/search/restrictions and verified official road-information link.
- No engine, matcher, cone, episode, voice, map-provider, HUD-orientation, schema, backend, permission or dependency changes. No new full visual design implemented.
- S07 remains an alias of R12; X03 shares P02B. No duplicate modules or screens.
- The five tabs remain Inicio, Garaje, Apps, Viaje, Conducir; Apps stays central. Home retains its owner-approved exclusion of a Driving CTA.

## Five visual families: owner choice still required

| Family | Alternative A | Alternative B | States and constraints |
|---|---|---|---|
| R07 vehicle detail | Compact identity, circulation, SOAT/RTM, insurance/tax, documents, edit. Main CTA opens actual Pico detail; contextual actions complete real missing data. | Identity and real alert summary followed by collapsible Circulation, Obligations, Protection, Documents and Administration. | Active/focused distinction; unknown is not unrestricted; unset is not compliant. Keep edit/destructive actions distinct and existing safeguards. No invented score. |
| R08/R09 creation | Three-family selector, then essential plate/city followed by compact optional fields and Save. | Same selector; plate/city/subtype then expandable optional data and Save. | Back returns to selector during creation; compatible draft data preserved. Edit/legacy values do not silently reclassify. Essential fields fit Mi A3 at scale1 with keyboard closed; all optional fields remain available. Keyboard or scale1.5/2 permits scroll and more height, never scaling the user down. |
| R10/R11 Apps | Compact header/close and view selector above existing 3x3 grid; remove redundant reserved space after measuring actual bottom inset. Proposed target58-62% of body at scale1. | Title and view selector in one band, same grid/order; proposed target55-60% only if complete labels and touch areas fit. | Current code uses70% of body, not a measured three-quarters claim. Nine primary modules, More and secondary order remain. Touch targets >=48dp; larger text permits more height/scroll. No production panel changes in V01A. |
| R12/S07 Trip | Single heading, trip-local vehicle, origin/destination/date, independent restriction results, external navigation and official road-information action. | Compact local input section followed by two clearly identified origin/destination result sections and external actions. | One date applies to both endpoints, no invented arrival/return/intermediate coverage. Missing/deleted selection is explicit. No route/toll totals before F01. Full visual layout awaits choice. |
| R15/R16 camera alert/map/radar | Existing speedometer coexists with compact map-first alert panel; eligible reported-speed sign stays beside speedometer, outside alert facts. | Same speedometer/sign relationship with radar-first panel and location/authority facts. | Preserve sweep, heading/distance semantics, map/radar controls and HUD orientation. ANSV reported speed is not promoted to a legally verified limit. Unknown speed omits sign/overspeed claim. Partial tiles are not a loaded map; retained fallback behavior is not changed or proved fixed by a proposal. |

Shared actions for both alternatives in each family:
- R07: open real Pico detail for the displayed vehicle ID; Edit preserves that identity. Missing data opens its existing edit flow; delete remains separately confirmed with K7 protections. Loading/error/unknown must not display invented compliance.
- R08/R09: select category, Back and Save. Save uses existing validation/busy guards. Fitting essential inputs at scale 1 with keyboard closed is a target pending measurement, not an achieved result; optional inputs and accessible scroll remain.
- R10/R11: close the overlay, switch primary/More view, open the existing module. Preserve module guards, labels and order; do not reduce touch targets to meet height targets.
- R12/S07: single principal title `Planea tu viaje`; select local vehicle, choose endpoints/date, save local draft. Existing external actions open Google Maps, Waze or verified official road information. Incomplete inputs require correction; deleted vehicles require explicit reselection; unknown rules remain unknown; launcher failure remains visible. No action changes global active vehicle/city.
- R15/R16: retain current session finish, map/radar selection and HUD controls, plus existing camera detail/location actions. GPS/permitted/denied/error, target absent, target with or without eligible reported speed and partial tiles/fallback remain distinct. No new session action, matcher or voice behavior is proposed.

All alternatives preserve readable sources, semantics, truthful empty/error/loading states and existing gestures. Current V01A fixes require section 6 tests and physical QA before their closeout, without waiting for a visual choice. Future full redesigns require owner selection and their own validation at 360x800, 390x844, 412x915, scales 1/1.5/2, keyboard reachability and individual physical captures when implemented. Proposals do not authorize hiding fields/actions to fit a percentage. No collage or new inventory replaces the owner's existing decisions. Home's Driving-CTA exclusion comes from `docs/design/HOME_OWNER_V4.json`.

## Remaining work, not silently discarded

V01B tracks conservative typography, spacing, sources, actions, dialogs and accessibility for remaining POLISH rows: R04/R05/R11/R17B/R18B, P02/P02B/P03/P04/P05/P06/P07/P08/P09, S01-S06 including S05B, and X02-X04, plus any residual visual polish in locally fixed surfaces. KEEP stays KEEP; no inferred priority or automatic REDESIGN.

P07 PDF import remains unverified following the V00R physical picker failure. No direct-store injection, cipher/gateway change, or empty-state screenshot counts as a successful import. R15 tile coverage remains a distinct external/evidence limitation. Prior K7 closure does not imply these new capabilities are complete.

F01 tolls remains a requested expansion: verify concrete route, direction, vehicle category, station-by-station current tariffs and licensing. A partial subtotal is not a complete total and unknown is not zero. Select an authorized provider/budget or official-data maintenance path before implementing; no credentials, subscription or billing activated in V01A.

F02 manual camera updates remains a requested expansion: the packaged local pack/publisher does not prove a published HTTPS channel. Show installed and remote versions separately when verified. Proposed states are checking/error/offline/up-to-date/update-available based on real requests; without a verified channel no up-to-date claim is valid. Validate trusted HTTPS origin, schema, bounded size, version and byte SHA; activate atomically with previous copy retained, never during an active Driving session. Same-origin SHA is integrity, not independent origin authentication. No GPS/plate transmission or download on opening Apps; no fictitious update action.

## Driving informational notice

The owner-supplied notice is proposed informational copy, pending legal review before public release. It does not transfer all responsibility to the user or waive statutory rights. Where consumer law applies, Ley1480 articles42/43 restrict abusive clauses and certain liability limitations. Primary reference: [official legal text](https://www.ins.gov.co/Normatividad/Leyes/LEY%201480%20DE%202011.pdf#page=10). The notice is accessible from idle, is dismissible, and introduces no mandatory consent or interruption of active driving.

Next: review bounded PR + choose visual alternatives + authorize F01/F02 separately. No D02, automatic design approval, merge or deploy.
