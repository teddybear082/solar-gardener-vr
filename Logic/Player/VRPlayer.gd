extends "res://addons/godot-openxr/scenes/first_person_controller_vr.gd"
class_name VRPlayer

signal player_got_hurt

enum MultiToolController {
	LEFT,		# Use left controller
	RIGHT,		# Use right controler
}

export (MultiToolController) var multitoolcontrollerselection : int = MultiToolController.RIGHT

export var max_jetpack_fuel := 3.0
export var unlocked_jetpack := false
onready var jetpack_fuel = max_jetpack_fuel

onready var player_body = get_node("PlayerBody")
onready var pickup_point : Spatial = $"%PickupPoint"
onready var hand_tool_viewport = $MultitoolHolder/Multitool/HandToolViewport
onready var tool_select_ui = hand_tool_viewport.get_scene_instance()
onready var jetpack_light = player_body.get_node("KinematicBody/JetpackLight")#$JetpackLight
onready var jetpack_flames = player_body.get_node("KinematicBody/JetpackFlames")#$JetpackFlames
onready var jetpack_particles = player_body.get_node("KinematicBody/JetpackFlames/Particles")#$JetpackFlames/Particles
onready var left_movement_direct = $LeftHandController/MovementDirect
onready var right_movement_direct = $RightHandController/MovementDirect
onready var left_movement_jump = $LeftHandController/MovementJump
onready var right_movement_jump = $RightHandController/MovementJump
onready var left_movement_turn = $LeftHandController/MovementTurn
onready var right_movement_turn = $RightHandController/MovementTurn
onready var movement_flight = $MovementFlight
onready var movement_wallwalk = $MovementWallWalk

var movement_disabled : bool = false
var gravity_effect_max_dist = 40
var gravity_direction = 0.0
var trigger_jetpack : bool = false
const footstep_thresh = 0.2
var _multitoolcontroller : ARVRController
var _off_handcontroller : ARVRController


# SHED HARD CODE DIRTY
var shed:Spatial
var shed_factor := 0.0

func _ready():
	Game.vrplayer = self
	Game.player = self
	Game.camera = get_node("ARVRCamera")
	Game.multitool = $MultitoolHolder/Multitool
	Game.player_raycast = $MultitoolHolder/Multitool/PlayerRayCast
	Game.UI = $LeftHandController/UI_Viewport2Dto3D.get_scene_instance()
	
	if Game.vr_hand_selection == Game.vr_primary_hand.LEFT:
		multitoolcontrollerselection = MultiToolController.LEFT
		left_movement_direct.enabled = false
		right_movement_direct.enabled = true
		left_movement_jump.enabled = false
		right_movement_jump.enabled = true
		left_movement_turn.enabled = true
		right_movement_turn.enabled = false
		movement_flight._controller = movement_flight._right_controller
		var ui_viewport = $LeftHandController/UI_Viewport2Dto3D
		$LeftHandController.remove_child(ui_viewport)
		$RightHandController.add_child(ui_viewport)
		
	if Game.vr_movement_selection == Game.vr_movement_speed.SLOW:
		set_speed(1)
		set_turn_sensitivity(1)
	
	elif Game.vr_movement_selection == Game.vr_movement_speed.FAST:
		set_speed(4)
		set_turn_sensitivity(3)
	
	if multitoolcontrollerselection == MultiToolController.RIGHT:
		$RightHandController/RightMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		$RightHandController/RightHand.visible = false
		$LeftHandController/LeftHand.visible = true
		$LeftHandController/LeftHand/Hand_L/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = true
		$RightHandController/RightHand/Hand_R/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = false
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
		_off_handcontroller = ARVRHelpers.get_left_controller(self)
		
		
	else:
		$LeftHandController/LeftMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		$LeftHandController/LeftHand.visible = false
		$RightHandController/RightHand.visible = true
		$LeftHandController/LeftHand/Hand_L/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = false
		$RightHandController/RightHand/Hand_R/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = true
		_multitoolcontroller = ARVRHelpers.get_left_controller(self)
		_off_handcontroller = ARVRHelpers.get_right_controller(self)
	
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	
	
	_off_handcontroller.connect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.connect("button_release", Game, "_on_offhand_controller_button_released")
	
	Game.multitool.connect("switched_to", Game.UI, "switched_to_tool")
	
	tool_select_ui.connect("analyzer_button_pressed", Game.multitool, "_on_analyzer_handUI_button_pressed")
	tool_select_ui.connect("plant_button_pressed", Game.multitool, "_on_plant_handUI_button_pressed")
	tool_select_ui.connect("grow_button_pressed", Game.multitool, "_on_grow_handUI_button_pressed")
	
	movement_disabled = true
	var tween = get_tree().create_tween()
	tween.tween_property($ARVRCamera/FadeSphereMesh.get_surface_material(0), "albedo_color", Color(0,0,0,0), 10)
	yield(get_tree().create_timer(10), "timeout")
	$ARVRCamera/FadeSphereMesh.visible = false
	tween.kill()
	movement_disabled = false
	
func _process(delta):
	pass

