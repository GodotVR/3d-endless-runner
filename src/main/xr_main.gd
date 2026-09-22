extends "res://src/main/main.gd"

const Stencilizer = preload("res://addons/spatialize/stencilizer.gd")

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var left_hand: XRController3D = %LeftHand
@onready var right_hand: XRController3D = %RightHand
@onready var viewport_2d_in_3d: Node3D = %Viewport2Din3D
@onready var flat_portal: MeshInstance3D = $FlatPortal
@onready var cube_portal: MeshInstance3D = $CubePortal
@onready var cube_depth: MeshInstance3D = $CubeDepth
@onready var game_parent: Node3D = $GameParent
@onready var world_environment: WorldEnvironment = $GameParent/Level/WorldEnvironment

var stencilizer: Stencilizer = Stencilizer.new(1)
var xr_mode: int = 0

func _ready() -> void:
	ui = viewport_2d_in_3d.get_scene_instance()
	ui.xr_mode_changed.connect(_on_ui_xr_mode_changed)

	super._ready()

	stencilizer.setup_portal_material(flat_portal)
	stencilizer.setup_portal_material(cube_portal)

	level.object_spawned.connect(_on_level_object_spawned)


func _on_level_object_spawned(obj: Node3D) -> void:
	if xr_mode >= 1:
		stencilizer.setup_object_materials(obj)


func _on_ui_xr_mode_changed(p_index: int) -> void:
	set_xr_mode(p_index)


func set_xr_mode(p_index: int) -> void:
	xr_mode = p_index

	var openxr_interface: OpenXRInterface = XRServer.find_interface("OpenXR")
	if not openxr_interface or not openxr_interface.is_initialized():
		return

	var faux_sky_box: MeshInstance3D = level.get_node("FauxSkyBox") as MeshInstance3D
	var plain: MeshInstance3D = level.get_node("Plain") as MeshInstance3D

	if xr_mode == 0:
		openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		world_environment.environment.background_mode = Environment.BG_SKY
		get_viewport().transparent_bg = false
		stencilizer.restore_object_materials(player)
		stencilizer.restore_object_materials(level)
		xr_origin.position = $VROriginMarker.position
		game_parent.position = Vector3.ZERO
		game_parent.scale = Vector3.ONE
		faux_sky_box.visible = true
		plain.visible = true
		flat_portal.visible = false
		cube_portal.visible = false
		cube_depth.visible = false

	elif xr_mode >= 1:
		openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		world_environment.environment.background_mode = Environment.BG_COLOR
		world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		get_viewport().transparent_bg = true
		stencilizer.setup_object_materials(player)
		stencilizer.setup_object_materials(level)

		if xr_mode == 1:
			xr_origin.position = $PortalOriginMarker.position
			game_parent.position = Vector3.ZERO
			game_parent.scale = Vector3.ONE
			faux_sky_box.visible = true
			plain.visible = true
			flat_portal.visible = true
			cube_portal.visible = false
			cube_depth.visible = false
		elif xr_mode == 2:
			xr_origin.position = $VolumeOriginMarker.position
			game_parent.position = $VolumeGameMarker.position
			game_parent.scale = Vector3(0.1, 0.1, 0.1)
			faux_sky_box.visible = false
			plain.visible = false
			flat_portal.visible = false
			cube_portal.visible = true
			cube_depth.visible = true


func _on_hand_tracking_changed(_tracking: bool) -> void:
	var hand_tracking_active: bool = left_hand.get_has_tracking_data() or right_hand.get_has_tracking_data()
	ui.set_on_screen_controls_visibility(hand_tracking_active)


func _on_start_xr_xr_ended() -> void:
	_on_ui_pause_pressed()
