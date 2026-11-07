class_name PersistentTransform
extends Node
## Saves where its [member target] stands and which way it faces.
##
## Positions change all the time, so they're only written when the game is
## saved or checkpointed ([signal SaveManager.saving]), not on every move. The
## data goes into [member state] under "transform", so it shares the owner's
## existing save entry, and it's only restored in the level it was saved in.

## The node to save. Defaults to the parent.
@export var target: Node3D
## Where to store the transform, e.g. the owner's Memory component.
@export var state: PersistentState

const KEY: String = "transform"


func _ready() -> void:
    if not target:
        target = get_parent() as Node3D
    if not target or not state:
        push_error("PersistentTransform %s needs a Node3D target and a PersistentState." % get_path())
        return
    _restore()
    SaveManager.saving.connect(_on_saving)


func _restore() -> void:
    var saved: Variant = state.recall(KEY)
    if typeof(saved) != TYPE_DICTIONARY or saved.get("level", "") != _current_level():
        return
    var position: Variant = saved.get("position")
    if position is Vector3:
        if target.has_method("teleport"):
            # Lets the target reset anything tied to its position, like a nav path.
            target.teleport(position)
        else:
            target.global_position = position
    target.rotation.y = float(saved.get("yaw", target.rotation.y))


func _on_saving() -> void:
    # Hidden targets (a defeated NPC) keep their last saved transform.
    if not target.is_inside_tree() or not target.is_visible_in_tree():
        return
    state.remember(KEY, {
        "level": _current_level(),
        "position": target.global_position,
        "yaw": target.rotation.y,
    })


func _current_level() -> String:
    var scene: Node = get_tree().current_scene
    return scene.scene_file_path if scene else ""