func _physics_process(delta) -> void:
	if Game.game_state == Game.State.LOADING or Game.game_state == Game.State.INTRO_FLIGHT or Game.game_state == Game.State.WARPING:
		return 
	
	if player_body.ground_control_velocity.length() > footstep_thresh:
#		if Game.player_is_in_shed:
#			Audio.start_footsteps("wood")
#		else:
		var prefix: String = Game.planet.music_prefix
		
		
		Audio.start_footsteps(prefix)
	else:
		Audio.stop_footsteps()
		
	
	# If movement disabled variable set, disable movement providers
	if movement_disabled or Game.game_state != Game.State.INGAME:
		for provider in get_tree().get_nodes_in_group("movement_providers"):
			provider.enabled = false
		
	else:
		if Game.vr_hand_selection == Game.vr_primary_hand.LEFT:
			left_movement_direct.enabled = false
			right_movement_direct.enabled = true
			left_movement_jump.enabled = false
			right_movement_jump.enabled = true
			left_movement_turn.enabled = true
			right_movement_turn.enabled = false
			
		elif Game.vr_hand_selection == Game.vr_primary_hand.RIGHT:
			left_movement_direct.enabled = true
			right_movement_direct.enabled = false
			left_movement_jump.enabled = true
			right_movement_jump.enabled = false
			left_movement_turn.enabled = false
			right_movement_turn.enabled = true
			
	# If unlocked jetpack, let movement flight module know
	if unlocked_jetpack:
		if jetpack_fuel > 0.0:
			movement_flight.enabled = true
		else:
			movement_flight.enabled = false
	else:
		movement_flight.enabled = false
	
	if jetpack_fuel <= 0:
		trigger_jetpack = false
	
	if trigger_jetpack:
		jetpack_fuel -= delta * .7
		
	jetpack_light.visible = trigger_jetpack
	jetpack_flames.visible = trigger_jetpack
	jetpack_particles.emitting = trigger_jetpack
	
	
func set_multitool_controller(string_of_controller_side : String):
	_multitoolcontroller.disconnect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.disconnect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.disconnect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.disconnect("button_release", Game, "_on_offhand_controller_button_released")
	
	if string_of_controller_side == "left":
		$LeftHandController/LeftMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		$LeftHandController/LeftHand.visible = false
		$RightHandController/RightHand.visible = true
		$LeftHandController/LeftHand/Hand_L/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = false
		$RightHandController/RightHand/Hand_R/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = true
		_multitoolcontroller = ARVRHelpers.get_left_controller(self)
		_off_handcontroller = ARVRHelpers.get_right_controller(self)
		left_movement_direct.enabled = false
		right_movement_direct.enabled = true
		left_movement_jump.enabled = false
		right_movement_jump.emabled = true
		left_movement_turn.enabled = true
		right_movement_turn.enabled = false
		movement_flight._controller = movement_flight._right_controller
		
	elif string_of_controller_side == "right":
		$RightHandController/RightMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		$RightHandController/RightHand.visible = false
		$LeftHandController/LeftHand.visible = true
		$LeftHandController/LeftHand/Hand_L/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = true
		$RightHandController/RightHand/Hand_R/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = false
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
		_off_handcontroller = ARVRHelpers.get_left_controller(self)
		left_movement_direct.enabled = true
		right_movement_direct.enabled = false
		left_movement_jump.enabled = true
		right_movement_jump.emabled = false
		left_movement_turn.enabled = false
		right_movement_turn.enabled = true
		movement_flight._controller = movement_flight._left_controller
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.connect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.connect("button_release", Game, "_on_offhand_controller_button_released")


func set_speed(speed_number):
	$LeftHandController/MovementDirect.max_speed = speed_number
	$RightHandController/MovementDirect.max_speed = speed_number
	
	
func set_turn_sensitivity(turn_number):
	$LeftHandController/MovementTurn.smooth_turn_speed = turn_number
	$RightHandController/MovementTurn.smooth_turn_speed = turn_number
	if turn_number == 1:
		$LeftHandController/MovementTurn.turn_mode = $LeftHandController/MovementTurn.TurnMode.SNAP
		$RightHandController/MovementTurn.turn_mode = $RightHandController/MovementTurn.TurnMode.SNAP

func set_handmenu_distance(distance):
	if $LeftHandController.get_node("UI_Viewport2Dto3D") != null:
		$LeftHandController/UI_Viewport2Dto3D.transform.origin.z = distance
	else:
		$RightHandController.get_node("UI_Viewport2Dto3D").transform.origin.z = distance
	hand_tool_viewport.transform.origin.z = distance		
		
func _on_MovementFlight_flight_started():
	if not "jetpack" in Audio.playing:
		Audio.fade_in("jetpack", 0.1, true)
	trigger_jetpack = true


func _on_MovementFlight_flight_finished():
	if "jetpack" in Audio.playing:
		Audio.fade_out("jetpack", 0.1)
	trigger_jetpack = false
	yield(get_tree().create_timer(3.0), "timeout")
	jetpack_fuel = max_jetpack_fuel
