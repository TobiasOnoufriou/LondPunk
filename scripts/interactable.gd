class_name Interactable
extends Area3D
## Clickable component for anything the player can walk up to and use.
##
## CameraRig reports clicks on it via [signal EventBus.interactable_clicked]; the
## player walks within [member interact_range] and calls [method interact]. The
## owning node (NPC, door, loot...) listens to [signal interacted].

## Emitted when [param interactor] uses this.
signal interacted(interactor: Node3D)

## How close (flat distance, metres) the interactor has to be.
@export var interact_range: float = 1.8
## Disabled interactables can't be clicked or used.
@export var enabled: bool = true:
    set(value):
        enabled = value
        _apply_enabled()

var _layer: int = 0


func _ready() -> void:
    _layer = collision_layer
    monitoring = false
    _apply_enabled()


## Uses this on behalf of [param interactor]. Ignored while disabled.
func interact(interactor: Node3D) -> void:
    if enabled:
        interacted.emit(interactor)


## True if [param point] is close enough to use this.
func is_in_range(point: Vector3) -> bool:
    var flat: Vector3 = global_position - point
    flat.y = 0.0
    return flat.length() <= interact_range


func _apply_enabled() -> void:
    if not is_node_ready():
        return
    # Dropping off the layer keeps click rays from hitting it.
    collision_layer = _layer if enabled else 0
