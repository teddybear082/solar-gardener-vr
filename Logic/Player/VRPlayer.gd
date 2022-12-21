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


onready var jetpack_light = get_node("JetpackLight")
onready var jetpack_flames = get_node("JetpackFlames")
onready var jetpack_particles = jetpack_flames.get_node("Particles")
onready var player_body = get_node("Player-cage")
onready var pickup_point : Spatial = $"%PickupPoint"

var movement_disabled : bool = false
var gravity_effect_max_dist = 40
var gravity_direction = 0.0
var trigger_jetpack : bool = false
const footstep_thresh = 0.2
var _multitoolcontroller : ARVRController
var _off_handcontroller : ARVRController

func _ready():
	Game.vrplayer = self
	Game.player = self
	Game.camera = get_node("ARVRCamera")
	Game.multitool = $MultitoolHolder/Multitool
	Game.player_raycast = $MultitoolHolder/Multitool/PlayerRayCast
	Game.UI = Game.camera.get_node("UI_Viewport2Dto3D").get_scene_instance()
	
	if multitoolcontrollerselection == MultiToolController.RIGHT:
		$RightHandController/RightMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
		_off_handcontroller = ARVRHelpers.get_left_controller(self)
	else:
		$LeftHandController/LeftMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_left_controller(self)
		_off_handcontroller = ARVRHelpers.get_right_controller(self)
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.connect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.connect("button_release", Game, "_on_offhand_controller_button_released")
	Game.multitool.connect("switched_to", Game.UI, "switched_to_tool")
	player_body.set_as_toplevel(true)
	
func _process(delta):
	pass

func _physics_process(delta) -> void:
	if Game.game_state == Game.State.LOADING or Game.game_state == Game.State.INTRO_FLIGHT or Game.game_state == Game.State.WARPING:
		return 
	
	# If movement disabled variable set, disable movement in player_cage
	if movement_disabled or Game.game_state != Game.State.INGAME:
		player_body.movement_disabled = true
	
	else:
		player_body.movement_disabled = false
	
	# Enable flight movement provider if have unlocked jet pack and have fuel, else disable
	var jetpack_available = unlocked_jetpack and (jetpack_fuel>0.0)
	if jetpack_available == true:
		pass # to do 
	else:
		pass # to do
	
	if trigger_jetpack:
		jetpack_fuel -= delta * .7
		
	if !trigger_jetpack:
			if player_body.input_axis.length() > footstep_thresh:
				var prefix: String = Game.planet.music_prefix		
				Audio.play_random_step(prefix)
				Audio.start_footsteps(prefix)
			else:
				Audio.stop_footsteps()
				


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

func set_multitool_controller(string_of_controller_side : String):
	_multitoolcontroller.disconnect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.disconnect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.disconnect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.disconnect("button_release", Game, "_on_offhand_controller_button_released")
	
	if string_of_controller_side == "left":
		$LeftHandController/LeftMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_left_controller(self)
		_off_handcontroller = ARVRHelpers.get_right_controller(self)
		
	if string_of_controller_side == "right":
		$RightHandController/RightMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
		_off_handcontroller = ARVRHelpers.get_left_controller(self)
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.connect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.connect("button_release", Game, "_on_offhand_controller_button_released")
	
