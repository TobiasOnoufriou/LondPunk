extends Node
## Global signal hub (autoload: EventBus).
##
## Systems talk to each other through these signals instead of holding direct
## references, so UI, camera, and characters stay decoupled.

## Emitted when the player clicks a walkable world surface.
@warning_ignore("unused_signal")
signal ground_clicked(world_position: Vector3)

## Requests that the active camera centre on and follow [param target].
@warning_ignore("unused_signal")
signal camera_focus_requested(target: Node3D)

## Emitted when the player clicks a combat unit in the world.
@warning_ignore("unused_signal")
signal combatant_clicked(combatant: Combatant)

## Emitted when the player clicks something they can interact with (NPC, door...).
@warning_ignore("unused_signal")
signal interactable_clicked(interactable: Interactable)


# --- View ---

## Turns the see-through walls effect (occlusion cutout and near-camera fade) on or off.
@warning_ignore("unused_signal")
signal see_through_toggled(enabled: bool)

## Replaces the active see-through walls tuning, e.g. from an options menu.
@warning_ignore("unused_signal")
signal see_through_settings_changed(settings: SeeThroughSettings)


# --- Dialogue ---

## Emitted when a conversation with [param speaker] opens. Exploration input should pause.
@warning_ignore("unused_signal")
signal conversation_started(speaker: Node3D)

## Emitted when the conversation with [param speaker] closes.
@warning_ignore("unused_signal")
signal conversation_ended(speaker: Node3D)


# --- Combat: state broadcasts (CombatManager / Combatant -> anyone) ---

## Emitted once when a fight begins, with every participating unit.
@warning_ignore("unused_signal")
signal combat_started(combatants: Array[Combatant])

## Emitted when one side has been wiped out.
@warning_ignore("unused_signal")
signal combat_ended(party_won: bool)

## Emitted at the start of each round, before the first turn.
@warning_ignore("unused_signal")
signal round_started(round_number: int)

## Emitted whenever the initiative order is rebuilt.
@warning_ignore("unused_signal")
signal turn_order_changed(order: Array[Combatant])

## Emitted when [param combatant] begins its turn (AP already refilled).
@warning_ignore("unused_signal")
signal turn_started(combatant: Combatant)

## Emitted when [param combatant]'s turn is over.
@warning_ignore("unused_signal")
signal turn_ended(combatant: Combatant)

## Emitted when a unit's action points change.
@warning_ignore("unused_signal")
signal ap_changed(combatant: Combatant, current: int, maximum: int)

## Emitted when a unit's hit points change.
@warning_ignore("unused_signal")
signal hp_changed(combatant: Combatant, current: int, maximum: int)

## Emitted when a unit loses [param amount] hit points.
@warning_ignore("unused_signal")
signal combatant_damaged(combatant: Combatant, amount: int)

## Emitted when a unit is reduced to zero hit points.
@warning_ignore("unused_signal")
signal combatant_died(combatant: Combatant)

## Emitted when a unit gains or loses a status effect.
@warning_ignore("unused_signal")
signal status_changed(combatant: Combatant)

## Emitted when an ability starts resolving. Input should wait for [signal action_resolved].
@warning_ignore("unused_signal")
signal ability_used(user: Combatant, ability: Ability, target: AbilityTarget)

## Emitted when the ability started by [signal ability_used] has finished.
@warning_ignore("unused_signal")
signal action_resolved(user: Combatant)

## Emitted when the active unit's targeting ability changes. [param ability] may be null.
@warning_ignore("unused_signal")
signal ability_armed(user: Combatant, ability: Ability)

## A human-readable line for the combat log.
@warning_ignore("unused_signal")
signal combat_log_message(text: String)


# --- Combat: player requests (UI -> combat) ---

## The player picked an ability for the active unit.
@warning_ignore("unused_signal")
signal ability_selected(ability: Ability)

## The player backed out of the current targeting mode.
@warning_ignore("unused_signal")
signal ability_cancelled

## The player wants to end the active unit's turn.
@warning_ignore("unused_signal")
signal end_turn_requested

## The player dismissed the victory/defeat screen. Encounters clean up on this.
@warning_ignore("unused_signal")
signal combat_result_acknowledged(party_won: bool)
