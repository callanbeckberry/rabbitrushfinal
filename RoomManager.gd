extends Node2D

# Define each room's data.
# Rooms are arranged in three rows of four:
# Base row (row 1): centers at (0,0), (512,0), (1024,0), (1536,0)
# Row 2 (above): centers at (0,-512), (512,-512), (1024,-512), (1536,-512)
# Row 3 (top row): centers at (0,-1024), (512,-1024), (1024,-1024), (1536,-1024)
@export var room_data: Array = [
	{ "bounds": Rect2(-256, -256, 512, 512) },      # Room 1: Center (0,0)
	{ "bounds": Rect2(256, -256, 512, 512) },       # Room 2: Center (512,0)
	{ "bounds": Rect2(768, -256, 512, 512) },       # Room 3: Center (1024,0)
	{ "bounds": Rect2(1280, -256, 512, 512) },      # Room 4: Center (1536,0)
	{ "bounds": Rect2(-256, -768, 512, 512) },      # Room 5: Center (0,-512)
	{ "bounds": Rect2(256, -768, 512, 512) },       # Room 6: Center (512,-512)
	{ "bounds": Rect2(768, -768, 512, 512) },       # Room 7: Center (1024,-512)
	{ "bounds": Rect2(1280, -768, 512, 512) },      # Room 8: Center (1536,-512)
	{ "bounds": Rect2(-256, -1280, 512, 512) },     # Room 9: Center (0,-1024)
	{ "bounds": Rect2(256, -1280, 512, 512) },      # Room 10: Center (512,-1024)
	{ "bounds": Rect2(768, -1280, 512, 512) },      # Room 11: Center (1024,-1024)
	{ "bounds": Rect2(1280, -1280, 512, 512) }      # Room 12: Center (1536,-1024)
]

# We'll use player's global position as-is.
@export var player_offset: Vector2 = Vector2.ZERO
@export var tile_size: int = 32  # Not used directly here, but useful for reference.
@export var total_coins: int = 120  # The total number of coins in the game

# Room tracking
var current_room_data: Dictionary = {}
var current_room_index: int = -1

# Signals
signal room_changed(new_room_center: Vector2)

func _ready() -> void:
	var player = get_node_or_null("../Player")
	if player:
		# Update player with coin settings
		player.total_coins = total_coins
		
		# Find initial room
		current_room_data = _find_room(player.global_position - player_offset)
		if current_room_data != {}:
			var center = current_room_data["bounds"].position + current_room_data["bounds"].size * 0.5
			emit_signal("room_changed", center)
			print("Initial room: ", current_room_data["bounds"], " Center: ", center)
		else:
			print("Warning: Player is not inside any defined room!")
	else:
		print("Warning: Player not found in RoomManager _ready()!")

func _process(delta: float) -> void:
	var player = get_node_or_null("../Player")
	if player:
		var effective_pos = player.global_position - player_offset
		var new_room_data = _find_room(effective_pos)
		if new_room_data != {} and new_room_data != current_room_data:
			current_room_data = new_room_data
			var center = current_room_data["bounds"].position + current_room_data["bounds"].size * 0.5
			print("Room changed to: ", current_room_data["bounds"], " Center: ", center)
			emit_signal("room_changed", center)
	else:
		push_warning("Player not found in _process() of RoomManager.")

func _find_room(pos: Vector2) -> Dictionary:
	for i in range(room_data.size()):
		var data = room_data[i]
		var bounds: Rect2 = data["bounds"]
		if bounds.has_point(pos):
			current_room_index = i
			return data
	return {}

# Call this to place a final boss door
func place_final_boss_door(pos: Vector2) -> void:
	var final_door_scene = load("res://final_boss_door.tscn")
	if not final_door_scene:
		push_error("Failed to load final_boss_door.tscn")
		return
	
	var final_door = final_door_scene.instantiate()
	add_child(final_door)
	
	# Set up the door with the tilemap
	var tile_map = get_node_or_null("../TileMap")
	if tile_map:
		var grid_pos = tile_map.local_to_map(pos)
		final_door.setup(tile_map, grid_pos)
	else:
		final_door.position = pos
		push_warning("TileMap not found, placing final boss door without tile setup")
