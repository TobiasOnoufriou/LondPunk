class_name CombatStats
extends Resource
## Combat numbers and ability loadout for a unit.
##
## Shared by every unit of the same type. When character classes exist they can
## build or supply one of these.

@export var display_name: String = "Unit"
@export var color: Color = Color.WHITE

@export_group("Stats")
@export var max_hp: int = 20
@export var max_ap: int = 6
## Higher acts earlier in the round.
@export var initiative: int = 10
## Scales weapon abilities such as Attack.
@export var attack_power: int = 2
## Scales tech abilities such as Technobolt.
@export var tech_power: int = 2
## Flat reduction to incoming damage.
@export var defense: int = 1

@export_group("Abilities")
## Shown in this order on the ability bar (hotkeys 1, 2, 3...).
@export var abilities: Array[Ability] = []
