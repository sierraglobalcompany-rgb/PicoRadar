# API Contract Baseline v1

Dynamic API stays minimal.

## GET /api/v1/health
Health only. No auth.

## POST /api/v1/places/autocomplete
Purpose: server-side proxy to place autocomplete.

Request fields:
- query
- sessionToken
- optional country bias

Never include:
- plate;
- document ID;
- private documents.

## POST /api/v1/routes/compute
Request:
- origin;
- destination;
- departureTime;
- travel mode;
- route preference.

Backend:
- calls RouteProvider;
- requests minimal field mask;
- does not store trip history by default.

## POST /api/v1/reports
Purpose: report incorrect directory/public data.
Rate limited.

## POST /api/v1/leads
Only enabled when a real partner exists.
Requires:
- explicit partner ID;
- consent version;
- user-entered contact data.
No silent multi-partner fan-out in Free 1.0.

## Error shape

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Safe user-facing message",
    "correlationId": "optional"
  }
}
```
