extends "res://addons/godot-openxr/scenes/first_person_controller_vr.gd"
class_name VRPlayer

signal player_got_hurt

enum MultiToolController {
	LEFT,		# Use left controller
	RIGHT,		# Use right controler
}

export (MultiToolController) var multitoolcontrollerselection : int = MultiToolController.RIGHT


export var jetpack_fuel := 1.0
export var unlocked_jetpack := false
export var gravity_multiplier := 3.0
export var left_handed : bool = false

onready var flight_movement_node = get_node("MovementFlight")
onready var direct_movement_node = get_node("LeftHandController/MovementDirect")
onready var turn_movement_node = get_node("RightHandController/MovementTurn")
onready var jump_movement_node = get_node("LeftHandController/MovementJump")
onready var physical_jump_movement_node = get_node("MovementPhysicalJump")
onready var jog_movement_node = get_node("MovementJogInPlace")
onready var jetpack_light = get_node("JetpackLight")
onready var jetpack_flames = get_node("JetpackFlames")
onready var jetpack_particles = jetpack_flames.get_node("Particles")
onready var player_body = get_node("PlayerBody")
onready var gravity_strength : float = (ProjectSettings.get_setting("physics/3d/default_gravity") 
		* gravity_multiplier)
onready var pickup_point : Spatial = $"%PickupPoint"

var movement_disabled : bool = false
var gravity_effect_max_dist = 40
var gravity_direction = 0.0
var trigger_jetpack : bool = false
const footstep_thresh = 0.2
var _multitoolcontroller : ARVRController

func _ready():
	Game.vrplayer = self
	Game.player = self
	Game.camera = get_node("ARVRCamera")
	Game.multitool = $MultitoolHolder/Multitool
	Game.player_raycast = $MultitoolHolder/Multitool/PlayerRayCast
	Game.UI = Game.camera.get_node("UI_Viewport2Dto3D").get_scene_instance()
	if multitoolcontrollerselection == MultiToolController.RIGHT:
		$RightHandController/RemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
	else:
		$LeftHandController/RemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_left_controller(self)
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")

	Game.multitool.connect("switched_to", Game.UI, "switched_to_tool")
	
func _process(delta):
	pass

func _physics_process(delta) -> void:
	if Game.game_state == Game.State.LOADING or Game.game_state == Game.State.INTRO_FLIGHT or Game.game_state == Game.State.WARPING:
		return 
	
		# If movement disabled variable set, disable all XRTools movement providers, else enable
	if movement_disabled or Game.game_state != Game.State.INGAME:
		for provider in get_tree().get_nodes_in_group("movement_providers"):
			provider.enabled = false
	
	else:
		for provider in get_tree().get_nodes_in_group("movement_providers"):
			provider.enabled = true
	
	# Enable flight movement provider if have unlocked jet pack and have fuel, else disable
	var jetpack_available = unlocked_jetpack and (jetpack_fuel>0.0)
	if jetpack_available == true:
		flight_movement_node.enabled = true
	else:
		flight_movement_node.enabled = false
	
	
	gravity_direction = calc_gravity_direction()
	
	if trigger_jetpack:
#		print(jetpack_fuel)
		jetpack_fuel -= delta * .7
		
	if !trigger_jetpack:
			if player_body.ground_control_velocity.length() > footstep_thresh:
				var prefix: String = Game.planet.music_prefix		
				Audio.play_random_step(prefix)
				Audio.start_footsteps(prefix)
			else:
				Audio.stop_footsteps()
				
	var planet_gravity_modifier : float = Game.planet.gravity_modifier
#	if direction.length() > 0.1 or not is_on_floor():
#		velocity += gravity_strength * gravity_direction * delta * planet_gravity_modifier
#	orient_player_sphere(delta)
#	velocity = accelerate(velocity, direction, delta)
##	
#	up_direction = -gravity_direction
#	velocity = move_and_slide_with_snap(velocity, snap, up_direction, 
#			stop_on_slope, 4, floor_max_angle)
			
	
	
func calc_gravity_direction() -> Vector3:
	if Game.planet != null:
		var dist_to_planet = global_translation.distance_to(Game.planet.global_translation)
		if dist_to_planet > gravity_effect_max_dist:
			return Vector3(0.0, -1.0, 0.0).normalized()
		return global_translation.direction_to(Game.planet.global_translation)
		
	return Vector3(0.0, -1.0, 0.0).normalized()




func _on_MovementFlight_flight_started():
	Audio.fade_in("jetpack", 0.1, true)
	trigger_jetpack = true
	jetpack_light.visible = true
	jetpack_flames.visible = true
	jetpack_particles.emitting = true

func _on_MovementFlight_flight_finished():
	Audio.fade_out("jetpack", 0.1)
	trigger_jetpack = false
	jetpack_light.visible = false
	jetpack_flames.visible = false
	jetpack_particles.emitting = false
	jetpack_fuel = 1.0

func _on_PlayerBody_player_jumped():
	Audio.stop_footsteps()
