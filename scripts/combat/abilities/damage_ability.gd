class_name DamageAbility
extends Ability
## Deals damage to a single target. Backs both weapon attacks and damage spells.

enum ScalingStat { ATTACK, TECH }

@export var base_damage: int = 4
## Which of the user's stats is added to [member base_damage].
@export var scaling_stat: ScalingStat = ScalingStat.ATTACK
## Fraction of the target's defense that is ignored.
@export_range(0.0, 1.0) var defense_penetration: float = 0.0
## Random spread around the rolled value. 0.2 means +/-20%.
@export_range(0.0, 1.0) var damage_variance: float = 0.2
@export var damage_type: StringName = &"physical"
## Pause before the hit lands, so the turn reads clearly.
@export var windup_time: float = 0.3


## Rolls the damage [param user] would deal to [param victim], before status effects.
func roll_damage(user: Combatant, victim: Combatant) -> int:
    var power: int = user.stats.attack_power
    if scaling_stat == ScalingStat.TECH:
        power = user.stats.tech_power
    var spread: float = randf_range(1.0 - damage_variance, 1.0 + damage_variance)
    var effective_defense: float = victim.stats.defense * (1.0 - defense_penetration)
    return maxi(1, roundi((base_damage + power) * spread - effective_defense))


func execute(user: Combatant, target: AbilityTarget) -> void:
    var victim: Combatant = target.combatant
    user.face_towards(victim.global_position)
    await user.get_tree().create_timer(windup_time).timeout

    var dealt: int = victim.receive_damage(roll_damage(user, victim))
    EventBus.combat_log_message.emit("%s uses %s on %s for %d damage." % [
        user.get_display_name(), display_name, victim.get_display_name(), dealt])
