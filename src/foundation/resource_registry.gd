## ResourceRegistry — Autoload singleton (position 2 in Project Settings).
## Loads all game data at startup from res://assets/data/.
## Runtime systems read data by StringName ID; never hold mutable references to registry entries.
## ADR-0001: Data-Driven Resource Registry Pattern.
class_name ResourceRegistry extends Node

## Internal character data store. Keyed by CharacterData.id.
var _characters: Dictionary[StringName, CharacterData] = {}

## True once _load_characters() has completed — set regardless of whether any data was found.
var _loaded: bool = false

func _ready() -> void:
	_load_characters()


## Load all .tres files from res://assets/data/characters/.
## Called once at startup. Never called at runtime.
func _load_characters() -> void:
	var dir := DirAccess.open("res://assets/data/characters/")
	if dir == null:
		push_error("ResourceRegistry: res://assets/data/characters/ not found.")
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := "res://assets/data/characters/" + file_name
			var res: Resource = ResourceLoader.load(path)
			if res is CharacterData:
				var char_data := res as CharacterData
				_characters[char_data.id] = char_data
			else:
				push_warning("ResourceRegistry: %s did not deserialise to CharacterData." % path)
		file_name = dir.get_next()
	dir.list_dir_end()
	_loaded = true


## Returns the read-only registry entry for a character.
## Never mutate the returned object. Use get_character_copy() for encounter-scoped copies.
func get_character(id: StringName) -> CharacterData:
	if not _characters.has(id):
		push_error("ResourceRegistry.get_character: unknown id '%s'" % id)
		return null
	return _characters[id]


## Returns a deep copy of a character suitable for mutation during an encounter.
## The copy is independent — changes do not affect the registry entry.
func get_character_copy(id: StringName) -> CharacterData:
	var original: CharacterData = get_character(id)
	if original == null:
		return null
	var copy: CharacterData = original.duplicate_deep() as CharacterData
	copy.hp_current = copy.base_hp
	return copy


## Returns true once _load_characters() has completed (regardless of how many records were found).
func is_initialized() -> bool:
	return _loaded


## Returns all registered character IDs as an Array[StringName].
func get_character_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_characters.keys())
	return ids
