# Global Definition of Done + Stop Conditions

## Every lot is DONE only if

- Scope is implemented without silent extras.
- Formatting/lint/static analysis pass.
- Required tests pass.
- No secret/PII leak.
- New behavior has tests where reasonably testable.
- Docs/ADR updated if a decision changed.
- Required manual/physical QA completed.
- Android dev build is green for integration lots.
- Worktree is clean or documented.
- Handoff is complete.

## Global Stop Conditions

Stop rather than improvise when:
- baseline conflicts;
- required credential/key is unavailable;
- a dependency cannot support API 36/current Flutter;
- migration may destroy user data;
- proposed approach violates local-first/privacy;
- policy/store requirement materially changes product;
- physical QA reveals a platform constraint not covered in baseline;
- scope must expand substantially to make tests pass.

Return evidence + 2–3 options when possible.
