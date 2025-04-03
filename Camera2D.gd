extends Camera2D

var smoothing_time: float = 0.05
var target_position: Vector2 = global_position
var debug_printed: bool = false

func _ready() -> void:
	make_current()
	target_position = global_position
	print("Camera ready. Initial position: ", global_position)
	
	# Add camera to cameras group
	add_to_group("cameras")
	
	var room_manager = get_node_or_null("../RoomManager")
	if room_manager:
		room_manager.connect("room_changed", Callable(self, "_on_room_changed"))
		print("Connected to RoomManager signal.")
	else:
		print("Error: RoomManager not found!")

func _on_room_changed(new_room_center: Vector2) -> void:
	print("Room changed detected. New room center: ", new_room_center)
	target_position = new_room_center
	debug_printed = false

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, delta / smoothing_time)
	if not debug_printed and global_position.distance_to(target_position) < 1.0:
		print("Camera reached target: ", target_position)
		debug_printed = true
