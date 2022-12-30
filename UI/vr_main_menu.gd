extends Spatial


onready var world = preload("res://Logic/MainScene.tscn")
onready var check_material = preload("res://addons/godot-xr-tools/materials/pointer.tres")
onready var loading_screen = $LoadingScreen
onready var title_logo = $TitleLabel3D
onready var shed = $Shed
onready var arvrcamera = $FPController/ARVRCamera
onready var cooldown = $MenuCoolDown
var ok_to_select : bool = true
var quit_available : bool = false

func _ready():
	loading_screen.set_camera(arvrcamera)

func _process(delta):
	if not quit_available:
		return
		
	if quit_available and $Shed.visible == true:
		if $FPController/LeftHandController.is_button_pressed(XRTools.Buttons.VR_TRIGGER):
			get_tree().quit()
			
		if $FPController/RightHandController.is_button_pressed(XRTools.Buttons.VR_TRIGGER):
			get_tree().quit()


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
	Game.vr_hand_selection = Game.vr_primary_hand.LEFT
	$FPController.set_process_internal(false)
	$FPController/ARVRCamera/FadeSphereMesh.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property($FPController/ARVRCamera/FadeSphereMesh.get_surface_material(0), "albedo_color", Color(0,0,0,255), 1.5)
	yield(get_tree().create_timer(1.7), "timeout")
	get_tree().change_scene("res://Logic/MainScene.tscn")


func _on_RightFunctionPickup_has_picked_up(what):
	yield(get_tree().create_timer(2.0), "timeout")
	$TransitionSound.play()
	yield(get_tree().create_timer(1), "timeout")
	shed.visible = false
	title_logo.visible = false
	ARVRServer.center_on_hmd(ARVRServer.DONT_RESET_ROTATION, true)
	Game.vr_hand_selection = Game.vr_primary_hand.RIGHT
	$FPController.set_process_internal(false)
	$FPController/ARVRCamera/FadeSphereMesh.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property($FPController/ARVRCamera/FadeSphereMesh.get_surface_material(0), "albedo_color", Color(0,0,0,255), 1.5)
	yield(get_tree().create_timer(1.7), "timeout")
	tween.kill()
	get_tree().change_scene("res://Logic/MainScene.tscn")


func _on_MenuCoolDown_timeout():
	ok_to_select = true


func _on_QuitArea_body_entered(body):
	if body.get_parent().name == "PlayerBody":
		$Shed/QuitArea/QuitLabel3D.visible = true
		quit_available = true
	

func _on_QuitArea_body_exited(body):
	if body.get_parent().name == "PlayerBody":
		$Shed/QuitArea/QuitLabel3D.visible = false
		quit_available = false
