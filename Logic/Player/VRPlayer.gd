extends "res://addons/godot-openxr/scenes/first_person_controller_vr.gd"
class_name VRPlayer

signal player_got_hurt

enum MultiToolController {
	LEFT,		# Use left controller
	RIGHT,		# Use right controler
}

export (MultiToolController) var multitoolcontrollerselection : int = MultiToolController.RIGHT


export var unlocked_jetpack := false


onready var player_body = get_node("Player-cage")
onready var pickup_point : Spatial = $"%PickupPoint"
onready var hand_tool_viewport = $MultitoolHolder/Multitool/HandToolViewport
onready var tool_select_ui = hand_tool_viewport.get_scene_instance()

var movement_disabled : bool = false
var gravity_effect_max_dist = 40
var gravity_direction = 0.0
var trigger_jetpack : bool = false
const footstep_thresh = 0.2
var _multitoolcontroller : ARVRController
var _off_handcontroller : ARVRController
var function_pointer = null

func _ready():
	Game.vrplayer = self
	Game.player = self
	Game.camera = get_node("ARVRCamera")
	Game.multitool = $MultitoolHolder/Multitool
	Game.player_raycast = $MultitoolHolder/Multitool/PlayerRayCast
	Game.UI = $LeftHandController/UI_Viewport2Dto3D.get_scene_instance()#Game.camera.get_node("UI_Viewport2Dto3D").get_scene_instance()
	
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
	
	# If unlocked jetpack, let player-cage know to impact movement
	if unlocked_jetpack:
		player_body.unlocked_jetpack = true
	else:
		player_body.unlocked_jetpack = false
	
	
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
		
	elif string_of_controller_side == "right":
		$RightHandController/RightMultiToolRemoteTransform.set_remote_node($MultitoolHolder.get_path())
		$RightHandController/RightHand.visible = false
		$LeftHandController/LeftHand.visible = true
		$LeftHandController/LeftHand/Hand_L/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = true
		$RightHandController/RightHand/Hand_R/Armature/Skeleton/IndexBoneAttachment/Poke.enabled = false
		_multitoolcontroller = ARVRHelpers.get_right_controller(self)
		_off_handcontroller = ARVRHelpers.get_left_controller(self)
		
	
	_multitoolcontroller.connect("button_pressed", Game.multitool, "_on_vr_multitool_controller_button_pressed")
	_multitoolcontroller.connect("button_release", Game.multitool, "_on_vr_multitool_controller_button_released")
	_off_handcontroller.connect("button_pressed", Game, "_on_offhand_controller_button_pressed")
	_off_handcontroller.connect("button_release", Game, "_on_offhand_controller_button_released")
	
