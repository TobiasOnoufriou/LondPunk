class_name EncounterSpawnPoint
extends Marker3D
## Where a [CombatEncounter] spawns one Combatant when the fight starts.
##
## Used for party slots and for extra enemies that aren't standing in the world
## as NPCs beforehand. The marker's transform becomes the unit's.

@export var stats: CombatStats
@export var faction: Combatant.Faction = Combatant.Faction.PARTY
## Overrides [member CombatStats.display_name], e.g. "Bouncer's Mate".
@export var display_name_override: String = ""
