class_name MoveMarker
extends Node3D
## Brief ground ring showing where a click-to-move order was issued.

@export var duration: float = 0.6
@export var start_scale: float = 1.4
@export var end_scale: float = 0.6

var _tween: Tween


func _ready() -> void:
    visible = false
    EventBus.ground_clicked.connect(_on_ground_clicked)


func _exit_tree() -> void:
    if _tween:
        _tween.kill()


func _on_ground_clicked(world_position: Vector3) -> void:
    if _tween:
        _tween.kill()

    global_position = world_position + Vector3.UP * 0.02
    scale = Vector3.ONE * start_scale
    visible = true

    _tween = create_tween()
    _tween.tween_property(self, "scale", Vector3.ONE * end_scale, duration) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_callback(hide)
