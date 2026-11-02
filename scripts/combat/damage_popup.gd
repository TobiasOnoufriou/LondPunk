class_name DamagePopup
extends Label3D
## Floating combat number that rises, fades and frees itself.

@export var rise_height: float = 1.0
@export var duration: float = 0.9

var _tween: Tween


func _exit_tree() -> void:
    if _tween:
        _tween.kill()


## Shows [param value] in [param color] and starts the animation.
func play(value: String, color: Color) -> void:
    text = value
    modulate = color
    _tween = create_tween().set_parallel()
    _tween.tween_property(self, "position:y", position.y + rise_height, duration) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _tween.tween_property(self, "modulate:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
    _tween.chain().tween_callback(queue_free)
