tool
class_name XRToolsPlayerBody, "res://addons/godot-xr-tools/editor/icons/body.svg"
extends Node


## XR Tools Player Physics Body Script
##
## This node provides the player with a physics body. The body is a 
## [CapsuleShape] which tracks the player location as measured by the 
## [ARVRCamera] for the players head.
##
## The player body can detect when the player is in the air, on the ground,
## or on a steep slope.
##
## Player movement is achieved by a number of movement providers attached to
## either the player or their controllers.
##
## After the player body moves, the [ARVROrigin] is updated as necessary to 
## track the players movement.


## Signal emitted when the player jumps
signal player_jumped()

## Signal emitted when the player bounces
signal player_bounced(collider, magnitude)


## Player body enabled flag
export var enabled : bool = true setget set_enabled

## Player radius
export var player_radius : float = 0.4 setget set_player_radius

## Player head height (distance between between camera and top of head)
export var player_head_height : float = 0.1

## Minimum player height
export var player_height_min : float = 1.0

## Maximum player height
export var player_height_max : float = 2.2

## Eyes forward offset from center of body in player_radius units
export (float, 0.0, 1.0) var eye_forward_offset : float = 0.66

## Lets the player push rigid bodies
export var push_rigid_bodies : bool = true

## GroundPhysicsSettings to apply - can only be typed in Godot 4+
export var physics : Resource setget set_physics

# Set our collision layer
export (int, LAYERS_3D_PHYSICS) var collision_layer : int = 1 << 19 setget set_collision_layer

# Set our collision mask
export (int, LAYERS_3D_PHYSICS) var collision_mask : int = 1023 setget set_collision_mask


## Player Velocity - modifiable by movement providers
var velocity : Vector3 = Vector3.ZERO

## Current player gravity
var gravity : Vector3 = Vector3.ZERO

## Player On Ground flag - used by movement providers
var on_ground : bool = true

## Ground 'up' vector - used by movement providers
var ground_vector : Vector3 = Vector3.UP

## Ground slope angle - used by movement providers
var ground_angle : float = 0.0

## Ground node the player is touching
var ground_node : Spatial = null

## Ground physics override (if present)
var ground_physics : XRToolsGroundPhysicsSettings = null

## Ground control velocity - modified by movement providers
var ground_control_velocity : Vector2 = Vector2.ZERO

## Player height offset (for height calibration)
var player_height_offset : float = 0.0

## Velocity of the ground under the players feet
var ground_velocity : Vector3 = Vector3.ZERO

## Gravity-based "up" direction
var up_gravity_vector := Vector3.UP

## Player-based "up" direction
var up_player_vector := Vector3.UP

## Gravity-based "up" plane
var up_gravity_plane := Plane(Vector3.UP, 0.0)

## Player-based "up" plane
var up_player_plane := Plane(Vector3.UP, 0.0)

# Movement providers
var _movement_providers := Array()

# Jump cool-down counter
var _jump_cooldown := 0

# Player height overrides
var _player_height_overrides := { }

## Player height override (enabled when non-negative)
var _player_height_override : float = -1.0

# Previous ground node
var _previous_ground_node : Spatial = null

# Previous ground local position
var _previous_ground_local : Vector3 = Vector3.ZERO

# Previous ground global position
var _previous_ground_global : Vector3 = Vector3.ZERO


## ARVROrigin node
onready var origin_node : ARVROrigin = ARVRHelpers.get_arvr_origin(self)

## ARVRCamera node
onready var camera_node : ARVRCamera = ARVRHelpers.get_arvr_camera(self)

## Player KinematicBody node
onready var kinematic_node : KinematicBody = $KinematicBody

# Default physics (if not specified by the user or the current ground)
onready var default_physics = _guaranteed_physics()

# Collision node
onready var _collision_node : CollisionShape = $KinematicBody/CollisionShape


# Class to sort movement providers by order
class SortProviderByOrder:
	static func sort_by_order(a, b) -> bool:
		return true if a.order < b.order else false


