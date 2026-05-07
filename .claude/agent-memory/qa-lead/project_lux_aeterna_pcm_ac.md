---
name: Lux Aeterna — Party Composition Manager AC status
description: 21 ACs drafted for party-composition-manager.md; all BLOCKING; 3 testability flags raised; 5 coverage gaps documented; not yet written to GDD file
type: project
---

## Party Composition Manager — AC Status

- 21 acceptance criteria drafted (AC-1 to AC-21)
- All criteria in GIVEN-WHEN-THEN format
- All criteria classified BLOCKING (LOGIC or INTEGRATION — no advisory criteria; PCM has no UI/Visual/Config stories)
- NOT YET written to `design/gdd/party-composition-manager.md`

## Testability Flags (designer/programmer action required)

1. **AC-6**: "UNINITIALIZED state preserved" requires internal state access — recommend exposing `is_initialized() -> bool` on PCM API
2. **AC-16**: `get_party_size()` safe default before init is unspecified in GDD — designer must confirm (assumed 0)
3. **AC-20**: Scene transition test requires running Godot instance or integration scene — cannot run headlessly with GUT alone; flag to lead-programmer

## Coverage Gaps Documented

1. **Slot identity post-guest-cycle** — no AC verifies Clawd is still specifically in slot 1 after guest operations (safe given no slot-shuffling, but untested)
2. **INV-2 "valid CharacterData" undefined** — "null or valid CharacterData" has no machine-readable definition of "valid"; recommend designer add a schema predicate
3. **Signal argument type** — AC-10/AC-12 verify signal is emitted but not that argument is typed as CharacterData
4. **Same-frame double-registration** — single-threaded Godot makes this safe but undocumented; recommend a GDD edge case note
5. **get_party_snapshot() copy vs. reference** — Dictionary values may be live refs or copies; affects AC-19 at snapshot level; designer must clarify

## Gate Classification

- LOGIC — BLOCKING: AC-2, AC-3, AC-6, AC-7, AC-8, AC-9, AC-11, AC-12, AC-13, AC-14, AC-15, AC-17, AC-18
- INTEGRATION — BLOCKING: AC-1, AC-4, AC-5, AC-10, AC-16, AC-19, AC-20, AC-21
