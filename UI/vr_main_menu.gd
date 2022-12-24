extends Spatial


onready var world = preload("res://Logic/MainScene.tscn")
onready var check_material = preload("res://addons/godot-xr-tools/materials/pointer.tres")
onready var loading_screen = $LoadingScreen
onready var title_logo = $TitleLabel3D
onready var shed = $Shed
onready var arvrcamera = $FPController/ARVRCamera
onready var cooldown = $MenuCoolDown
var ok_to_select : bool = true


func _ready():
	loading_screen.set_camera(arvrcamera)


func _on_LoadingScreen_continue_pressed():
	shed.global_transform.origin = $FPController.global_transform.origin
	title_logo.global_transform.origin = shed.global_transform.origin + Vector3(-1.5, 1.2, 0.5)
	loading_screen.visible = false
	shed.visible = true
	title_logo.visible = true


func _on_SlowMoveArea_area_entered(area):
	if ok_to_select == true:
		$Shed/SlowMoveArea/MeshInstance.set_surface_material(0, check_material)
		$Shed/MediumMoveArea/MeshInstance.set_surface_material(0, null)
		$Shed/FastMoveArea/MeshInstance.set_surface_material(0, null)
		Game.vr_movement_selection = Game.vr_movement_speed.SLOW
		ok_to_select = false
		cooldown.start()


func _on_MediumMoveArea_area_entered(area):
	if ok_to_select == true:
		$Shed/MediumMoveArea/MeshInstance.set_surface_material(0, check_material)
		$Shed/SlowMoveArea/MeshInstance.set_surface_material(0, null)
		$Shed/FastMoveArea/MeshInstance.set_surface_material(0, null)
		Game.vr_movement_selection = Game.vr_movement_speed.MEDIUM
		ok_to_select = false
		cooldown.start()


func _on_FastMoveArea_area_entered(area):
	if ok_to_select == true:
		$Shed/FastMoveArea/MeshInstance.set_surface_material(0, check_material)
		$Shed/SlowMoveArea/MeshInstance.set_surface_material(0, null)
		$Shed/MediumMoveArea/MeshInstance.set_surface_material(0, null)
		Game.vr_movement_selection = Game.vr_movement_speed.FAST
		ok_to_select = false
		cooldown.start()


func _on_LeftFunctionPickup_has_picked_up(what):
	yield(get_tree().create_timer(2.0), "timeout")
	$TransitionSound.play()
	yield(get_tree().create_timer(1), "timeout")
	shed.visible = false
	title_logo.visible = false
	ARVRServer.center_on_hmd(ARVRServer.DONT_RESET_ROTATION, true)
	yield(get_tree().create_timer(2), "timeout")
	Game.vr_hand_selection = Game.vr_primary_hand.LEFT
	$FPController.set_process_internal(false)
	get_tree().change_scene("res://Logic/MainScene.tscn")


func _on_RightFunctionPickup_has_picked_up(what):
	yield(get_tree().create_timer(2.0), "timeout")
	$TransitionSound.play()
	yield(get_tree().create_timer(1), "timeout")
	shed.visible = false
	title_logo.visible = false
	ARVRServer.center_on_hmd(ARVRServer.DONT_RESET_ROTATION, true)
	yield(get_tree().create_timer(2), "timeout")
	Game.vr_hand_selection = Game.vr_primary_hand.RIGHT
	$FPController.set_process_internal(false)
	get_tree().change_scene("res://Logic/MainScene.tscn")


func _on_MenuCoolDown_timeout():
	ok_to_select = true
