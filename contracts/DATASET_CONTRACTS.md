# Dataset Contracts — Baseline

## Common envelope

Every published dataset has:
- schemaVersion;
- version;
- generatedAt;
- source/verification metadata where relevant.

## Restrictions
Indexable concepts:
- jurisdiction_id;
- vehicle_type;
- valid_from / valid_until;
- priority;
- active.
Flexible rule payload can contain:
- plate digit position;
- digits / parity;
- day/week/date rules;
- multiple time windows;
- holidays;
- registration origin;
- corridors;
- temporary overrides.

Engine output is typed:
`allowed | restricted | unknown | stale`.

## Cameras
Required:
- camera_id;
- region_code;
- lat/lon;
- type;
- source;
- verified_at;
- speed_limit_verified.

Optional:
- direction/bearing;
- corridor;
- speed_limit.

Unknown speed limit never triggers overspeed.

## Tolls
- toll station;
- coordinates;
- direction;
- rates by vehicle category;
- valid_from / valid_until.

## Directories
- business_id;
- category;
- vehicle types;
- coordinates;
- official status/source;
- commercial/sponsor state stored separately.

## Legal
- legal rule ID;
- legal basis;
- effective dates/status;
- template version;
- reviewed_at.
