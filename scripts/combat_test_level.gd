extends Node3D
## Graybox arena that starts a test fight as soon as it loads.

@export var nav_region: NavigationRegion3D
@export var combat_manager: CombatManager


func _ready() -> void:
    EventBus.combat_result_acknowledged.connect(_on_combat_result_acknowledged)
    # Bakes at runtime so the navmesh always matches the arena geometry.
    if nav_region:
        nav_region.bake_navigation_mesh(false)
    # The navigation map only picks up the new mesh on a later physics frame.
    await get_tree().physics_frame
    await get_tree().physics_frame
    combat_manager.start_combat()


func _on_combat_result_acknowledged(party_won: bool) -> void:
    # Defeat is handled by SaveManager restoring its checkpoint.
    if party_won:
        get_tree().reload_current_scene()
