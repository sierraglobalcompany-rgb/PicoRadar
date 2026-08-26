# Execution Order

Recommended primary path:

1. C00 — repo/scaffold/flavors
2. C01 — app shell/router
3. C02 — CI
4. C03 — Drift DB
5. C04 — prefs/secure/crypto
6. C05 — manifest sync
7. C06 — vehicle domain
8. C07 — onboarding
9. C08 — garage
10. C09 — pico rule engine
11. C10 — restrictions import
12. C11 — Home/alerts
13. C12 — Apps launcher
14. C13 — SOAT/RTM/insurance/taxes
15. C14 — comparendos official links
16. C15 — private wallet/scanner
17. C16 — camera repository
18. C17 — location service
19. C18 — camera matcher
20. C19 — alert engine/driving UI
21. C20 — background/HUD physical gate
22. C21 — Trip UI/mock
23. C22 — routes/places backend proxy
24. C23 — trip enrichment
25. C24 — services/CDA
26. C25 — reports/leads foundation
27. C26 — defense rule engine
28. C27 — defense PDF/deadlines
29. C28 — admin/publisher
30. C29 — hardening Free 1.0

## Safe parallelism after C00

- C02 can run in parallel with C01/C03.
- C17 can begin after C00 while data/UI lots progress.
- C22 can run server-side after C00 and before C23.
- C28 can begin once C05 contracts are stable, but should not force mobile contract changes.
- C26 can begin after C15/C03 even if services are unfinished.

Do not parallelize lots that edit the same architectural core unless explicitly coordinated.
