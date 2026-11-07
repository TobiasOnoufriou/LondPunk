class_name CombatManager
extends Node
## Runs a turn-based fight: builds the initiative order, hands each turn to the
## player or AI controller, and is the single entry point for using abilities.

## Internal: emitted to release the turn loop when the active unit's turn ends.
signal _turn_finished

@export var party_root: Node
@export var enemy_root: Node
@export var player_controller: PlayerTurnController
@export var ai_controller: AITurnController
## Breather between turns so the camera and UI can catch up.
@export var turn_gap: float = 0.4

var combatants: Array[Combatant] = []
var turn_order: Array[Combatant] = []
var active_combatant: Combatant
var round_number: int = 0
## True while an ability is resolving. Input should be ignored until it clears.
var busy: bool = false
var is_running: bool = false

## Units that went down during the action currently resolving, logged once it finishes.
var _fallen: Array[Combatant] = []


func _ready() -> void:
    EventBus.combatant_died.connect(_on_combatant_died)


## Collects the units under [member party_root] and [member enemy_root] and starts the fight.
## Can be called again for a new fight once the previous one has ended.
func start_combat() -> void:
    if is_running:
        return
    combatants.clear()
    turn_order.clear()
    active_combatant = null
    round_number = 0
    busy = false
    _fallen.clear()
    for root: Node in [party_root, enemy_root]:
        for child: Node in root.get_children():
            if child is Combatant:
                combatants.append(child as Combatant)

    is_running = true
    EventBus.combat_started.emit(combatants)
    EventBus.combat_log_message.emit("Combat begins!")
    _run_rounds()


## Ends [param unit]'s turn. Ignored if it isn't [param unit]'s turn or an ability is resolving.
func end_turn(unit: Combatant) -> void:
    if unit != active_combatant or busy:
        return
    _turn_finished.emit()


## Uses [param ability] from [param user] on [param target] if it's legal.
## Returns true if the ability was performed. Await it to wait for it to resolve.
func perform(user: Combatant, ability: Ability, target: AbilityTarget) -> bool:
    if not is_running or busy or user != active_combatant:
        return false

    var reason: String = ability.validate(user, target)
    if not reason.is_empty():
        EventBus.combat_log_message.emit(reason)
        return false
    var cost: int = ability.get_ap_cost(user, target)
    if not user.action_points.can_afford(cost):
        EventBus.combat_log_message.emit("Not enough AP for %s (needs %d)." % [ability.display_name, cost])
        return false

    busy = true
    user.action_points.spend(cost)
    EventBus.ability_used.emit(user, ability, target)
    await ability.execute(user, target)
    for unit: Combatant in _fallen:
        EventBus.combat_log_message.emit("%s is down!" % unit.get_display_name())
    _fallen.clear()
    busy = false
    EventBus.action_resolved.emit(user)

    if _check_combat_over():
        return true
    if user.action_points.current_ap <= 0 or not user.is_alive():
        end_turn(user)
    return true


func _run_rounds() -> void:
    while is_running:
        round_number += 1
        _build_turn_order()
        EventBus.round_started.emit(round_number)
        EventBus.combat_log_message.emit("--- Round %d ---" % round_number)

        for unit: Combatant in turn_order:
            if not is_running:
                return
            if unit.is_alive():
                await _take_turn(unit)


func _take_turn(unit: Combatant) -> void:
    active_combatant = unit
    unit.start_turn()
    unit.set_selected(true)
    EventBus.camera_focus_requested.emit(unit)
    EventBus.turn_started.emit(unit)

    if unit.faction == Combatant.Faction.PARTY:
        player_controller.begin_turn(unit)
    else:
        ai_controller.begin_turn(unit)
    await _turn_finished

    # Cleared before the gap so a controller still looping sees its turn is over.
    active_combatant = null
    unit.set_selected(false)
    EventBus.turn_ended.emit(unit)
    if is_running:
        await get_tree().create_timer(turn_gap).timeout


func _build_turn_order() -> void:
    turn_order.assign(combatants.filter(func(unit: Combatant) -> bool: return unit.is_alive()))
    turn_order.sort_custom(_acts_before)
    EventBus.turn_order_changed.emit(turn_order)


## Higher initiative first; the party wins ties.
func _acts_before(a: Combatant, b: Combatant) -> bool:
    if a.stats.initiative != b.stats.initiative:
        return a.stats.initiative > b.stats.initiative
    return a.faction == Combatant.Faction.PARTY and b.faction != Combatant.Faction.PARTY


func _check_combat_over() -> bool:
    var party_alive: bool = _faction_alive(Combatant.Faction.PARTY)
    var enemies_alive: bool = _faction_alive(Combatant.Faction.ENEMY)
    if party_alive and enemies_alive:
        return false

    is_running = false
    if active_combatant:
        active_combatant.set_selected(false)
    EventBus.combat_log_message.emit("Victory!" if party_alive else "Defeat...")
    EventBus.combat_ended.emit(party_alive)
    # Release the turn loop so it can exit.
    _turn_finished.emit()
    return true


func _on_combatant_died(unit: Combatant) -> void:
    _fallen.append(unit)


func _faction_alive(faction: Combatant.Faction) -> bool:
    return combatants.any(func(unit: Combatant) -> bool:
        return unit.faction == faction and unit.is_alive())