# Add support for is_class on XRTools classes
func is_class(name : String) -> bool:
	return name == "XRToolsPlayerBody" or .is_class(name)


# Called when the node enters the scene tree for the first time.
func _ready():
	# Get the movement providers ordered by increasing order
	_movement_providers = get_tree().get_nodes_in_group("movement_providers")
	_movement_providers.sort_custom(SortProviderByOrder, "sort_by_order")

	# Propagate defaults
	_update_enabled()
	_update_player_radius()
	_update_collision_layer()
	_update_collision_mask()

func set_enabled(new_value) -> void:
	enabled = new_value
	if is_inside_tree():
		_update_enabled()

func _update_enabled() -> void:
	# Update collision_shape
	if _collision_node:
		_collision_node.disabled = !enabled

	# Update physics processing
	if enabled:
		set_physics_process(true)

func set_player_radius(new_value: float) -> void:
	player_radius = new_value
	if is_inside_tree():
		_update_player_radius()

func _update_player_radius() -> void:
	if _collision_node and _collision_node.shape:
		_collision_node.shape.radius = player_radius

func set_physics(new_value: Resource) -> void:
	# Save the property
	physics = new_value
	default_physics = _guaranteed_physics()

func set_collision_layer(new_layer: int) -> void:
	collision_layer = new_layer
	if is_inside_tree():
		_update_collision_layer()

func _update_collision_layer() -> void:
	if kinematic_node:
		kinematic_node.collision_layer = collision_layer

func set_collision_mask(new_mask: int) -> void:
	collision_mask = new_mask
	if is_inside_tree():
		_update_collision_mask()

func _update_collision_mask() -> void:
	if kinematic_node:
		kinematic_node.collision_mask = collision_mask

func _physics_process(delta: float):
	# Do not run physics if in the editor
	if Engine.editor_hint:
		return

	# If disabled then turn of physics processing and bail out
	if !enabled:
		set_physics_process(false)
		return

	# Decrement the jump cool-down on each physics update
	if _jump_cooldown:
		_jump_cooldown -= 1

	# Calculate the players "up" direction and plane
	up_player_vector = origin_node.global_transform.basis.y
	up_player_plane = Plane(up_player_vector, 0.0)

	# Determine environmental gravity
	var gravity_state := PhysicsServer.body_get_direct_state(kinematic_node.get_rid())
	gravity = gravity_state.total_gravity

	# Update the kinematic body to be under the camera
	_update_body_under_camera()

	# Allow the movement providers a chance to perform pre-movement updates. The providers can:
	# - Adjust the gravity direction
	for p in _movement_providers:
		if p.enabled:
			p.physics_pre_movement(delta, self)

	# Determine the gravity "up" direction and plane
	if gravity.is_equal_approx(Vector3.ZERO):
		# Gravity too weak - use player
		up_gravity_vector = up_player_vector
		up_gravity_plane = up_player_plane
	else:
		# Use gravity direction
		up_gravity_vector = -gravity.normalized()
		up_gravity_plane = Plane(up_gravity_vector, 0.0)

	# Update the ground information
	_update_ground_information(delta)

	# Get the player body location before movement occurs
	var position_before_movement := kinematic_node.global_transform.origin

	# Run the movement providers in order. The providers can:
	# - Move the kinematic node around (to move the player)
	# - Rotate the ARVROrigin around the camera (to rotate the player)
	# - Read and modify the player velocity
	# - Read and modify the ground-control velocity
	# - Perform exclusive updating of the player (bypassing other movement providers)
	# - Request a jump
	# - Modify gravity direction
	ground_control_velocity = Vector2.ZERO
	var exclusive := false
	for p in _movement_providers:
		if p.is_active or (p.enabled and not exclusive):
			if p.physics_movement(delta, self, exclusive):
				exclusive = true

	# If no controller has performed an exclusive-update then apply gravity and
	# perform any ground-control
	if !exclusive:
		if on_ground and ground_physics.stop_on_slope and ground_angle < ground_physics.move_max_slope:
			# Apply gravity towards slope to prevent sliding
			velocity += -ground_vector * gravity.length() * delta
		else:
			# Apply gravity
			velocity += gravity * delta
		_apply_velocity_and_control(delta)

	# Apply the player-body movement to the ARVR origin
	var movement := kinematic_node.global_transform.origin - position_before_movement
	origin_node.global_transform.origin += movement

	# Orient the player towards (potentially modified) gravity
	slew_up(-gravity.normalized(), 5.0 * delta)


