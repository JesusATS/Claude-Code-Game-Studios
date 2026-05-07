## EnemyData — stat and behaviour profile for an enemy combatant.
## ADR-0001: Data-Driven Resource Registry Pattern.
## Stored as .tres files under res://assets/data/enemies/.
class_name EnemyData extends Resource

## Stable StringName ID matching the .tres filename (e.g. &"enemy_goblin").
@export var id: StringName = &""

## Display name shown in HUD and enemy name plate.
@export var display_name: String = ""

## Maximum hit points.
@export var base_hp: int = 0

## Attack stat. Range 1–99 at design time.
@export var base_atk: int = 0

## Defence stat. Range 1–99 at design time.
@export var base_def: int = 0

## Speed stat. Range 1–99 at design time.
@export var base_spd: int = 0

## TEMPO stat — drives block timing window width (Formula 2b). Range 1–99.
## TEMPO exists ONLY on EnemyData, NOT on CharacterData (AC-25).
@export var base_tempo: int = 0

## Action rules — list of Resource entries defining this enemy's behaviour.
## Typed as Array[Resource] for Inspector compatibility; cast to EnemyActionRule at runtime.
@export var action_rules: Array[Resource] = []

## SFX ID played when this enemy is incapacitated.
@export var sfx_incapacitated_id: StringName = &""
