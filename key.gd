extends Area2D

class_name Key

var target_position = Vector2.ZERO
var is_moving = false
var tile_size = 32
var move_speed = 100
var following_player = false
var movement_history = []  # Stores the player's last positions
var max_history_length = 1  # distance behind player

# Reference to the player
var player = null

func _ready():
	add_to_group("key")

func _physics_process(delta):
	if is_moving:
		global_position = global_position.move_toward(target_position, move_speed * delta)
		if global_position.distance_to(target_position) < 1:
			global_position = target_position
			is_moving = false

func start_following(player_ref):
	player = player_ref
	following_player = true
	# Initialize the key's position to be 1 tile away from player
	var player_tile = player.get_current_tile()
	# For initial placement, we'll put it one tile below the player
	var initial_tile = player_tile + Vector2i(0, 1)
	global_position = player.tile_map.map_to_local(initial_tile) + Vector2(tile_size / 2, tile_size / 2)
	
	# Add initial position to history
	movement_history.append(global_position)

func update_position(player_last_position):
	if not following_player:
		return
		
	# Add the player's last position to our history
	movement_history.append(player_last_position)
	
	# Keep only the needed number of positions
	while movement_history.size() > max_history_length:
		movement_history.pop_front()
	
	# Move to the oldest position in our history
	if movement_history.size() > 0:
		target_position = movement_history[0]
		is_moving = true

func is_near_door(door_position):
	# Get current tile positions
	var key_tile = player.tile_map.local_to_map(global_position)
	var door_tile = player.tile_map.local_to_map(door_position)
	
	# Debug output
	print("Key tile position: ", key_tile)
	print("Door tile position: ", door_tile)
	
	# Check if adjacent (including diagonals)
	var distance = abs(key_tile.x - door_tile.x) + abs(key_tile.y - door_tile.y)
	print("Distance between key and door: ", distance)
	
	# Return true if distance is 1 (adjacent) or 2 (diagonal)
	return distance <= 2

func consume():
	# Called when the key is used to unlock a door
	following_player = false
	# Play animation or sound if needed
	# Then remove the key
	queue_free()
