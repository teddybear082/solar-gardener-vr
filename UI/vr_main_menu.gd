extends Spatial


onready var world = preload("res://Logic/MainScene.tscn")
onready var loading_screen = $LoadingScreen
onready var title_logo = $TitleLabel3D
onready var shed = $Shed
onready var arvrcamera = $FPController/ARVRCamera
func _ready():
	loading_screen.set_camera(arvrcamera)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_LoadingScreen_continue_pressed():
	shed.global_transform.origin = $FPController.global_transform.origin
	title_logo.global_transform.origin = shed.global_transform.origin + Vector3(-1.5, 1.2, 0.5)
	loading_screen.visible = false
	shed.visible = true
	title_logo.visible = true


func _on_main_menu_tool_pickable_picked_up(pickable):
	yield(get_tree().create_timer(2.0), "timeout")
	$TransitionSound.play()
	yield(get_tree().create_timer(1), "timeout")
	shed.visible = false
	title_logo.visible = false
	ARVRServer.center_on_hmd(ARVRServer.DONT_RESET_ROTATION, true)
	yield(get_tree().create_timer(2), "timeout")
	get_tree().change_scene("res://Logic/MainScene.tscn")
