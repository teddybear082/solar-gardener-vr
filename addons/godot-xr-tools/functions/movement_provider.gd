tool
class_name XRToolsMovementProvider, "res://addons/godot-xr-tools/editor/icons/movement_provider.svg"
extends Node


##
## Movement Provider base class
##
## @desc:
##     This movement provider class is the base class of all movement providers.
##     Movement providers are invoked by the PlayerBody object in order to apply
##     motion to the player
##
##     Movement provider implementations should:
##      - Export an 'order' integer to control order of processing
##      - Override the physics_movement method to impelment motion
##


## Enable movement provider
export var enabled : bool = true


# Is the movement provider actively performing a move
var is_active := false


# If missing we need to add our XRToolsPlayerBody
func _create_player_body_node():
	# get our origin node
	var arvr_origin := ARVRHelpers.get_arvr_origin(self)
	if !arvr_origin:
		return

	# Double check if it hasn't already been created by another movement function
	var player_body := XRToolsPlayerBody.find_instance(self)
	if !player_body:
		# create our XRToolsPlayerBody node and add it into our tree
		var player_body_scene = preload("res://addons/godot-xr-tools/player/player_body.tscn")
		player_body = player_body_scene.instance()
		player_body.set_name("PlayerBody")
		arvr_origin.add_child(player_body)
		player_body.set_owner(get_tree().get_edited_scene_root())


# Add support for is_class on XRTools classes
func is_class(name : String) -> bool:
	return name == "XRToolsMovementProvider" or .is_class(name)


# Function run when node is added to scene
func _ready():
	# If we're in the editor, help the user out by creating our XRToolsPlayerBody node
	# automatically when needed.
	if Engine.editor_hint:
		var player_body = XRToolsPlayerBody.find_instance(self)
		if !player_body:
			# This call needs to be deferred, we can't add nodes during scene construction
			call_deferred("_create_player_body_node")


# Override this function to perform pre-movement updates to the PlayerBody
func physics_pre_movement(_delta: float, _player_body: XRToolsPlayerBody):
	pass


# Override this function to apply motion to the PlayerBody
func physics_movement(_delta: float, _player_body: XRToolsPlayerBody, _disabled: bool):
	pass


# This method verifies the movement provider has a valid configuration.
func _get_configuration_warning():
	# Verify we're within the tree of an ARVROrigin node
	if !ARVRHelpers.get_arvr_origin(self):
		return "This node must be within a branch on an ARVROrigin node"

	if !XRToolsPlayerBody.find_instance(self):
		return "Missing PlayerBody node on the ARVROrigin"

	# Verify movement provider is in the correct group
	if !is_in_group("movement_providers"):
		return "Movement provider not in 'movement_providers' group"

	# Verify order property exists
	if !"order" in self:
		return "Movement provider does not expose an order property"

	# Passed basic validation
	return ""