# Request a jump
func request_jump(skip_jump_velocity := false):
	# Skip if cooling down from a previous jump
	if _jump_cooldown:
		return;

	# Skip if not on ground
	if !on_ground:
		return

	# Skip if jump disabled on this ground
	var jump_velocity := XRToolsGroundPhysicsSettings.get_jump_velocity(ground_physics, default_physics)
	if jump_velocity == 0.0:
		return

	# Skip if the ground is too steep to jump
	var max_slope := XRToolsGroundPhysicsSettings.get_jump_max_slope(ground_physics, default_physics)
	if ground_angle > max_slope:
		return

	# Perform the jump
	if !skip_jump_velocity:
		velocity += ground_vector * jump_velocity * ARVRServer.world_scale

	# Report the jump
	emit_signal("player_jumped")
	_jump_cooldown = 4

# Move the players body
func move_body(p_velocity: Vector3) -> Vector3:
	return kinematic_node.move_and_slide(p_velocity, up_gravity_vector, false, 4, 0.785398, push_rigid_bodies)

## Rotate the player
##
## This method rotates the player by rotating the [ARVROrigin] around the camera.
func rotate_player(angle: float):
	var t1 := Transform()
	var t2 := Transform()
	var rot := Transform()

	t1.origin = -camera_node.transform.origin
	t2.origin = camera_node.transform.origin
	rot = rot.rotated(Vector3.DOWN, angle)
	origin_node.transform = (origin_node.transform * t2 * rot * t1).orthonormalized()

## Slew the players up vector
##
## This method slews the players up vector by rotating the [ARVROrigin] around 
## the players feet.
func slew_up(up: Vector3, slew: float) -> void:
	# Skip if the up vector is not valid
	if up.is_equal_approx(Vector3.ZERO):
		return

	# Get the current origin
	var current_origin := origin_node.global_transform

	# Save the player foot global and local positions
	var ref_pos_global := kinematic_node.global_translation
	var ref_pos_local : Vector3 = current_origin.xform_inv(ref_pos_global)

	# Calculate the target origin
	var target_origin := current_origin
	target_origin.basis.y = up.normalized()
	target_origin.basis.x = target_origin.basis.y.cross(target_origin.basis.z).normalized()
	target_origin.basis.z = target_origin.basis.x.cross(target_origin.basis.y).normalized()
	target_origin.origin = ref_pos_global - target_origin.basis.xform(ref_pos_local)

	# Calculate the new origin
	var new_origin := current_origin.interpolate_with(target_origin, slew).orthonormalized()

	# Update the origin
	origin_node.global_transform = new_origin

# Set or clear a named height override
func override_player_height(key, value: float = -1.0):
	# Clear or set the override
	if value < 0.0:
		_player_height_overrides.erase(key)
	else:
		_player_height_overrides[key] = value

	# Set or clear the override value
	var override = _player_height_overrides.values().min()
	_player_height_override = override if override != null else -1.0

