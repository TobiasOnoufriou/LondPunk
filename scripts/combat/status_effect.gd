class_name StatusEffect
extends Resource
## A temporary modifier on a unit, such as Guarded.
##
## Assets in data/status are templates; [method Combatant.add_status] stores a
## duplicate so each unit tracks its own remaining duration.

@export var id: StringName = &""
@export var display_name: String = ""
## Turns of the affected unit it lasts. Ticks down at the start of each of its turns.
@export var duration_turns: int = 1
## Multiplies incoming damage. 0.5 halves it.
@export var damage_taken_multiplier: float = 1.0

var remaining_turns: int = 0
