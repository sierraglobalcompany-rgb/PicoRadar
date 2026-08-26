# Android Physical QA Checklist

Use for lots marked **PHYSICAL QA REQUIRED**.

## Device matrix

At minimum:
- one physical mid-range Android device;
- one device/API close to production target when available;
- test both Wi-Fi/mobile data states.

## Core lifecycle

- cold launch;
- warm resume;
- background/foreground;
- screen lock/unlock;
- rotate if supported;
- process recreation where relevant;
- battery saver;
- airplane mode;
- permissions denied / later enabled.

## GPS / Driving

- start/stop tracking;
- GPS weak;
- urban canyon;
- straight approach;
- opposite direction camera;
- parallel road;
- turn before camera;
- two cameras close;
- GPS jitter;
- background while Waze/Maps visible;
- lock screen;
- phone call interruption;
- Bluetooth vehicle audio;
- TTS route/audio;
- 30 / 60 / 120 minute battery session;
- foreground notification;
- final stop releases GPS/service.

## HUD

- normal + mirrored;
- dark/night readability;
- keep-awake;
- brightness handling;
- exit flow.

## Scanner / Billetera

- camera capture;
- two sides;
- gallery import;
- cancel/retry;
- temp plaintext deleted;
- biometric allow/deny;
- app restart;
- screenshots/backup behavior per design.

## Notifications

- permission denied;
- scheduled notification;
- rule update causes reschedule;
- tap deep-link;
- exact-alarm restrictions handled gracefully.

## Evidence

Record:
- device/model;
- Android version;
- build SHA;
- scenario;
- result;
- screenshot/video/log when useful;
- battery before/after for driving sessions.
