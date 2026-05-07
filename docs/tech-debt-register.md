# Tech Debt Register

> Tracks known technical debt items deferred during story implementation.
> Each entry captures the issue, the story that introduced it, and the story
> that should resolve it. Reviewed at sprint close-out before advancing stages.

---

## Open Items

### TD-001 — Infinite-Stun Synchronous Recursion in TCS FSM

| Field | Value |
|-------|-------|
| **Introduced by** | Story 002 — TCS Turn Order (`production/epics/timing-combat-system/story-002-tcs-turn-order.md`) |
| **Must resolve before** | Story 005 — CC Economy (stun application lands here) |
| **Severity** | HIGH — will cause engine crash ("call stack size exceeded") in production |
| **File** | `src/feature/combat/timing_combat_system.gd` |

**Description**:

The synchronous FSM call chain `_process_round_end()` → `_process_round_start()` →
`_process_turn_start()` → `_process_turn_skipped()` → `_process_turn_end()` →
`_process_round_end()` can loop indefinitely without unwinding the stack.

This happens when every living combatant has an active stun (`se.check_turn_skip()`
returns `true` for all) in every round. The empty-queue guard in `_process_round_start()`
only fires if all combatants are dead — it does not break a stun-only loop.

GDScript has no tail-call optimization. On desktop targets this produces a
`"call stack size exceeded"` engine error and crashes the running scene.

**Proposed resolution options** (one of):
1. Add a consecutive-skip counter in `_process_turn_start()`. If the counter
   exceeds `_turn_queue.size()` (all slots skipped in one pass), force ROUND_END
   without recursing back into ROUND_START.
2. Defer `_process_round_start()` via `call_deferred()` inside `_process_round_end()`
   to unwind the call stack between rounds (safe for turn-based games where the
   FSM only advances on player input or timer).

**Flagged by**: `/code-review` — Architecture Specialist, 2026-05-05

---

## Resolved Items

*(none yet)*
