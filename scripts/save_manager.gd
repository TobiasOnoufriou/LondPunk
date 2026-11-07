extends Node
## Global game state and save files (autoload: SaveManager).
##
## Everything that should be remembered lives in one dictionary here. Nodes
## don't copy state in and out: a [PersistentState] component binds to its
## entry and writes straight into it, so the state survives scene changes and
## saving is just writing the dictionary to disk. Loading replaces the
## dictionary and reloads the saved level, and every node reads its state
## again in [method Node._ready].
##
## Values must be plain data (bool, int, float, String, StringName, vectors,
## colours, arrays, dictionaries). Objects are not saved.

## Emitted just before the state is saved or checkpointed. Fill in anything
## that isn't written as it changes (e.g. positions, see [PersistentTransform]).
signal saving

## Emitted after a save file has been read, before its level reloads.
signal loaded

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const QUICK_SLOT: String = "quick"

var _state: Dictionary = {}
## Snapshot taken when a fight starts, restored if the party loses.
var _checkpoint: Dictionary = {}
## Which node currently owns each entity id, to catch duplicate ids.
var _bound: Dictionary[String, Node] = {}
## True from combat_started until the result is acknowledged. Fights aren't
## saveable (combatants, HP, the hidden Player), so saving is blocked.
var _in_combat: bool = false


func _init() -> void:
	# Set up in _init, not _ready, so the state exists before any
	# PersistentState binds in _enter_tree, however early that happens.
	new_game()


func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_result_acknowledged.connect(_on_combat_result_acknowledged)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_game(QUICK_SLOT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_game(QUICK_SLOT)
		get_viewport().set_input_as_handled()


# --- State ---

## Clears all remembered state.
func new_game() -> void:
	_state = {
		"version": SAVE_VERSION,
		"level": "",
		"flags": {},
		"entities": {},
	}
	_checkpoint = {}
	_in_combat = false


## Returns the live state dictionary for [param id], creating it if needed.
## Writes to it are remembered; prefer [PersistentState] over calling this directly.
func get_entity(id: String) -> Dictionary:
	var entities: Dictionary = _state.get_or_add("entities", {})
	return entities.get_or_add(id, {})


## Called by [PersistentState] when it enters the tree. Warns about duplicate ids.
func bind_entity(id: String, owner_node: Node) -> Dictionary:
	if _bound.has(id) and is_instance_valid(_bound[id]) and _bound[id] != owner_node:
		push_warning("SaveManager: save_id \"%s\" is used by both %s and %s." % [
			id, _bound[id].get_path(), owner_node.get_path()])
	_bound[id] = owner_node
	return get_entity(id)


## Called by [PersistentState] when it leaves the tree.
func unbind_entity(id: String, owner_node: Node) -> void:
	if _bound.get(id) == owner_node:
		_bound.erase(id)


## Sets a world/quest flag, e.g. from dialogue: [code]do SaveManager.set_flag("found_club")[/code].
func set_flag(flag: String, value: Variant = true) -> void:
	if not is_saveable(value):
		push_error("SaveManager: flag \"%s\" can't store an Object." % flag)
		return
	_flags()[flag] = value


## Returns a world/quest flag, or [param default] if it was never set.
func get_flag(flag: String, default: Variant = false) -> Variant:
	return _flags().get(flag, default)


## True if the world/quest flag has been set (to any value).
func has_flag(flag: String) -> bool:
	return _flags().has(flag)


func _flags() -> Dictionary:
	return _state.get_or_add("flags", {})


## True if [param value] can go in a save file.
func is_saveable(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			return (value as Array).all(is_saveable)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			return dict.keys().all(is_saveable) and dict.values().all(is_saveable)
	return true


# --- Files ---

## Writes the current state to [param slot]. Returns OK on success.
func save_game(slot: String = QUICK_SLOT) -> Error:
	if _in_combat:
		push_warning("SaveManager: can't save during combat.")
		return ERR_BUSY
	saving.emit()
	var scene: Node = get_tree().current_scene
	_state["level"] = scene.scene_file_path if scene else ""

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file: FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if not file:
		push_error("SaveManager: can't write %s (%s)." % [_slot_path(slot), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	# from_native keeps Godot types (ints stay ints, Vector3s stay Vector3s).
	file.store_string(JSON.stringify(JSON.from_native(_state), "\t"))
	print("SaveManager: saved to %s" % _slot_path(slot))
	return OK


## Reads [param slot] and reloads its level. Returns OK on success.
func load_game(slot: String = QUICK_SLOT) -> Error:
	if not has_save(slot):
		push_warning("SaveManager: no save in slot \"%s\"." % slot)
		return ERR_FILE_NOT_FOUND
	var text: String = FileAccess.get_file_as_string(_slot_path(slot))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_NIL:
		push_error("SaveManager: %s is not valid JSON." % _slot_path(slot))
		return ERR_PARSE_ERROR
	# Objects stay disallowed, so a save file can never create nodes or run scripts.
	var state: Variant = JSON.to_native(parsed)
	if typeof(state) != TYPE_DICTIONARY:
		push_error("SaveManager: %s has an unexpected layout." % _slot_path(slot))
		return ERR_INVALID_DATA

	_state = _migrate(state)
	_checkpoint = {}
	_in_combat = false
	loaded.emit()
	_reload_level(_state["level"])
	print("SaveManager: loaded %s" % _slot_path(slot))
	return OK


## True if [param slot] has a save file.
func has_save(slot: String = QUICK_SLOT) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]


## Upgrades older save layouts. Add a step here whenever SAVE_VERSION goes up.
func _migrate(state: Dictionary) -> Dictionary:
	var version: int = state.get("version", 0)
	if version > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer version (%d)." % version)
	for key: String in ["flags", "entities"]:
		if typeof(state.get(key)) != TYPE_DICTIONARY:
			state[key] = {}
	state["version"] = SAVE_VERSION
	return state


func _reload_level(level_path: String) -> void:
	if not level_path.is_empty() and ResourceLoader.exists(level_path):
		get_tree().change_scene_to_file(level_path)
	else:
		get_tree().reload_current_scene()


# --- Checkpoints ---

## Remembers the current state so [method restore_checkpoint] can return to it.
## Call it before a fight changes the scene (e.g. hides the Player), so
## positions are captured as they were.
func checkpoint() -> void:
	saving.emit()
	_checkpoint = _state.duplicate(true)


## Goes back to the last checkpoint (or just reloads if there isn't one).
func restore_checkpoint() -> void:
	if not _checkpoint.is_empty():
		_state = _checkpoint
		_checkpoint = {}
	get_tree().reload_current_scene()


func _on_combat_started(_combatants: Array[Combatant]) -> void:
	_in_combat = true
	# Fallback for fights that didn't checkpoint before starting.
	if _checkpoint.is_empty():
		checkpoint()


func _on_combat_result_acknowledged(party_won: bool) -> void:
	_in_combat = false
	if party_won:
		_checkpoint = {}
	else:
		restore_checkpoint()
