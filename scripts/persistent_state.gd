class_name PersistentState
extends Node
## Remembered key/value state for its parent, kept by [SaveManager].
##
## Drop one in as a child of anything that should remember things (an NPC, an
## encounter, a door...) and give it a unique [member save_id]. The data is
## ready by the time the parent's [method Node._ready] runs, and every write
## goes straight into the save state.
##
## Dialogue can call these methods when the component is passed as a game
## state, e.g. [code]if knows("insulted")[/code] or [code]do remember("insulted")[/code].

## Unique, stable id for this state in save files, e.g. "bouncer".
## If empty, the node path is used, which breaks if the node is moved or renamed.
@export var save_id: String = ""

## The live remembered values. Prefer the methods below over writing it directly.
var data: Dictionary = {}

var _bound_id: String = ""


func _enter_tree() -> void:
	_bound_id = save_id
	if _bound_id.is_empty():
		_bound_id = str(get_path())
		push_warning("PersistentState at %s has no save_id; falling back to its node path." % _bound_id)
	data = SaveManager.bind_entity(_bound_id, self)


func _exit_tree() -> void:
	SaveManager.unbind_entity(_bound_id, self)


## Stores [param value] under [param key]. Values must be plain data, not Objects.
func remember(key: String, value: Variant = true) -> void:
	if not SaveManager.is_saveable(value):
		push_error("PersistentState %s: \"%s\" can't store an Object." % [_bound_id, key])
		return
	data[key] = value


## Returns the value stored under [param key], or [param default] if there is none.
func recall(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


## True if [param key] has been remembered, unless it was remembered as false.
func knows(key: String) -> bool:
	var value: Variant = data.get(key)
	if value is bool:
		return value
	return value != null


## Removes [param key].
func forget(key: String) -> void:
	data.erase(key)


## Adds [param by] to the number stored under [param key] (starting at 0) and returns it.
func increment(key: String, by: int = 1) -> int:
	var value: int = int(data.get(key, 0)) + by
	data[key] = value
	return value
