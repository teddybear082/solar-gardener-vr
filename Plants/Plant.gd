extends Spatial
class_name Plant

const DEFAULT_GROW_SPEED = 1.0/20.0
const BOOSTED_GROW_SPEED = 1.0/2.0
const DEFAULT_MODEL_SCALE = .9
const GROWTH_UP_SCALE_FACTOR = 1.2
const GROWTH_DOWN_SCALE_FACTOR = .7
const SEED_START_POINT = .1
const SEED_SINK_DISTANCE = .2

var profile: PlantProfile

var growth_points: int = 0
var growth_stage: int = PlantData.GROWTH_STAGES.SEED
var growth_lock: int = PlantData.GROWTH_STAGES.SEED
var growth_stage_progress: float = 0.0

var planet: Planet

var model_seed: Spatial
var model_stage_1: Spatial
var model_stage_2: Spatial
var model_stage_3: Spatial
var model_stage_4: Spatial

var model_array: Array
var current_model: Spatial

var analyse_name : String

var is_setup := false
func setup():
	model_seed = profile.model_seed.instance()
	model_stage_1 = profile.model_stage_1.instance()
	model_stage_2 = profile.model_stage_2.instance()
	model_stage_3 = profile.model_stage_3.instance()
	model_stage_4 = profile.model_stage_4.instance()
	model_array = [model_seed, model_stage_1, model_stage_2, model_stage_3, model_stage_4]
	for model in model_array:
		model.visible = false
		add_child(model)

	model_seed.translation += Vector3.UP * SEED_START_POINT

	current_model = model_seed
	current_model.visible = true
	
	analyse_name = profile.name
	
	is_setup = true

func _physics_process(delta):
	growth_process(delta)

func growth_process(delta):
	if growth_stage == growth_lock:
		check_conditions()
	if growth_stage != growth_lock and $GrowthCooldown.time_left == 0.0:
		grow(delta, sign(growth_lock - growth_stage))

func calculate_growth_points():
	var points := 0
	# SOIL TYPE
	if profile.prefered_soil == PlantData.SOIL_TYPES.ANY:
		points += 1
	elif profile.prefered_soil == PlantData.SOIL_TYPES.NONE:
		points += 0
	elif profile.prefered_soil == planet.soil_type:
		points += 1
	
	# SUN
	if profile.sun == PlantData.PREFERENCE.ALWAYS_FALSE:
		points += 0
	elif profile.sun == PlantData.PREFERENCE.ALWAYS_TRUE:
		points += 1
	elif profile.sun == PlantData.PREFERENCE.LIKES:
		points += 1 if planet.sun else 0
	elif profile.sun == PlantData.PREFERENCE.HATES:
		points += 1 if not planet.sun else 0
	
	# MOIST
	if profile.moisture == PlantData.PREFERENCE.ALWAYS_FALSE:
		points += 0
	elif profile.moisture == PlantData.PREFERENCE.ALWAYS_TRUE:
		points += 1
	elif profile.moisture == PlantData.PREFERENCE.LIKES:
		points += 1 if planet.moist else 0
	elif profile.moisture == PlantData.PREFERENCE.HATES:
		points += 1 if not planet.moist else 0
	
	# NUTRI
	if profile.nutrients == PlantData.PREFERENCE.ALWAYS_FALSE:
		points += 0
	elif profile.nutrients == PlantData.PREFERENCE.ALWAYS_TRUE:
		points += 1
	elif profile.nutrients == PlantData.PREFERENCE.LIKES:
		points += 1 if planet.nutrients else 0
	elif profile.nutrients == PlantData.PREFERENCE.HATES:
		points += 1 if not planet.nutrients else 0
	
	# GROUP TODO
	if profile.group == PlantData.PREFERENCE.ALWAYS_FALSE:
		points += 0
	elif profile.group == PlantData.PREFERENCE.ALWAYS_TRUE:
		points += 1
	elif profile.group == PlantData.PREFERENCE.LIKES:
		points += 1 if planet.get_count_of_plant_type(profile.name) >= 5 else 0
	elif profile.group == PlantData.PREFERENCE.HATES:
		points += 1 if planet.get_count_of_plant_type(profile.name) < 5 else 0
	
func check_conditions():
	calculate_growth_points()
	if growth_points >= profile.points_for_stage_4:
		growth_lock = PlantData.GROWTH_STAGES.STAGE_4
	elif growth_points >= profile.points_for_stage_3:
		growth_lock = PlantData.GROWTH_STAGES.STAGE_3
	elif growth_points >= profile.points_for_stage_2:
		growth_lock = PlantData.GROWTH_STAGES.STAGE_2
	elif growth_points >= profile.points_for_stage_1:
		growth_lock = PlantData.GROWTH_STAGES.STAGE_1
	else:
		growth_lock = PlantData.GROWTH_STAGES.SEED

signal growth_stage_reached()
var growth_boost := false
func grow(delta, factor_sign):
	if growth_boost:
		growth_stage_progress += BOOSTED_GROW_SPEED * delta * factor_sign
	else:
		growth_stage_progress += DEFAULT_GROW_SPEED * delta * factor_sign
	growth_boost = false
	update_growth_visuals()
	if abs(growth_stage_progress) >= 1.0:
		$GrowthCooldown.start()
		var old_stage := growth_stage
		growth_stage = growth_stage + int(factor_sign * 1.1) # "* 1.1" to avoid float error nonsense
		current_model = model_array[growth_stage]
		growth_stage_progress = 0.0
		play_growth_pop_animation(old_stage)
		PlantData.growth_stage_reached(profile.name, growth_stage)
		
func play_growth_pop_animation(old_stage):
	model_array[old_stage].visible = false
	model_array[old_stage].scale = Vector3.ONE * DEFAULT_MODEL_SCALE
	current_model.scale = Vector3.ONE * DEFAULT_MODEL_SCALE
	current_model.visible = true
	# TODO Animation

func update_growth_visuals():
	if growth_stage == 0:
		model_seed.translation.y = SEED_START_POINT - SEED_SINK_DISTANCE * growth_stage_progress
	else:
		var scale_vector := Vector3.ONE
		if growth_stage_progress <= 0.0:
			scale_vector *= lerp(DEFAULT_MODEL_SCALE, GROWTH_DOWN_SCALE_FACTOR, -growth_stage_progress)
		else:
			scale_vector *= lerp(DEFAULT_MODEL_SCALE, GROWTH_UP_SCALE_FACTOR, growth_stage_progress)
		current_model.scale = scale_vector

const FLYING_PICKUP = preload("res://Objects/FlyingPickup.tscn")

func on_remove():
	var pickup = FLYING_PICKUP.instance()
	Game.planet.add_child(pickup)
	pickup.global_transform.basis = Utility.get_basis_y_aligned(Game.planet.global_translation.direction_to(self.global_translation))
	pickup.global_translation = self.global_translation
	pickup.setup_as_seed(profile.name)

	$RemoveTween.interpolate_property(self, "scale", Vector3.ONE, Vector3.ONE * .01, 2.5)
	$RemoveTween.start()
	yield(get_tree().create_timer(1.5), "timeout")
	pickup.start_flying()
	yield($RemoveTween, "tween_all_completed")
	queue_free()
