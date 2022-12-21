extends Control

signal analyzer_button_pressed
signal plant_button_pressed
signal grow_button_pressed

var ok_to_press : bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_AnalyzerButton_pressed():
	if ok_to_press:
		ok_to_press = false
		emit_signal("analyzer_button_pressed")
		$CoolDownTimer.start()


func _on_PlantButton_pressed():
	if ok_to_press:
		ok_to_press = false
		emit_signal("plant_button_pressed")
		$CoolDownTimer.start()


func _on_GrowButton_pressed():
	if ok_to_press:
		ok_to_press = false
		emit_signal("grow_button_pressed")
		$CoolDownTimer.start()


func _on_CoolDownTimer_timeout():
	ok_to_press = true
