## CharacterData — base stat block for a party member or guest character.
## ADR-0001: Data-Driven Resource Registry Pattern.
## All base values live in .tres files under res://assets/data/characters/.
## Runtime-only fields (hp_current) are NOT @export — set by TCS at encounter start.
class_name CharacterData extends Resource

## Stable StringName ID — must match the .tres filename convention (e.g. &"char_clawd").
@export var id: StringName = &""

## Display name shown in HUD and menus.
@export var display_name: String = ""

## Maximum hit points. Positive integer. hp_current is tracked at runtime by TCS.
@export var base_hp: int = 0

## Attack stat. Range 1–99 at design time.
@export var base_atk: int = 0

## Defence stat. Range 1–99 at design time.
@export var base_def: int = 0

## Speed stat. Range 1–99 at design time.
@export var base_spd: int = 0

## FLUX stat — drives attack timing window width (Formula 2a). Range 1–99.
## NOTE: TEMPO is NOT on CharacterData. TEMPO is an EnemyData-only field (AC-25).
@export var base_flux: int = 0

## Perfect-hit damage multiplier (e.g. 1.3 = 130% damage on a perfect hit).
@export var perfect_hit_multiplier: float = 1.0

## Ability IDs available to this character. Each entry is a StringName matching an AbilityData.id.
@export var base_abilities: Array[StringName] = []

## Runtime HP — NOT serialised in .tres. Set by TCS from base_hp at encounter start.
## Not @export so it never appears in the Inspector or .tres file.
var hp_current: int = 0

## Named inheritances applied to this character — appended at guest departure, never removed.
## Callers compute inheritance_sum by summing magnitude values of relevant entries here.
## Managed exclusively via apply_inheritance(). — TR-CSG-005.
@export var inheritances: Array[NamedInheritanceObject] = []

## Accent color for inheritance entry rendering and guest portrait border.
## Set in the character's .tres data file. Core party members default to Color.WHITE (unused).
@export var accent_color: Color = Color.WHITE


## Appends a Named Inheritance Object to this character's inheritance list.
## Idempotent: duplicate name+stat is silently ignored (warning pushed).
## HP inheritances raise base_hp (HP_max only); hp_current is never modified.
## Sole call site: Guest Character System departure handler. — ADR-0001, TR-CSG-005.
##
## Example:
##   var nio := NamedInheritanceObject.new()
##   nio.name = "Her Name's Gift"; nio.stat = &"flux"; nio.magnitude = 3
##   char_data.apply_inheritance(nio)  # char_data.inheritances.size() == 1
func apply_inheritance(nio: NamedInheritanceObject) -> void:
	for existing: NamedInheritanceObject in inheritances:
		if existing.stat == nio.stat and existing.name == nio.name:
			push_warning("CharacterData.apply_inheritance: duplicate '%s'/'%s' — ignoring." \
					% [nio.name, nio.stat])
			return
	inheritances.append(nio)
	if nio.stat == &"hp":
		base_hp += nio.magnitude


## Serializes runtime character state to a flat Dictionary with String keys.
## Keys use String (not StringName or int) for JSON round-trip safety.
## The Save System is the sole caller — this method does not perform file I/O.
## base_abilities is excluded: static config is reloaded from .tres at startup.
##
## Example:
##   var data := char_data.serialize()
##   # data["character_id"] == "char_ne"
##   # data["inheritances"] == [{"name": "Her Name's Gift", "stat": "flux", "magnitude": 3}]
func serialize() -> Dictionary:
	var nio_list: Array[Dictionary] = []
	for nio: NamedInheritanceObject in inheritances:
		nio_list.append({
			"name": nio.name,
			"stat": String(nio.stat),
			"magnitude": nio.magnitude
		})
	return {
		"character_id": String(id),
		"base_hp": base_hp,
		"hp_current": hp_current,
		"base_atk": base_atk,
		"base_def": base_def,
		"base_spd": base_spd,
		"base_flux": base_flux,
		"perfect_hit_multiplier": perfect_hit_multiplier,
		"inheritances": nio_list,
		"accent_color": accent_color.to_html(),
	}


## Reconstructs runtime character state from a serialized Dictionary.
## Counterpart to serialize(). Clears and rebuilds the inheritances array.
## The Save System is the sole caller — this method does not perform file I/O.
## Callers must reload base_abilities from ResourceRegistry after deserializing.
##
## Example:
##   var char_data2 := CharacterData.new()
##   char_data2.deserialize(data)
##   # char_data2.hp_current == 40 (not base_hp)
func deserialize(data: Dictionary) -> void:
	id = StringName(data.get("character_id", ""))
	base_hp = data.get("base_hp", 0)
	hp_current = data.get("hp_current", base_hp)
	base_atk = data.get("base_atk", 0)
	base_def = data.get("base_def", 0)
	base_spd = data.get("base_spd", 0)
	base_flux = data.get("base_flux", 0)
	perfect_hit_multiplier = data.get("perfect_hit_multiplier", 1.0)
	inheritances.clear()
	accent_color = Color.from_string(data.get("accent_color", "ffffffff"), Color.WHITE)
	for entry: Dictionary in data.get("inheritances", []):
		var nio := NamedInheritanceObject.new()
		nio.name = entry.get("name", "")
		nio.stat = StringName(entry.get("stat", ""))
		nio.magnitude = entry.get("magnitude", 0)
		inheritances.append(nio)
