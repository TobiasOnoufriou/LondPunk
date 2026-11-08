class_name CombatEncounter
extends Node3D
## A fight that breaks out in place, in an exploration level.
##
## On [method start] the listed NPCs are swapped for enemy Combatants where they
## stand, each [EncounterSpawnPoint] child spawns its unit, the exploration
## Player steps aside, and [member combat_manager] runs the fight. After a win
## the party is cleared away and the Player returns where the lead unit ended up.
## Runs once, and [member state] remembers that across saves. Defeat is
## handled by SaveManager restoring its pre-fight checkpoint.

@export var combat_manager: CombatManager
@export var combatant_scene: PackedScene
## World NPCs that turn into enemies. They need [member NPC.combat_stats].
@export var npc_combatants: Array[NPC] = []
## The exploration Player to hide during the fight and restore afterwards.
@export var player: PlayerController
## Remembers whether this fight has been won. Give it a unique save_id per encounter.
@export var state: PersistentState

## True once this encounter has been won.
var is_completed: bool:
	get:
		return state.knows("completed")
	set(value):
		state.remember("completed", value)

var _is_running: bool = false
var _party: Array[Combatant] = []


func _ready() -> void:
	EventBus.combat_result_acknowledged.connect(_on_combat_result_acknowledged)


## Spawns every participant and begins combat. Ignored if already fought or another fight is on.
func start() -> void:
	if _is_running or is_completed or combat_manager.is_running:
		return
	_is_running = true
	# Before anyone is hidden, so losing puts everyone back where they stood.
	SaveManager.checkpoint()

	for npc: NPC in npc_combatants:
		if not npc.combat_stats:
			push_warning("%s: NPC %s has no combat_stats, skipping." % [name, npc.name])
			continue
		_spawn(npc.combat_stats, Combatant.Faction.ENEMY, npc.display_name, npc.global_transform)
		npc.leave_for_combat()

	for child: Node in get_children():
		if child is EncounterSpawnPoint:
			var point: EncounterSpawnPoint = child as EncounterSpawnPoint
			_spawn(point.stats, point.faction, point.display_name_override, point.global_transform)

	if player:
		player.set_active(false)
	combat_manager.start_combat()


func _spawn(stats: CombatStats, faction: Combatant.Faction, display_name: String, xform: Transform3D) -> Combatant:
	var unit: Combatant = combatant_scene.instantiate() as Combatant
	unit.stats = stats
	unit.faction = faction
	unit.display_name_override = display_name
	var root: Node = combat_manager.party_root if faction == Combatant.Faction.PARTY else combat_manager.enemy_root
	root.add_child(unit)
	unit.global_transform = xform
	if faction == Combatant.Faction.PARTY:
		_party.append(unit)
	return unit


## The first party unit still standing, which the Player takes the place of.
func _lead_unit() -> Combatant:
	for unit: Combatant in _party:
		if unit.is_alive():
			return unit
	return _party[0] if not _party.is_empty() else null


func _on_combat_result_acknowledged(party_won: bool) -> void:
	if not _is_running or not party_won:
		return
	_is_running = false
	is_completed = true
	for npc: NPC in npc_combatants:
		npc.mark_defeated()

	if player:
		var lead: Combatant = _lead_unit()
		if lead:
			player.teleport(lead.global_position)
		player.set_active(true)
		EventBus.camera_focus_requested.emit(player)

	# Enemy bodies stay in the world as the aftermath; the party goes back to being the Player.
	for unit: Combatant in _party:
		unit.queue_free()
	_party.clear()
