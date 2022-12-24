extends Spatial

export var SKY_ENERGY_HTML5 := 0.04
export var SKY_ENERGY_NATIVE := 0.5

var planet_list := []
var skip_allowed := false

func _ready() -> void:
	if OS.has_feature("HTML5") or OS.get_name().to_lower() == "android":
		$WorldEnvironment.environment.background_energy = SKY_ENERGY_HTML5
	else:
		$WorldEnvironment.environment.background_energy = SKY_ENERGY_NATIVE
	
	Game.world = self
	PlantData.setup()
	PlantData.add_test_progress()
	Game.sun = $Sun
	for c in get_children():
		if c is Planet:
			(c as Planet).setup()
			(c as Planet).set_player_is_on_planet(false)
			planet_list.append(c)
	Game.planet = $Planet  # this is the starting planet
	Game.planet.set_player_is_on_planet(true)
	if OS.get_name().to_lower() == "android":
		var value = .5
		Game.world.get_node("Stars").visible = (value >= .7)
		for planet in Game.planet_list:
			planet = planet as Planet
			planet.render_multi_mesh = (value >= .7)
		Game.planet.trigger_lod(false)
		Game.main_scene.resolution_scaling_factor = value
		Game.main_scene.root_viewport_size_changed()
	start_loading()
	
#	$Planet/AudioStreamPlayer.play()

var INTRO_LENGTH_FACTOR = 1.15
var TEST_LENGTH_FACTOR = 0.02
const TEST_INTRO = true
func start_loading():
	if OS.is_debug_build() and (not TEST_INTRO):
		INTRO_LENGTH_FACTOR = TEST_LENGTH_FACTOR
	yield(get_tree(),"idle_frame")
	Game.UI.get_node("BlackScreen").visible = true
	Game.camera.current = false
	var loading_cams :Array = $LoadingCams.get_children()
	for i in range(len(loading_cams)):
		var cam: Camera = loading_cams[i]
		cam.current = true
		if cam.has_node("Ubershader"):
			cam.get_node("Ubershader").activate()
			yield(get_tree().create_timer(.4),"timeout")
		yield(get_tree().create_timer(.3),"timeout")
		if i == 0:
			for planet in planet_list:
				planet = planet as Planet
				planet.set_player_is_on_planet(not planet.player_on_planet)
				yield(get_tree().create_timer(.08),"timeout")
				planet.set_player_is_on_planet(not planet.player_on_planet)
				yield(get_tree().create_timer(.08),"timeout")
		cam.current = false
		cam.queue_free()
		Game.UI.set_loading_bar(float(i+1)/len(loading_cams))
	Game.UI.set_loading_bar(1.0)
#	yield(get_tree().create_timer(.3), "timeout")
	start_intro_flight()


var skipped = false
func start_intro_flight():
	Audio.fade_in("music_rock_2", 1.0)
	Game.set_game_state(Game.State.INTRO_FLIGHT)
	if (not OS.is_debug_build()) or TEST_INTRO:
		Dialog.play_intro()
	else:
		Game.UI.get_node("DialogUI/Controls/SubtitleText").text = ""
	
	Game.multitool.visible = false
	$"%FlyCamera".current = true

	$IntroFlight/Tween.interpolate_method(Game.UI, "set_blackscreen_alpha", 1.0, 0.0, 1.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$IntroFlight/Tween.start()
#	if (not OS.is_debug_build()) or TEST_INTRO:
#	yield(get_tree().create_timer(0.4), "timeout")
	$IntroFlight/AnimationPlayer.playback_speed = 1.0 / INTRO_LENGTH_FACTOR
	$IntroFlight/AnimationPlayer.play("fly")
	skip_allowed = true
#	yield($IntroFlight/Tween, "tween_all_completed")


	yield($IntroFlight/AnimationPlayer, "animation_finished")
	Game.UI.get_node("BlackScreen").visible = false
	if not skipped:
		end_intro_flight()
	
func end_intro_flight():
	$"%FlyCamera".current = false
	Game.camera.current = true
	Game.UI.get_node("SkipCutsceneLabel").visible = false
	Game.set_game_state(Game.State.INGAME)

	#Game.player.update_look_direction()
	Game.multitool.visible = true
	yield(get_tree().create_timer(.4),"timeout")
	Game.multitool.switch_tool(Game.multitool.TOOL.ANALYSIS)
	Game.intro_done = true
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and OS.has_feature("HTML5"):
		Game.main_scene.set_process_input(true)
		Game.UI.get_node("ClickToFocus").visible = true
		# in this case the intro only counts as done once this has been hidden
		Game.intro_done = false
	else:
		if Game.UI.has_node("ClickToFocus"):
			Game.UI.get_node("ClickToFocus").queue_free()
		
	Game.planet.fade_in()
	yield(get_tree().create_timer(2.0), "timeout")
	set_process(false)
	Audio.fade_out("music_rock_2", 1.0)
	if OS.is_debug_build() and not TEST_INTRO:
		Events.tutorial_beginning()
	
func _process(delta: float) -> void:
	if skip_allowed and Input.is_action_just_pressed("skip_cutscene"):
		if $SkipCutscene.is_stopped():
			$SkipCutscene.start(1.2)
			Game.UI.skip_button_held()
	elif Input.is_action_just_released("skip_cutscene"):
			$SkipCutscene.stop()
			Game.UI.skip_button_released()

func _on_SkipCutscene_timeout() -> void:
	Dialog.skip_intro()
	skipped = true
	$IntroFlight/Tween.reset_all()
	$IntroFlight/Tween.interpolate_method(Game.UI, "set_blackscreen_alpha", .0, 1.0, 0.7, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$IntroFlight/Tween.start()
	yield($IntroFlight/Tween, "tween_all_completed")
	end_intro_flight()
	$IntroFlight/Tween.reset_all()
	$IntroFlight/Tween.interpolate_method(Game.UI, "set_blackscreen_alpha", 1.0, 0.0, 1.3, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$IntroFlight/Tween.start()
	yield($IntroFlight/Tween, "tween_all_completed")
	Game.UI.get_node("BlackScreen").visible = false
	
	yield(get_tree().create_timer(2.5), "timeout")
	Events.tutorial_beginning()
	
	
func credits_animation(pivot: Spatial, duration: float):
	var tween = get_tree().create_tween()
	tween.tween_property(pivot, "rotation_degrees:y", pivot.rotation_degrees.y + 140, duration)
	tween.play()
