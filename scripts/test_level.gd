extends Node3D
## Graybox level for testing exploration movement and the camera.

@export var nav_region: NavigationRegion3D


func _ready() -> void:
	# Bakes at runtime so the navmesh always matches the level geometry.
	# Once the layout settles, bake in the editor and remove this.
	if nav_region:
		nav_region.bake_navigation_mesh(false)
