## NamedInheritanceObject — one named inheritance applied to a character at guest departure.
## ADR-0001: Data-Driven Resource Registry Pattern. TR-CSG-005.
## Stored as a typed array on CharacterData. Append-only at runtime — never removed.
## class_name in standalone .gd required for Array[NamedInheritanceObject] and .tres round-trip.
class_name NamedInheritanceObject extends Resource

## Display name shown in the party stat screen (e.g. "Her Name's Gift").
## Combined with stat as the idempotency key in CharacterData.apply_inheritance().
@export var name: String = ""

## Stat this inheritance applies to (e.g. &"flux", &"atk", &"hp").
@export var stat: StringName = &""

## Magnitude of the increase. Always >= 1 after compute_inheritance_magnitude() floor.
## For FLUX: always >= CharacterStatsUtil.FLUX_INHERITANCE_MIN (2).
## For HP: added to base_hp (HP_max); hp_current is never modified.
@export var magnitude: int = 0
