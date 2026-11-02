class_name DamagePopupSpawner
extends Node3D
## Spawns a DamagePopup above any unit that takes damage.

@export var popup_scene: PackedScene
@export var height: float = 2.2
@export var damage_color: Color = Color(1.0, 0.85, 0.3)


func _ready() -> void:
    EventBus.combatant_damaged.connect(_on_combatant_damaged)


func _on_combatant_damaged(combatant: Combatant, amount: int) -> void:
    var popup: DamagePopup = popup_scene.instantiate()
    add_child(popup)
    # A little sideways jitter so back-to-back hits don't overlap.
    var jitter: Vector3 = Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
    popup.global_position = combatant.global_position + Vector3.UP * height + jitter
    popup.play(str(amount), damage_color)
