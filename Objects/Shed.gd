extends Spatial

var home_planet : Planet

func _ready():
	#yield(get_tree(),"idle_frame")
	if get_parent() is Planet:
		home_planet = get_parent() as Planet
		home_planet.add_to_lod_list(self)

func on_lod(lod_triggered: bool):
	var no_lod_meshes := [	$ModelShed/ShedSolarPanels,
							$ModelShed/ShedRoundWindow,
							$ModelShed/ShedRoof,
							$ModelShed/ShedRoofWoodenFoundation,
							$ModelShed/ShedBase,
							$ModelShed/ShedFoundation,
							$ModelShed/ShedFoundationPillar,
							$ModelShed/ShedWoodenPilar,
							]

	for c in $ModelShed.get_children():
		if not c in no_lod_meshes:
			c.visible = not lod_triggered
	$OmniLight.visible = not lod_triggered
	$ScreenTexts.visible = not lod_triggered

func update_shed_info():
#	$ScreenTexts/Label1.text = "Loading..."
#	$ScreenTexts/Label2.text = "Loading..."
#	$ScreenTexts/Label3.text = "Loading..."
#	$ScreenTexts/Label4.text = "Loading..."
#	$ScreenTexts/Label5.text = "Loading..."
#	$ScreenTexts/Label6.text = "Loading..."
#	yield(get_tree().create_timer(.8),"timeout")

	var stats_string : String = "Seeds planted:\n" + str(Events.get_event_from_key("seed_planted").execute_count)
	stats_string = stats_string + "\n\n" + "Plants discovered:\n" + str(len(Game.journal.scanned_plant_names))
	$ScreenTexts/Label1.text = stats_string
	yield(get_tree().create_timer(.1),"timeout")
	$ScreenTexts/Label3.text = "Need\nhelp?" 
	yield(get_tree().create_timer(.1),"timeout")
	$ScreenTexts/Label5.text = "Open the\nGuide tab\nin the\njournal!" 
	yield(get_tree().create_timer(.1),"timeout")
	$ScreenTexts/Label6.text = Upgrades.get_upgrades_screen_text()
	if Upgrades.is_upgrade_available():
		$UpgradeStation.set_open(true)

func set_upgrade_screen(text: String):
	$ScreenTexts/Label6.text = text#Upgrades.get_upgrades_screen_text()


func _on_PlayerDetectArea_body_entered(body):
	if body is Player:
		Game.player_is_in_shed = true
		update_shed_info()
		body.shed = self
		$PlayerOrientationTween.remove_all()
		$PlayerOrientationTween.interpolate_property(body, "shed_factor", body.shed_factor, 1.0, 1.0, Tween.TRANS_QUAD,Tween.EASE_IN_OUT)
		$PlayerOrientationTween.start()


func _on_PlayerDetectArea_body_exited(body):
	if body is Player:
		Game.player_is_in_shed = false
		$PlayerOrientationTween.remove_all()
		$PlayerOrientationTween.interpolate_property(body, "shed_factor", body.shed_factor, 0.0, 1.0, Tween.TRANS_QUAD,Tween.EASE_IN_OUT)
		$PlayerOrientationTween.start()
