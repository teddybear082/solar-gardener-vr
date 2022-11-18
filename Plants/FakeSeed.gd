extends Spatial

export var scale_factor := .4

func setup(seed_name: String):
	var profile: PlantProfile = PlantData.profiles[seed_name]
	var seed_model = profile.model_seed.instance()
	add_child(seed_model)
	seed_model.scale = Vector3.ONE * scale_factor
