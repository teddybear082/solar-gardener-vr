tool
class_name XRToolsMovementWallWalk
extends XRToolsMovementProvider


## Wall walking provider order
export var order : int = 25

## Set our follow layer mask
export (int, LAYERS_3D_PHYSICS) var follow_mask : int = 8

## Wall stick distance
export var stick_distance : float = 1.0

## Wall stick strength
export var stick_strength : float = 9.8



func physics_pre_movement(delta: float, player_body: XRToolsPlayerBody):
	# Test for collision with wall under feet
	var wall_collision := player_body.kinematic_node.move_and_collide(
		player_body.up_player_vector * -stick_distance, true, true, true)
	if !wall_collision:
		return

	# Get the wall information
	var wall_node := wall_collision.collider
	var wall_normal := wall_collision.normal

	# Skip if the wall node doesn't have a collision layer
	if not "collision_layer" in wall_node:
		return

	# Skip if the wall doesn't match the follow layer
	var wall_layer : int = wall_node.collision_layer
	if (wall_layer & follow_mask) == 0:
		return

	# Modify the player gravity
	player_body.gravity = -wall_normal * stick_strength
