class_name ActionPointsComponent
extends Node
## The per-turn action point budget every ability is paid from.

## Emitted whenever [member current_ap] changes.
signal ap_changed(current: int, maximum: int)

@export var max_ap: int = 6

var current_ap: int = 0


## Sets a new maximum and fills the pool.
func setup(maximum: int) -> void:
    max_ap = maximum
    refill()


## Fills the pool back to [member max_ap]. Called at the start of each turn.
func refill() -> void:
    current_ap = max_ap
    ap_changed.emit(current_ap, max_ap)


## True if [param cost] AP can be paid right now.
func can_afford(cost: int) -> bool:
    return cost <= current_ap


## Pays [param cost] AP. Returns false (and spends nothing) if it can't be afforded.
func spend(cost: int) -> bool:
    if not can_afford(cost):
        return false
    current_ap -= cost
    ap_changed.emit(current_ap, max_ap)
    return true
