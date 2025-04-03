extends StaticBody2D

class_name LockedDoor

var tile_position: Vector2i
var tile_map = null
var is_unlocked = false

# Visual debugging options
var enable_debug_visuals = true
var debug_color = Color(0.8, 0.2, 0.2, 0.7)  # Semi-transparent red

func _ready():
	add_to_group("door")
	
	# If setup hasn't been called yet, try to find the tilemap automatically
	if tile_map == null:
		# Attempt to find the tilemap in the scene
		tile_map = get_node_or_null("/root/Main/TileMap")  # Adjust path as needed
		
		if tile_map:
			# Get our current position in tile coordinates
			tile_position = tile_map.local_to_map(global_position)
			print("LockedDoor automatically found tilemap and set position to:", tile_position)
		else:
			print("ERROR: LockedDoor couldn't find tilemap, please call setup() manually")
	
	# Create debug visuals
	if enable_debug_visuals:
		create_debug_visuals()

func setup(tilemap_ref, door_tile_position):
	tile_map = tilemap_ref
	tile_position = door_tile_position
	
	# Position the door at the center of the tile
	var tile_size = Vector2(32, 32)  # Default tile size, adjust if needed
	
	if tile_map and tile_map.tile_set:
		# Try to get tile size from tileset
		tile_size = tile_map.tile_set.tile_size
	
	global_position = tile_map.map_to_local(tile_position) + Vector2(tile_size.x / 2, tile_size.y / 2)
	
	print("LockedDoor positioned at global:", global_position)
	print("LockedDoor tile position:", tile_position)
	
	# Update debug visuals if already created
	if has_node("DebugLabel"):
		$DebugLabel.text = "DOOR (" + str(tile_position.x) + "," + str(tile_position.y) + ")"

func unlock():
	is_unlocked = true
	
	print("Door at tile position " + str(tile_position) + " unlocked!")
	
	# Remove the door collision
	$CollisionShape2D.set_deferred("disabled", true)
	
	if tile_map:
		# Update the tilemap - replace with walkable tile
		var walkable_tile_index = 1  # Adjust this to your actual walkable tile index
		tile_map.set_cell(0, tile_position, walkable_tile_index)
		
		print("Tilemap cell updated at position:", tile_position)
	else:
		print("WARNING: Cannot update tilemap cell, tilemap reference is null")
	
	# Animation if needed
	# $AnimationPlayer.play("unlock")
	
	# Sound effect if needed
	# $UnlockSound.play()
	
	# Fade out visuals
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)

func create_debug_visuals():
	# Add a visible sprite if none exists
	var sprite = get_node_or_null("Sprite2D")
	
	if not sprite:
		# Create a sprite if it doesn't exist
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
		
		# Create a simple colored square texture
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(debug_color)
		
		# Add a lock symbol
		for i in range(12, 20):
			for j in range(8, 24):
				if (j > 8 and j < 12) or (j > 20 and j < 24):
					img.set_pixel(i, j, Color.BLACK)
		
		for i in range(8, 24):
			for j in range(12, 20):
				img.set_pixel(i, j, Color.BLACK)
		
		var tex = ImageTexture.create_from_image(img)
		sprite.texture = tex
	
	# Add a label for identification
	var label = Label.new()
	label.name = "DebugLabel"
	
	# Include tile position in label if available
	if tile_position:
		label.text = "DOOR (" + str(tile_position.x) + "," + str(tile_position.y) + ")"
	else:
		label.text = "DOOR"
		
	label.position = Vector2(-30, -40)
	add_child(label)
	
	print("Debug visuals created for LockedDoor")

func _process(_delta):
	# Optional visualization for debugging (appears in _draw)
	if enable_debug_visuals:
		queue_redraw()

func _draw():
	# Only draw debug visuals when enabled
	if enable_debug_visuals:
		# Draw a visible outline
		var size = Vector2(32, 32)  # Default size, should match your tile size
		
		if tile_map and tile_map.tile_set:
			size = tile_map.tile_set.tile_size
			
		var rect = Rect2(-size.x/2, -size.y/2, size.x, size.y)
		draw_rect(rect, debug_color, false, 2)
		
		# Draw diagonals for visibility
		draw_line(Vector2(-size.x/2, -size.y/2), Vector2(size.x/2, size.y/2), Color(0.8, 0.2, 0.2, 0.8), 2)
		draw_line(Vector2(-size.x/2, size.y/2), Vector2(size.x/2, -size.y/2), Color(0.8, 0.2, 0.2, 0.8), 2)
