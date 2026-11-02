class_name ApplyStatusAbility
extends Ability
## Applies a status effect to the target (or to the user for SELF abilities).
## Defend uses this with the Guarded effect.

@export var status: StatusEffect


func execute(user: Combatant, target: AbilityTarget) -> void:
    var recipient: Combatant = target.combatant if target.combatant else user
    recipient.add_status(status)
    if recipient == user:
        EventBus.combat_log_message.emit("%s uses %s." % [user.get_display_name(), display_name])
    else:
        EventBus.combat_log_message.emit("%s uses %s on %s." % [
            user.get_display_name(), display_name, recipient.get_display_name()])
