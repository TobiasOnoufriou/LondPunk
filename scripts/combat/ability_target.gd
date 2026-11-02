class_name AbilityTarget
extends RefCounted
## What an ability is aimed at: a unit, or a point on the ground.

var combatant: Combatant
var position: Vector3 = Vector3.ZERO
## Scratch space for abilities that plan ahead, e.g. the clamped path of a Move.
var path: PackedVector3Array = PackedVector3Array()


## A target aimed at [param unit].
static func at_combatant(unit: Combatant) -> AbilityTarget:
    var target: AbilityTarget = AbilityTarget.new()
    target.combatant = unit
    target.position = unit.global_position
    return target


## A target aimed at a world position.
static func at_position(world_position: Vector3) -> AbilityTarget:
    var target: AbilityTarget = AbilityTarget.new()
    target.position = world_position
    return target


## Where the target currently is in the world.
func get_position() -> Vector3:
    return combatant.global_position if combatant else position
