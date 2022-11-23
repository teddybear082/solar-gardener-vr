extends Node

# IMPORTANT NOTE: this is dangerous, I can't even explain it properly, see this thread
# guide: https://github.com/godotengine/godot/issues/25672#issuecomment-461541415
export var sound_directoy = "res://Assets/Sound"

var num_players = 32

var available = []  # The available players, instances of type AudioPlayerWithInfo
var queue = []  # The queue of sounds to play.
var playing = {} # The players that are currently active, indexed by the sound name

var MANAGED_SOUND_SCENE = preload("res://Logic/Sound/ManagedSound.tscn")
var CUSTOM_AUDIO_PLAYER = preload("res://Logic/Sound/CustomAudioPlayer.tscn")

func _ready():
	# Generate as many audio players as said in the variable
	for i in num_players:
		var custom_player = CUSTOM_AUDIO_PLAYER.instance()
		$Players.add_child(custom_player, true)
		available.append(custom_player)
	
	print("Loading Sounds:")
	var dir = Directory.new()
	if dir.open(sound_directoy) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".ogg") or (OS.has_feature("standalone") and file_name.ends_with(".import")):
				if OS.has_feature("standalone"):  # hack -> see first comment of this file
					file_name = file_name.split(".import")[0]
				var node_name = file_name.split(".")[0]
				print("Loaded ", file_name)
				if not $Sounds.has_node(node_name): # sound has no custom config in Sounds
					var managed_sound = MANAGED_SOUND_SCENE.instance()
					managed_sound.name = node_name
					managed_sound.stream = load("res://Assets/Sound/" + file_name)
					$Sounds.add_child(managed_sound, true)
				else: # sound exists in Sounds
					var managed_sound = $Sounds.get_node(node_name)
					managed_sound.stream = load("res://Assets/Sound/" + file_name)
			file_name = dir.get_next()
	else:
		print("An error encountered loading the sounds")
	setup_footsteps()
	
func play(sound_name: String):
	queue.append(sound_name)

func stop(sound_name: String):
	if not sound_name in playing:
		printerr("stopping sound " + sound_name + " that isn't playing")
		return
		
	playing[sound_name].stop()
#
func set_volume(sound_name, volume):
	for player_with_info in playing:
#		print(stream_tuple.sound.file_name)
		if player_with_info.sound.name == sound_name:
			player_with_info.set_volume_db(volume)
			

#
func _process(delta):
#	# Play a queued sound if any players are available.
	if not queue.empty() and not available.empty():
		var sound_name = queue.pop_front()
		var player = available.pop_front()
		# Reset all player variables

		player.stream = $Sounds.get_node(sound_name).stream
		player.sound = $Sounds.get_node(sound_name)
		player.play()
		playing[sound_name] = player

	
#######################
### UTILITY METHODS ###
#######################
func fade_in(sound_name: String, fade_duration:=1.0, random_start:=false):
	if available.empty():
		printerr("No available players to play " + sound_name)
		return
	if sound_name in playing:
#		print("sound " + sound_name + " tried fading in twice")
		return

	var player: CustomAudioPlayer = available.pop_front()
	player.stream = $Sounds.get_node(sound_name).stream
	player.sound = $Sounds.get_node(sound_name)
	if random_start:
		player.fade_in(randf() * player.sound.stream.get_length(), fade_duration)
	else:
		player.fade_in(0.0, fade_duration)
	playing[sound_name] = player

func fade_out(sound_name: String, fade_duration:=1.0):
	if not sound_name in playing:  # don't know if this should be an error
#		printerr(sound_name + " not playing (trying fade_out)")
		return
	var player: CustomAudioPlayer = playing[sound_name]
	player.fade_out(fade_duration)
	
func fade_in_and_out(sound_name: String, play_duration: float, fade_duration:=1.0, random_start:=false):
	# play a sound for play duration, then fade out
	# TODO
	pass

func cross_fade(sound_name_out: String, sound_name_in: String, fade_duration:=1.0):
	fade_in(sound_name_in, fade_duration)
	fade_out(sound_name_out, fade_duration)

	
func play_attenuated(sound_name:String, distance:float):
	var sound: ManagedSound = $Sounds.get_node(sound_name)
	var max_dist = sound.max_distance_when_attenuated
	
	var player: CustomAudioPlayer = available.pop_front()
	player.sound = sound
	player.stream = sound.stream
	player.play()
	player.volume_db = linear2db(1.0 - distance/max_dist)
	print("playing at " + str(linear2db(1.0 - distance/max_dist)) + " db")
	
################################
### GAME SPECIFIC EXTENSIONS ###
################################
export var footstep_directory = "res://Assets/Sound/Footsteps/"
var number_per := {"dirt": 5, "obsidian": 7, "rock": 5, "sand": 5, "wood": 6}
var steps_per_second := 2.0 
var step_volume_db := -12.0
var variation = 0.28
# TODO add randomness to the steps per second timer !!!
var current_planet_type: String
onready var timer: Timer = $GameSpecific/FootstepTimer
func start_footsteps(planet_type: String):
	if planet_type == "placeholder":
		current_planet_type = "sand"
	if not timer.is_stopped():
		return
	current_planet_type = planet_type
	play_random_step()
	timer.start(1.0 / steps_per_second)

func play_random_step(planet_type: String = ""):
	if planet_type != "":
		current_planet_type = planet_type
	var step_no: int = (randi() % number_per[current_planet_type]) + 1
	var step_name = "steps_%s_%02d" % [current_planet_type, step_no]
	play(step_name)

func stop_footsteps():
	timer.stop()

func _on_FootstepTimer_timeout() -> void:
	timer.wait_time = 1.0/steps_per_second * (1.0 + (0.5 - randf()) * variation) 
	play_random_step()

func setup_footsteps():
	# Generate as many audio players as said in the variable
	print("Loading Footsteps..")
	var dir = Directory.new()
	if dir.open(footstep_directory) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".ogg") or (OS.has_feature("standalone") and file_name.ends_with(".import")):
				if OS.has_feature("standalone"):  # hack -> see first comment of this file
					file_name = file_name.split(".import")[0]
				var node_name = file_name.split(".")[0]
				if not $Sounds.has_node(node_name): # sound has no custom config in Sounds
					var managed_sound = MANAGED_SOUND_SCENE.instance()
					managed_sound.name = node_name
					managed_sound.stream = load(footstep_directory + file_name)
					managed_sound.volume_db = step_volume_db
					$Sounds.add_child(managed_sound, true)
				else: # sound exists in Sounds
					var managed_sound = $Sounds.get_node(node_name)
					managed_sound.stream = load(footstep_directory + file_name)
			file_name = dir.get_next()
	else:
		print("An error encountered loading the sounds")
	print("Done loading Footsteps!")


