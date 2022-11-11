extends Node

const MODELS_FOLDER = "res://Assets/Models/"

enum State {
	INGAME,
	SETTINGS,  # aka paused
	JOURNAL,
	MAIN_MENU, # if it's needed 
	WARPING,
	READING_NOTE,
	LOADING,
	INTRO_FLIGHT,
}

var game_state = State.LOADING setget set_game_state
# is set from MainScene, if this is false, a subscene is running individually for testing,
# if this is true game is running normally
var main_scene_running = false
var main_scene = null
# is set when main_scene_running
var UI: UI = null
var player : Player = null
var player_raycast: PlayerRayCast
var multitool#: Multitool
var camera: PlayerCamera
var crosshair: Crosshair
var sun: Spatial
# current planet
var planet: Planet = null
var invert_y_axis = false

var planet_list := []

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("open_settings"):  # show/hide settings UI
		if main_scene_running:
			if game_state == State.INGAME:
				self.game_state = State.SETTINGS
#			elif game_state == State.SETTINGS:
#				# this is only the correct if you can only enter settings from ingame!!
#				self.game_state = State.INGAME
	if Input.is_action_just_pressed("open_journal"):
		if game_state == State.INGAME:
			self.game_state = State.JOURNAL
		elif game_state == State.JOURNAL:
			# this is only the correct if you can only enter settings from ingame!!
			self.game_state = State.INGAME
			
	if OS.is_debug_build() and Input.is_action_just_pressed("give_seeds"):
		print("gib tzieds")
		PlantData.give_seeds("A Seedling", 10)
	if OS.is_debug_build() and Input.is_action_just_pressed("make_pref_known"):
		print("pref known")
		UI.get_node("JournalUI").make_preference_known("A Seedling", PlantData.PREFERENCES["Hates Sun"])
	if OS.is_debug_build() and Input.is_action_just_pressed("play_intro"):
		print("play intro")
		Dialog.play_intro()
		
	if OS.is_debug_build() and Input.is_action_just_pressed("unlock_all_tools"):
		print("unlock all tools")
		Game.multitool.activate_tool(Game.multitool.TOOL.GROW)
		Game.multitool.activate_tool(Game.multitool.TOOL.PLANT)
		

signal changed_state(state, prev_state)
func set_game_state(state):
	# complicated way since there may be special actions needed per state
	# or sometimes the new state shouldn't be set maybe if it doesn't make sense
	# stuff like mouse capturing could go here so that it's only done in one special position
	# (though note that on web browsers the first mouse capture has to be done in _input() !)
	var prev_state = game_state
	game_state = state
	
	emit_signal("changed_state", state, prev_state)


func is_ingame():
	return game_state == State.INGAME

var slerp_player_basis_a : Basis
var slerp_player_basis_b : Basis
func slerp_player_basis(f: float):
	player.global_transform.basis = slerp_player_basis_a.slerp(slerp_player_basis_b, f)

func execute_planet_hop(new_planet: Planet, pos: Vector3):
	#pos = new_planet.global_translation + new_planet.global_translation.direction_to(player.global_translation) * 10.0 - player.global_transform.basis.y * 2.0
	var dir_to_planet = player.global_translation.direction_to(new_planet.global_translation)
	pos = new_planet.global_translation + player.global_translation.direction_to(pos).cross(-dir_to_planet).cross(dir_to_planet).normalized() * 11.0
	set_game_state(State.WARPING)
	planet.set_player_is_on_planet(false)
	new_planet.set_player_is_on_planet(true)
	planet = new_planet
	#player.global_transform = Transform(new_basis, pos)
	var current_y_looking_angle : float = player.get_node("Head").rotation.x
	var target_y_looking_angle : float = -deg2rad(90.0) + player.global_translation.direction_to(pos).angle_to(pos.direction_to(planet.global_translation))
	slerp_player_basis_a = player.global_transform.basis
	slerp_player_basis_b = Utility.get_basis_y_aligned_with_z(new_planet.global_translation.direction_to(pos), -player.global_transform.basis.z) 
	$WarpTween.interpolate_method(self, "slerp_player_basis", 0.0, 1.0, 1.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	$WarpTween.interpolate_property(player, "global_translation", player.global_translation, pos, 1.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	$WarpTween.interpolate_property(player.get_node("Head"), "rotation:x", current_y_looking_angle, target_y_looking_angle, 1.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	$WarpTween.start()
	yield($WarpTween, "tween_all_completed")
	player.update_look_direction()
	set_game_state(State.INGAME)
