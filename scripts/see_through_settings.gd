class_name SeeThroughSettings
extends Resource
## Tuning for the see-through walls effect (see [SeeThroughController]).
##
## Only materials that include [code]res://shaders/see_through.gdshaderinc[/code]
## (e.g. [code]WallSeeThrough.tres[/code]) are affected. Every property emits
## [signal Resource.changed], so edits made while the game runs apply live.

## Master switch for both the occlusion cutout and the near-camera fade.
@export var enabled: bool = true:
	set(value):
		enabled = value
		emit_changed()

@export_group("Occlusion Cutout")
## Cut a hole in walls that hide a character from the camera.
@export var cutout_enabled: bool = true:
	set(value):
		cutout_enabled = value
		emit_changed()
## Hole radius in world units around the target, so it scales with zoom.
@export_range(0.1, 10.0, 0.05, "or_greater") var cutout_radius: float = 2.2:
	set(value):
		cutout_radius = value
		emit_changed()
## Shape of the hole, stretched over the cutout circle. Where the texture is black
## or transparent the wall is cut away; white and opaque keeps the wall.
@export var mask_texture: Texture2D:
	set(value):
		mask_texture = value
		emit_changed()
## Mask values below this are cut away.
@export_range(0.0, 1.0, 0.01) var mask_threshold: float = 0.5:
	set(value):
		mask_threshold = value
		emit_changed()
## Width (in mask value) of the dithered band at the hole's edge. 0 gives a hard edge.
@export_range(0.0, 1.0, 0.01) var edge_softness: float = 0.15:
	set(value):
		edge_softness = value
		emit_changed()
## Colour of the rim drawn just outside the hole. Alpha scales its strength.
@export var edge_color: Color = Color(0.4, 0.8, 1.0, 0.35):
	set(value):
		edge_color = value
		emit_changed()
## Width (in mask value) of the rim. 0 disables it.
@export_range(0.0, 1.0, 0.01) var edge_width: float = 0.05:
	set(value):
		edge_width = value
		emit_changed()
## How fast a hole opens and closes. Higher is snappier.
@export var fade_speed: float = 8.0
## Nodes in this group can cut holes. Up to [constant SeeThroughController.MAX_TARGETS] at once.
@export var target_group: StringName = &"see_through_target"
## Physics layers that count as blocking the view of a target.
@export_flags_3d_physics var occluder_mask: int = 1
## Height above the target's origin that is tested and centred on (roughly the chest).
@export var target_height_offset: float = 1.0
## Walls must be at least this much closer to the camera than the target to be cut,
## so the wall a character leans against from the far side stays solid.
@export var depth_bias: float = 0.6:
	set(value):
		depth_bias = value
		emit_changed()

@export_group("Near Camera Fade")
## Cut away wall geometry close to the camera (e.g. when it clips into a wall).
@export var near_fade_enabled: bool = true:
	set(value):
		near_fade_enabled = value
		emit_changed()
## Geometry closer to the camera than this is cut away.
@export_range(0.0, 20.0, 0.1, "or_greater") var near_fade_distance: float = 3.0:
	set(value):
		near_fade_distance = value
		emit_changed()
## Distance over which the cut dithers in, ending at [member near_fade_distance].
@export_range(0.0, 10.0, 0.1, "or_greater") var near_fade_softness: float = 1.5:
	set(value):
		near_fade_softness = value
		emit_changed()
