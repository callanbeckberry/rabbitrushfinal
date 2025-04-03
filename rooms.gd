extends Area2D

@export var room_center: Vector2  # Set this in the editor for each room.
signal room_entered(room_center: Vector2)

func _ready() -> void:
	print("Room ready: ", name, " with center set to: ", room_center)
	connect("body_entered", Callable(self, "_on_body_entered"))
	
	# Check if the player is already overlapping this room at startup.
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			print("Player already in room: ", name, ". Emitting 'room_entered' signal.")
			emit_signal("room_entered", room_center)
			break  # We only need to emit it once.

func _on_body_entered(body):
	print("Body entered room: ", body.name, " Groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("Player detected in room: ", name, ". Emitting 'room_entered' signal with center: ", room_center)
		emit_signal("room_entered", room_center)
