class_name NPC
extends Node3D
## A character the player can talk to with Dialogue Manager, and optionally fight.
##
## The NPC passes itself and its [member memory] to the dialogue as game states,
## so any `.dialogue` file can read their properties and call their public
## methods, e.g.:
## [codeblock]
## if knows("met")
##     Bouncer: You again.
## Bouncer: Your funeral.
## do start_combat()
## [/codeblock]
## Combat starts once the balloon closes, through [member encounter].
##
## Facts the NPC records in [member memory] itself: "met", "times_talked",
## "fought" and "defeated". Dialogue can add any others with remember().

@export var display_name: String = "Stranger"
@export var dialogue: DialogueResource
## The dialogue title to start from.
@export var dialogue_cue: String = "start"
## What this NPC fights as when an encounter turns it into a Combatant.
@export var combat_stats: CombatStats
## The fight [method start_combat] kicks off. Leave empty for peaceful NPCs.
@export var encounter: CombatEncounter
@export var body_color: Color = Color(0.6, 0.6, 0.65)

@export_group("Components")
@export var interactable: Interactable
@export var body_mesh: MeshInstance3D
@export var name_label: Label3D
## What this NPC remembers. Give it a unique save_id per NPC.
@export var memory: PersistentState

## True once this NPC has been in a fight. Readable from dialogue.
var has_fought: bool:
	get:
		return memory.knows("fought")

var _is_talking: bool = false
var _combat_pending: bool = false


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = body_color
	body_mesh.material_override = material
	name_label.text = display_name

	interactable.interacted.connect(_on_interacted)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	if memory.knows("defeated"):
		_remove_from_world()


## Dialogue API: starts [member encounter] once the conversation closes.
func start_combat() -> void:
	if not encounter:
		push_warning("%s: start_combat() called with no encounter assigned." % name)
		return
	_combat_pending = true


## Called by [CombatEncounter] when this NPC is swapped for a Combatant.
func leave_for_combat() -> void:
	memory.remember("fought")
	_remove_from_world()


## Called by [CombatEncounter] when the party wins. The NPC stays gone after loading.
func mark_defeated() -> void:
	memory.remember("defeated")


func _remove_from_world() -> void:
	interactable.enabled = false
	hide()


func _start_conversation() -> void:
	if not dialogue or _is_talking:
		return
	_is_talking = true
	EventBus.conversation_started.emit(self)
	EventBus.camera_focus_requested.emit(self)
	DialogueManager.show_dialogue_balloon(dialogue, dialogue_cue, [self, memory])


func _on_interacted(interactor: Node3D) -> void:
	if interactor:
		_face_towards(interactor.global_position)
	_start_conversation()


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if not _is_talking or resource != dialogue:
		return
	_is_talking = false
	# Recorded after the conversation so the first one still sees "not met".
	memory.remember("met")
	memory.increment("times_talked")
	EventBus.conversation_ended.emit(self)
	if _combat_pending:
		_combat_pending = false
		encounter.start()


func _face_towards(world_position: Vector3) -> void:
	var flat: Vector3 = world_position - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.0001:
		# The model faces -Z.
		rotation.y = atan2(-flat.x, -flat.z)
