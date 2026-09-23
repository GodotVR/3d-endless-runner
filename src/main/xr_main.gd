extends "res://src/main/main.gd"

const Stencilizer = preload("res://addons/spatialize/stencilizer.gd")

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = %XRCamera3D
@onready var left_function_pointer = $XROrigin3D/LeftController/FunctionPointer
@onready var right_function_pointer = $XROrigin3D/RightController/FunctionPointer
@onready var left_hand: XRController3D = %LeftHand
@onready var right_hand: XRController3D = %RightHand
@onready var viewport_2d_in_3d: Node3D = %Viewport2Din3D
@onready var viewport_2d_in_3d_transform_orig: Transform3D = viewport_2d_in_3d.transform
@onready var flat_portal: MeshInstance3D = $FlatPortal
@onready var cube_portal: MeshInstance3D = $CubePortal
@onready var cube_depth: MeshInstance3D = $CubeDepth
@onready var game_parent: Node3D = $GameParent
@onready var world_environment: WorldEnvironment = $GameParent/Level/WorldEnvironment

const UI_LAYER_MIN_SCALE := 0.25
const FUNCTION_POINTER_DEFAULT_TARGET_RADIUS := 0.05

enum XRMode {
	IMMERSIVE,
	PORTAL,
	VOLUME,
}

var stencilizer: Stencilizer = Stencilizer.new(1)
var xr_mode: XRMode = XRMode.IMMERSIVE
var uses_spatial_container := false

func _ready() -> void:
	ui = viewport_2d_in_3d.get_scene_instance()
	ui.xr_mode_changed.connect(_on_ui_xr_mode_changed)

	super._ready()

	var spatial_container_ext = Engine.get_singleton("OpenXRSpatialContainerExtension")
	if spatial_container_ext and spatial_container_ext.is_enabled():
		spatial_container_ext.spatial_container_bounds_changed.connect(_on_spatial_container_bounds_changed)
		uses_spatial_container = true

	stencilizer.setup_portal_material(flat_portal)
	stencilizer.setup_portal_material(cube_portal)

	level.object_spawned.connect(_on_level_object_spawned)


func _on_level_object_spawned(obj: Node3D) -> void:
	if xr_mode >= XRMode.PORTAL:
		stencilizer.setup_object_materials(obj)


func _on_ui_xr_mode_changed(p_index: int) -> void:
	set_xr_mode(p_index)


func _process(_delta: float) -> void:
	if uses_spatial_container and xr_mode != XRMode.IMMERSIVE:
		viewport_2d_in_3d.position = Vector3.ZERO
		viewport_2d_in_3d.scale = game_parent.scale
		if viewport_2d_in_3d.scale.x < UI_LAYER_MIN_SCALE:
			viewport_2d_in_3d.scale = Vector3.ONE * UI_LAYER_MIN_SCALE

		left_function_pointer.target_radius = FUNCTION_POINTER_DEFAULT_TARGET_RADIUS * viewport_2d_in_3d.scale.x
		right_function_pointer.target_radius = FUNCTION_POINTER_DEFAULT_TARGET_RADIUS * viewport_2d_in_3d.scale.x


