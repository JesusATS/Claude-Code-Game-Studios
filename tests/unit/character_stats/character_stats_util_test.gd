## Unit tests for CharacterStatsUtil — effective stat computation and window frame derivation.
## Story 002: CharacterStatsUtil — Effective Stat & Window Computation
## Covers: TR-CSG-002, TR-CSG-003, TR-CSG-004
extends GdUnitTestSuite


# --- effective_stat() ---

## AC-3: floor clamp holds regardless of modifier magnitude.
func test_effective_stat_floor_clamp_large_negative_modifier() -> void:
	assert_int(CharacterStatsUtil.effective_stat(8, 0, -10)).is_equal(1)


## AC-16: layering base → inheritances → status_modifiers → clamp.
func test_effective_stat_floor_with_inheritance_and_modifier() -> void:
	assert_int(CharacterStatsUtil.effective_stat(12, 2, -15)).is_equal(1)


## AC-17: ceiling clamp holds; 18+0+50=68, no ceiling hit.
func test_effective_stat_unclamped_ceiling_case() -> void:
	assert_int(CharacterStatsUtil.effective_stat(18, 0, 50)).is_equal(68)


## AC-19: sum-then-clamp; 11+95+0=106 → 99.
func test_effective_stat_ceiling_clamp_large_inheritance() -> void:
	assert_int(CharacterStatsUtil.effective_stat(11, 95, 0)).is_equal(99)


## AC-27: sum-then-clamp, not per-object clamp; 18+5+0=23.
func test_effective_stat_sum_then_clamp() -> void:
	assert_int(CharacterStatsUtil.effective_stat(18, 5, 0)).is_equal(23)


## Edge: extreme negative modifier — floor always 1.
func test_effective_stat_extreme_negative_floor() -> void:
	assert_int(CharacterStatsUtil.effective_stat(1, 0, -100)).is_equal(1)


## Edge: extreme positive modifier — ceiling always 99.
func test_effective_stat_extreme_positive_ceiling() -> void:
	assert_int(CharacterStatsUtil.effective_stat(90, 5, 10)).is_equal(99)


## Normal: no modifiers returns base unchanged.
func test_effective_stat_no_modifiers_returns_base() -> void:
	assert_int(CharacterStatsUtil.effective_stat(45, 0, 0)).is_equal(45)


## Normal: mixed modifiers; 12+3-2=13.
func test_effective_stat_mixed_modifiers() -> void:
	assert_int(CharacterStatsUtil.effective_stat(12, 3, -2)).is_equal(13)


# --- timing_window_frames() ---

## AC-7: Clawd base_flux=16 at SCALE=1.0 returns 16.
func test_timing_window_frames_clawd_flux() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(16)).is_equal(16)


## Ne base_flux=8 at SCALE=1.0 returns 8.
func test_timing_window_frames_ne_flux() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(8)).is_equal(8)


## AC-8: FLUX=1 returns floor clamp of 2.
func test_timing_window_frames_floor_clamp() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(1)).is_equal(2)


## AC-9: FLUX=99 returns TIMING_WINDOW_FRAMES_MAX ceiling (30).
func test_timing_window_frames_ceiling_clamp() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(99)).is_equal(30)


## Rounding: int(3.0*1.0+0.5)=int(3.5)=3 — GDScript int() truncates toward zero.
func test_timing_window_frames_rounding_truncates_half() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(3)).is_equal(3)


## Rounding: int(5.0*1.0+0.5)=int(5.5)=5.
func test_timing_window_frames_rounding_flux_5() -> void:
	assert_int(CharacterStatsUtil.timing_window_frames(5)).is_equal(5)


# --- block_window_frames() ---

## AC-24: TEMPO=24, BASE=32, SCALE=1.0 → int((32-24)*1.0+0.5)=int(8.5)=8.
func test_block_window_frames_standard_case() -> void:
	assert_int(CharacterStatsUtil.block_window_frames(24)).is_equal(8)


## TEMPO=16 → int((32-16)*1.0+0.5)=int(16.5)=16.
func test_block_window_frames_tempo_16() -> void:
	assert_int(CharacterStatsUtil.block_window_frames(16)).is_equal(16)


## TEMPO=32 → int((32-32)*1.0+0.5)=int(0.5)=0 → clamp → 2.
func test_block_window_frames_floor_when_tempo_equals_base() -> void:
	assert_int(CharacterStatsUtil.block_window_frames(32)).is_equal(2)


## TEMPO=99 → negative raw → clamp → 2.
func test_block_window_frames_floor_when_tempo_exceeds_base() -> void:
	assert_int(CharacterStatsUtil.block_window_frames(99)).is_equal(2)


# --- Constants (TR-CSG-004) ---

## WINDOW_SCALE_FACTOR is 1.0 (accessibility default).
func test_window_scale_factor_default_value() -> void:
	assert_float(CharacterStatsUtil.WINDOW_SCALE_FACTOR).is_equal_approx(1.0, 0.0001)


## TIMING_WINDOW_FRAMES_MAX is 30.
func test_timing_window_frames_max_is_30() -> void:
	assert_int(CharacterStatsUtil.TIMING_WINDOW_FRAMES_MAX).is_equal(30)


## BLOCK_WINDOW_BASE is 32.
func test_block_window_base_is_32() -> void:
	assert_int(CharacterStatsUtil.BLOCK_WINDOW_BASE).is_equal(32)


## EFFECTIVE_FLUX_FLOOR is 8.
func test_effective_flux_floor_is_8() -> void:
	assert_int(CharacterStatsUtil.EFFECTIVE_FLUX_FLOOR).is_equal(8)
