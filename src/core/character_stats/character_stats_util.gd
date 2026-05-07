## CharacterStatsUtil — pure static utility for effective stat computation and window frame derivation.
## ADR-0007: Effective Stat Computation and Window Frame Derivation.
## All systems that need effective stats call these functions — no inline computation permitted.
## Example: CharacterStatsUtil.effective_stat(12, 2, -5)  →  9
class_name CharacterStatsUtil extends RefCounted

## Accessibility knob — scales attack and block window durations. Range: 0.6–1.6.
## Defined in exactly one .gd file. Do not shadow this constant elsewhere. — ADR-0007 Rule 3.
const WINDOW_SCALE_FACTOR: float = 1.0

## Hard ceiling on timing window frames (Formula 2a). Tuning range: 20–45.
const TIMING_WINDOW_FRAMES_MAX: int = 30

## Reference ceiling for block window derivation (Formula 2b). Tuning range: 28–50.
const BLOCK_WINDOW_BASE: int = 32

## Minimum effective FLUX enforced by Status Effects (SE GDD). Not clamped here — used by SE epic.
const EFFECTIVE_FLUX_FLOOR: int = 8

## Minimum magnitude for any FLUX inheritance — floors the raw compute_inheritance_magnitude() result.
## Guarantees effective FLUX increases by at least 2 per FLUX inheritance. — TR-CSG-005.
const FLUX_INHERITANCE_MIN: int = 2


## Returns the effective value of a single stat after all modifier layers.
## Layer order: base + sum(inheritances) + sum(status_modifiers), clamped [1, 99].
## No system may replicate this computation inline. — ADR-0007 Rule 1 & 4.
##
## Example:
##   CharacterStatsUtil.effective_stat(12, 2, -5)   # returns 9
##   CharacterStatsUtil.effective_stat(8, 0, -10)   # returns 1  (floor)
##   CharacterStatsUtil.effective_stat(90, 5, 10)   # returns 99 (ceiling)
static func effective_stat(
		base: int,
		inheritance_sum: int,
		status_modifier_sum: int) -> int:
	return clampi(base + inheritance_sum + status_modifier_sum, 1, 99)


## Returns the offensive timing window in frames from effective FLUX (Formula 2a, CS&G GDD).
## Input: effective FLUX of the acting combatant, already clamped [1, 99].
## Output clamped [2, TIMING_WINDOW_FRAMES_MAX] — no 0- or 1-frame windows permitted.
## Rounding: int(value + 0.5) — round-half-up. Never use GDScript round() (banker's rounding).
##
## Example (WINDOW_SCALE_FACTOR = 1.0):
##   CharacterStatsUtil.timing_window_frames(16)  # returns 16
##   CharacterStatsUtil.timing_window_frames(1)   # returns 2  (floor clamp)
##   CharacterStatsUtil.timing_window_frames(99)  # returns 30 (ceiling clamp)
static func timing_window_frames(effective_flux: int) -> int:
	var raw := int(float(effective_flux) * WINDOW_SCALE_FACTOR + 0.5)
	return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)


## Returns the block window in frames from effective TEMPO (Formula 2b, CS&G GDD).
## Input: effective TEMPO of the attacking enemy, already clamped [1, 99].
## Output clamped [2, TIMING_WINDOW_FRAMES_MAX].
## Rounding: int(value + 0.5) — round-half-up.
##
## Example (BLOCK_WINDOW_BASE = 32, WINDOW_SCALE_FACTOR = 1.0):
##   CharacterStatsUtil.block_window_frames(24)  # returns 8
##   CharacterStatsUtil.block_window_frames(32)  # returns 2 (floor clamp — TEMPO >= BASE)
##   CharacterStatsUtil.block_window_frames(99)  # returns 2 (floor clamp)
static func block_window_frames(effective_tempo: int) -> int:
	var raw := int(float(BLOCK_WINDOW_BASE - effective_tempo) * WINDOW_SCALE_FACTOR + 0.5)
	return clampi(raw, 2, TIMING_WINDOW_FRAMES_MAX)


## Returns the inheritance magnitude for one stat, applying zero-floor and FLUX minimum.
## Rounding: int(value + 0.5) — round-half-up, matching ADR-0007 rounding rule.
## For FLUX: result is at least FLUX_INHERITANCE_MIN (2), regardless of base_stat.
## For all stats: result is at least 1 — zero-magnitude inheritances are never created.
##
## Example:
##   CharacterStatsUtil.compute_inheritance_magnitude(8, &"flux", 0.15)   # returns 2 (floor)
##   CharacterStatsUtil.compute_inheritance_magnitude(20, &"flux", 0.15)  # returns 3
##   CharacterStatsUtil.compute_inheritance_magnitude(1, &"atk", 0.15)    # returns 1
static func compute_inheritance_magnitude(
		base_stat: int,
		stat: StringName,
		ceiling: float = 0.15) -> int:
	var raw := int(float(base_stat) * ceiling + 0.5)
	raw = maxi(raw, 1)
	if stat == &"flux":
		raw = maxi(raw, FLUX_INHERITANCE_MIN)
	return raw