# This method updates the body to match the player position
func _update_body_under_camera():
	# Calculate the player height based on the camera position in the origin and the calibration
	var player_height: float = clamp(
		camera_node.transform.origin.y + player_head_height + player_height_offset + XRToolsUserSettings.player_height_adjust,
		player_height_min * ARVRServer.world_scale,
		player_height_max * ARVRServer.world_scale)

	# Allow forced overriding of height
	if _player_height_override >= 0.0:
		player_height = _player_height_override

	# Ensure player height makes mathematical sense
	player_height = max(player_height, player_radius * 2.0)

	# Adjust the collision shape to match the player geometry
	_collision_node.shape.radius = player_radius
	_collision_node.shape.height = player_height - (player_radius * 2.0)
	_collision_node.transform.origin.y = (player_height / 2.0)

	# Center the kinematic body on the ground under the camera
	var curr_transform := kinematic_node.global_transform
	var camera_transform := camera_node.global_transform
	curr_transform.basis = origin_node.global_transform.basis
	curr_transform.origin = camera_transform.origin
	curr_transform.origin += up_player_vector * (player_head_height - player_height)

	# The camera/eyes are towards the front of the body, so move the body back slightly
	var forward_dir := up_player_plane.project(-camera_transform.basis.z)
	if forward_dir.length() > 0.01:
		curr_transform.origin -= forward_dir.normalized() * eye_forward_offset * player_radius

	# Set the body position
	kinematic_node.global_transform = curr_transform

# This method updates the information about the ground under the players feet
func _update_ground_information(delta: float):
	# Update the ground information
	var ground_collision := kinematic_node.move_and_collide(up_gravity_vector * -0.1, true, true, true)
	if !ground_collision:
		on_ground = false
		ground_vector = up_gravity_vector
		ground_angle = 0.0
		ground_node = null
		ground_physics = null
		_previous_ground_node = null
		return

	# Save the ground information from the collision
	on_ground = true
	ground_vector = ground_collision.normal
	ground_angle = rad2deg(ground_collision.get_angle(up_gravity_vector))
	ground_node = ground_collision.collider

	# Select the ground physics
	var physics_node := ground_node.get_node_or_null("GroundPhysics") as XRToolsGroundPhysics
	ground_physics = XRToolsGroundPhysics.get_physics(physics_node, default_physics)

	# Detect if we're sliding on a wall
	# TODO: consider reworking this magic angle
	if ground_angle > 85:
		on_ground = false

	# Detect ground velocity under players feet
	if _previous_ground_node == ground_node:
		var pos_old := _previous_ground_global
		var pos_new := ground_node.to_global(_previous_ground_local)
		ground_velocity = (pos_new - pos_old) / delta

	# Update ground velocity information
	_previous_ground_node = ground_node
	_previous_ground_global = ground_collision.position
	_previous_ground_local = ground_node.to_local(_previous_ground_global)


# This method applies the player velocity and ground-control velocity to the physical body
func _apply_velocity_and_control(delta: float):
	# Calculate local velocity
	var local_velocity := velocity - ground_velocity

	# Split the velocity into horizontal and vertical components
	var horizontal_velocity := up_gravity_plane.project(local_velocity)
	var vertical_velocity := local_velocity - horizontal_velocity

	# If the player is on the ground then give them control
	if on_ground:
		# If ground control is being supplied then update the horizontal velocity
		var control_velocity := Vector3.ZERO
		if abs(ground_control_velocity.x) > 0.1 or abs(ground_control_velocity.y) > 0.1:
			var camera_transform := camera_node.global_transform
			var dir_forward := up_gravity_plane.project(camera_transform.basis.z).normalized()
			var dir_right := up_gravity_plane.project(camera_transform.basis.x).normalized()
			control_velocity = (dir_forward * -ground_control_velocity.y + dir_right * ground_control_velocity.x) * ARVRServer.world_scale

			# Apply control velocity to horizontal velocity based on traction
			var current_traction := XRToolsGroundPhysicsSettings.get_move_traction(ground_physics, default_physics)
			var traction_factor: float = clamp(current_traction * delta, 0.0, 1.0)
			horizontal_velocity = lerp(horizontal_velocity, control_velocity, traction_factor)

			# Prevent the player from moving up steep slopes
			var current_max_slope := XRToolsGroundPhysicsSettings.get_move_max_slope(ground_physics, default_physics)
			if ground_angle > current_max_slope:
				# Get a vector in the down-hill direction
				var down_direction := up_gravity_plane.project(ground_vector).normalized()
				var vdot: float = down_direction.dot(horizontal_velocity)
				if vdot < 0:
					horizontal_velocity -= down_direction * vdot
		else:
			# User is not trying to move, so apply the ground drag
			var current_drag := XRToolsGroundPhysicsSettings.get_move_drag(ground_physics, default_physics)
			var drag_factor: float = clamp(current_drag * delta, 0, 1)
			horizontal_velocity = lerp(horizontal_velocity, control_velocity, drag_factor)

	# Combine the velocities back to a 3-space velocity
	local_velocity = horizontal_velocity + vertical_velocity

	# Move the player body with the desired velocity
	velocity = move_body(local_velocity + ground_velocity)

	# Perform bounce test if a collision occurred
	if kinematic_node.get_slide_count():
		# Detect bounciness
		var collision := kinematic_node.get_slide_collision(0)
		var collision_node := collision.collider
		var collision_physics_node := collision_node.get_node_or_null("GroundPhysics") as XRToolsGroundPhysics
		var collision_physics = XRToolsGroundPhysics.get_physics(collision_physics_node, default_physics)
		var bounce_threshold := XRToolsGroundPhysicsSettings.get_bounce_threshold(collision_physics, default_physics)
		var bounciness := XRToolsGroundPhysicsSettings.get_bounciness(collision_physics, default_physics)
		var magnitude := -collision.normal.dot(local_velocity)

		# Detect if bounce should be performed
		if bounciness > 0.0 and magnitude >= bounce_threshold:
			local_velocity += 2 * collision.normal * magnitude * bounciness
			velocity = local_velocity + ground_velocity
			emit_signal("player_bounced", collision_node, magnitude)

	# Hack to ensure feet stick to ground (if not jumping)
	# TODO: FIX
	#if abs(velocity.y) < 0.001:
	#	velocity.y = ground_velocity.y

