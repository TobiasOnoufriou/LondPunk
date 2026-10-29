extends Node
## Global signal hub (autoload: EventBus).
##
## Systems talk to each other through these signals instead of holding direct
## references, so UI, camera, and characters stay decoupled.

## Emitted when the player clicks a walkable world surface.
@warning_ignore("unused_signal")
signal ground_clicked(world_position: Vector3)

## Requests that the active camera centre on and follow [param target].
@warning_ignore("unused_signal")
signal camera_focus_requested(target: Node3D)
