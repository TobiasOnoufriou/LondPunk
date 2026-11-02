class_name HealthComponent
extends Node
## Tracks hit points for its owner and reports changes.

## Emitted whenever [member current_hp] changes.
signal hp_changed(current: int, maximum: int)
## Emitted once when hit points reach zero.
signal died

@export var max_hp: int = 20

var current_hp: int = 0


func _ready() -> void:
    current_hp = max_hp


## Resets to full health with a new maximum.
func setup(maximum: int) -> void:
    max_hp = maximum
    current_hp = maximum
    hp_changed.emit(current_hp, max_hp)


## True once hit points have reached zero.
func is_dead() -> bool:
    return current_hp <= 0


## Removes up to [param amount] hit points and returns how many were actually lost.
func take_damage(amount: int) -> int:
    if is_dead() or amount <= 0:
        return 0
    var dealt: int = mini(amount, current_hp)
    current_hp -= dealt
    hp_changed.emit(current_hp, max_hp)
    if current_hp == 0:
        died.emit()
    return dealt


## Restores up to [param amount] hit points and returns how many were actually gained.
func heal(amount: int) -> int:
    if is_dead() or amount <= 0:
        return 0
    var healed: int = mini(amount, max_hp - current_hp)
    current_hp += healed
    hp_changed.emit(current_hp, max_hp)
    return healed
