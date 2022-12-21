extends KinematicBody

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

export var speed := 30
export var gravity_multiplier := 3.0
export var jump_acceleration := 950
export var ground_friction := 0.1
export var air_friction := 0.05

var direction := Vector3()
var input_axis := Vector2.ZERO
var input_axis_turn := 0.0
var turn_sensitivity = 0.005
var velocity := Vector3()
var snap := Vector3()
var up_direction := Vector3.UP
var stop_on_slope := false

var movement_disabled = false
var has_jumped = false
var jump_button_pressed = false
var jump_action_released_after_jump := false

var gravity_effect_max_dist = 40
var gravity_direction

onready var floor_max_angle: float = deg2rad(45.0)
onready var gravity_strength : float = (ProjectSettings.get_setting("physics/3d/default_gravity") * gravity_multiplier)
onready var planet = $"../planet"

onready var ARVROrigin = $"../ARVROrigin"
onready var ARVRCamera = $"../ARVROrigin/ARVRCamera"
# Controller node
onready var _right_controller = ARVROrigin.get_node("RightHand")
onready var _left_controller = ARVROrigin.get_node("LeftHand")

## Button to trigger jump
export (XRTools.Buttons) var jump_button_id : int = XRTools.Buttons.VR_TRIGGER

onready var look_direction = -ARVRCamera.transform.basis.z
var last_target_up := Vector3.ZERO
onready var target_look = -ARVRCamera.transform.basis.z

# Collision node
onready var _collision_node : CollisionShape = $CollisionShape

func _ready():
	pass
	
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

func calc_gravity_direction() -> Vector3:
	if planet != null:
		var dist_to_planet = global_translation.distance_to(planet.global_translation)
		if dist_to_planet > gravity_effect_max_dist:
			return Vector3(0.0, -1.0, 0.0).normalized()
		return global_translation.direction_to(planet.global_translation)
	return Vector3(0.0, -1.0, 0.0).normalized()

func _physics_process(delta) -> void:
	global_rotation = ARVRCamera.global_rotation
	if planet != null:
		input_axis = Vector2(_right_controller.get_joystick_axis(XRTools.Axis.VR_PRIMARY_Y_AXIS),
			_right_controller.get_joystick_axis(XRTools.Axis.VR_PRIMARY_X_AXIS))
		input_axis_turn = _left_controller.get_joystick_axis(XRTools.Axis.VR_PRIMARY_X_AXIS)
		
		if _left_controller.is_button_pressed(jump_button_id) or _left_controller.is_button_pressed(jump_button_id):
			jump_button_pressed = true

		var trigger_jump : bool = is_on_floor() and jump_button_pressed and !has_jumped

		if movement_disabled:
			input_axis = Vector2.ZERO
			input_axis_turn = 0.0
			trigger_jump = false
			jump_button_pressed = false
		
		direction = get_input_direction()
		gravity_direction = calc_gravity_direction()
		
		if trigger_jump:
			snap = Vector3.ZERO
			velocity += jump_acceleration * delta * ARVROrigin.transform.basis.y
			has_jumped = true
			jump_action_released_after_jump = false
		elif is_on_floor():
			if has_jumped:
				has_jumped = false
				jump_button_pressed = false
			snap = gravity_direction
		
		var planet_gravity_modifier : float = planet.gravity_modifier
		if direction.length() > 0.1 or not is_on_floor():
			velocity += gravity_strength * gravity_direction * delta * planet_gravity_modifier
		orient_player_sphere(delta)
		velocity = accelerate(velocity, direction, delta)
		up_direction = -gravity_direction
		velocity = move_and_slide_with_snap(velocity, snap, up_direction, 
				stop_on_slope, 4, floor_max_angle)
				
		ARVROrigin.global_translation = global_translation
		ARVROrigin.global_rotation = global_rotation
		ARVRCamera.global_rotation = global_rotation

#func update_look_direction():
#	look_direction = -ARVRCamera.transform.basis.z
#	target_look = -ARVRCamera.transform.basis.z
#	last_target_up = Vector3.ZERO

func orient_player_sphere(delta: float):
	var target_up = planet.global_translation.direction_to(global_translation)
	if last_target_up == Vector3.ZERO:
		last_target_up = target_up
	var v = target_up.cross(Vector3.UP).normalized()
	var basis = Basis.IDENTITY.rotated(v, -target_up.angle_to(Vector3.UP))

	if target_up != last_target_up:
		var turn_axis : Vector3 = target_up.cross(last_target_up).normalized()
		var turn_angle : float = last_target_up.angle_to(target_up)
		look_direction = look_direction.rotated(-turn_axis.normalized(), turn_angle)
	
	look_direction = look_direction.rotated(target_up, -input_axis_turn * turn_sensitivity)
	target_look = look_direction.cross(-target_up).cross(target_up)
	input_axis_turn = 0.0

	transform.basis = Basis(-target_up.cross(target_look), target_up, -target_look)

	transform = transform.orthonormalized()
	
	# apply planet rotation to player
	var test_t := global_transform
	test_t.origin = planet.to_local(global_translation)
	test_t = test_t.rotated(planet.rotation_axis, delta * planet.y_rotation_speed)
	test_t.origin = planet.to_global(test_t.origin)
	global_transform = test_t
	last_target_up = target_up
	
	look_direction = -transform.basis.z

func get_input_direction() -> Vector3:
#	direction = transform.basis.z * -input_axis.x + transform.basis.x * input_axis.y
	direction = transform.basis.z * -input_axis.x + transform.basis.x * input_axis.y
	return direction

func accelerate(old_velocity: Vector3, direction: Vector3, delta: float) -> Vector3:
	if is_on_floor():
		velocity = velocity * pow((1.0 - ground_friction), delta * 60)
	else:
		velocity = velocity * pow((1.0 - air_friction), delta * 60)
	velocity += speed * direction * delta
	
	return velocity

func get_in_plane_velocity() -> Vector2:
	var global_vel: Vector3 = velocity
	return Vector2(global_vel.x, global_vel.z)