# Get a guaranteed-valid physics
func _guaranteed_physics():
	# Ensure we have a guaranteed-valid XRToolsGroundPhysicsSettings value
	var valid_physics := physics as XRToolsGroundPhysicsSettings
	if !valid_physics:
		valid_physics = XRToolsGroundPhysicsSettings.new()
		valid_physics.resource_name = "default"

	# Return the guaranteed-valid physics
	return valid_physics

# This method verifies the XRToolsPlayerBody has a valid configuration. Specifically it
# checks the following:
# - ARVROrigin can be identified
# - ARVRCamera can be identified
# - Player radius is valid
# - Maximum slope is valid
func _get_configuration_warning():
	# Check the origin node
	var test_origin_node = ARVRHelpers.get_arvr_origin(self)
	if !test_origin_node:
		return "Unable to find ARVR Origin node"

	# Check the camera node
	var test_camera_node = ARVRHelpers.get_arvr_camera(self)
	if !test_camera_node:
		return "Unable to find ARVR Camera node"

	# Verify the player radius is valid
	if player_radius <= 0:
		return "Player radius must be configured"

	# Verify the player height minimum is valid
	if player_height_min < player_radius * 2.0:
		return "Player height minimum smaller than 2x radius"

	# Verify the player height maximum is valid
	if player_height_max < player_height_min:
		return "Player height maximum cannot be smaller than minimum"

	# Verify eye-forward does not allow near-clip-plane look through
	var eyes_to_collider = (1.0 - eye_forward_offset) * player_radius
	if eyes_to_collider < test_camera_node.near:
		return "Eyes too far forwards. Move eyes back or decrease camera near clipping plane"

	# If specified, verify the ground physics is a valid type
	if physics and !physics is XRToolsGroundPhysicsSettings:
		return "Physics resource must be a GroundPhysicsSettings"

	# Passed basic validation
	return ""

## Find an [XRToolsPlayerBody] node.
##
## This function searches from the specified node for an [XRToolsPlayerBody]
## assuming the node is a sibling of the body under an [ARVROrigin].
static func find_instance(node: Node) -> XRToolsPlayerBody:
	return XRTools.find_child(
		ARVRHelpers.get_arvr_origin(node),
		"*",
		"XRToolsPlayerBody") as XRToolsPlayerBody