func set_xr_mode(p_index: XRMode) -> void:
	xr_mode = p_index

	var openxr_interface: OpenXRInterface = XRServer.find_interface("OpenXR")
	if not openxr_interface or not openxr_interface.is_initialized():
		return

	var faux_sky_box: MeshInstance3D = level.get_node("FauxSkyBox") as MeshInstance3D
	var plain: MeshInstance3D = level.get_node("Plain") as MeshInstance3D

	if xr_mode == XRMode.IMMERSIVE:
		openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		world_environment.environment.background_mode = Environment.BG_SKY
		get_viewport().transparent_bg = false
		stencilizer.restore_object_materials(player)
		stencilizer.restore_object_materials(level)
		xr_origin.position = %VROriginMarker.position
		game_parent.position = Vector3.ZERO
		game_parent.scale = Vector3.ONE
		faux_sky_box.visible = true
		plain.visible = true
		flat_portal.visible = false
		cube_portal.visible = false
		cube_depth.visible = false

		left_function_pointer.target_radius = FUNCTION_POINTER_DEFAULT_TARGET_RADIUS
		right_function_pointer.target_radius = FUNCTION_POINTER_DEFAULT_TARGET_RADIUS

		if uses_spatial_container:
			OpenXRSpatialContainerExtension.request_spatial_container_bounds_mode(OpenXRSpatialContainerState.BOUNDS_MODE_IMMERSIVE)

	elif xr_mode in [XRMode.PORTAL, XRMode.VOLUME]:
		openxr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		world_environment.environment.background_mode = Environment.BG_COLOR
		world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		get_viewport().transparent_bg = true
		stencilizer.setup_object_materials(player)
		stencilizer.setup_object_materials(level)

		if xr_mode == XRMode.PORTAL:
			xr_origin.position = %PortalOriginMarker.position if not uses_spatial_container else Vector3.ZERO
			game_parent.position = Vector3.ZERO
			game_parent.scale = Vector3.ONE
			faux_sky_box.visible = true
			plain.visible = true
			flat_portal.visible = true
			cube_portal.visible = false
			cube_depth.visible = false
		elif xr_mode == XRMode.VOLUME:
			xr_origin.position = %VolumeOriginMarker.position if not uses_spatial_container else Vector3.ZERO
			game_parent.position = %VolumeGameMarker.position if not uses_spatial_container else Vector3.ZERO
			game_parent.scale = Vector3(0.1, 0.1, 0.1)
			faux_sky_box.visible = false
			plain.visible = false
			flat_portal.visible = false
			cube_portal.visible = true
			cube_depth.visible = true

		if uses_spatial_container:
			OpenXRSpatialContainerExtension.request_spatial_container_bounds_mode(OpenXRSpatialContainerState.BOUNDS_MODE_BOUNDED)


func _on_hand_tracking_changed(_tracking: bool) -> void:
	var hand_tracking_active: bool = left_hand.get_has_tracking_data() or right_hand.get_has_tracking_data()
	ui.set_on_screen_controls_visibility(hand_tracking_active)


func _on_start_xr_xr_ended() -> void:
	_on_ui_pause_pressed()


func _on_spatial_container_bounds_changed(_spatial_container_rid: RID, p_infinite_bounds: bool, p_bounds_mode: OpenXRSpatialContainerState.BoundsMode, p_updated_bounds: Vector3) -> void:
	if p_bounds_mode == OpenXRSpatialContainerState.BOUNDS_MODE_IMMERSIVE:
		print("Spatial Container: Immersive")
		game_parent.position = Vector3.ZERO
		game_parent.scale = Vector3.ONE
		viewport_2d_in_3d.transform = viewport_2d_in_3d_transform_orig
	else:
		print("Spatial Container: Bounded")
		var new_bounds: Vector3 = p_updated_bounds if not p_infinite_bounds else Vector3(1.0, 1.0, 1.0)
		var min_dimension: float = min(new_bounds.x, min(new_bounds.y, new_bounds.z))
		if min_dimension <= 0.0:
			print("Spatial Container: Invalid bounds received: ", p_updated_bounds)
			return

		cube_depth.mesh.size = new_bounds * 0.99

		game_parent.scale = Vector3.ONE * (min_dimension / 20.0)
		game_parent.position.y = (-new_bounds.y / 2.0) + 0.001
		game_parent.position.z = (new_bounds.z  / 2.0) - (game_parent.scale.z * 1.0)

		if xr_mode == XRMode.PORTAL:
			flat_portal.position.y = 0.0
			flat_portal.position.z = (new_bounds.z / 2.0) - 0.001
			flat_portal.mesh.size = Vector2(new_bounds.x, new_bounds.y)
		elif xr_mode == XRMode.VOLUME:
			cube_portal.position = Vector3.ZERO
			cube_portal.mesh.size = new_bounds
			cube_depth.position = Vector3.ZERO
			cube_depth.mesh.size = new_bounds

		print("Spatial Container: Updated bounds: ", new_bounds, " | New scale: ", game_parent.scale)
