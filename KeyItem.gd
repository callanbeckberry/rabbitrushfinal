extends Area2D

class_name KeyItem

# Visual debugging options
#var enable_debug_visuals = true
#var debug_color = Color(1, 0.7, 0, 0.7)  # Semi-transparent gold

func _ready():
	add_to_group("key_item")
	
	# Connect signal for player collection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Print position for debugging
	print("KeyItem initialized at position:", global_position)
	print("KeyItem tile position:", get_tile_position())
	
	# Create debug visuals if needed
	#if enable_debug_visuals:
	#	create_debug_visuals()

func _on_body_entered(body):
	if body.is_in_group("player"):
		collect(body)

func _on_area_entered(area):
	if area.is_in_group("player"):
		var player = area.get_parent() if area.get_parent().is_in_group("player") else area
		collect(player)

func collect(player):
	print("Player collected key item!")
	
	# Check if player already has a key - FIXED THIS LINE
	if "has_key" in player and player.has_key:
		print("Player already has a key, not collecting another one")
		return
	
	# Check if the player has the required method
	if player.has_method("spawn_and_attach_key"):
		# Spawn the following key
		player.spawn_and_attach_key()
		
		# Play collection sound/animation if needed
		# $CollectSound.play()
		
		# Remove the key item
		queue_free()
	else:
		print("ERROR: Player object doesn't have spawn_and_attach_key method!")

func get_tile_position():
	# Get the tilemap
	var tilemap = get_node_or_null("/root/Main/TileMap") # Adjust the path as needed
	if tilemap:
		return tilemap.local_to_map(global_position)
	return Vector2i(0, 0)

#func create_debug_visuals():
	# Add a visible sprite if none exists
	#var sprite = get_node_or_null("Sprite2D")
	
	#if not sprite:
		# Create a sprite if it doesn't exist
		#sprite = Sprite2D.new()
		#sprite.name = "Sprite2D"
		#add_child(sprite)
		
		# Create a simple colored square texture
		#var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		#img.fill(debug_color)
		
		# Add a simple pattern to make it recognizable
		#for i in range(32):
			#img.set_pixel(i, i, Color.BLACK)
			#img.set_pixel(i, 31-i, Color.BLACK)
		
		#var tex = ImageTexture.create_from_image(img)
		#sprite.texture = tex
	
	# Add a label for identification
	#var label = Label.new()
	#label.name = "DebugLabel"
	#label.text = "KEY ITEM"
	#label.position = Vector2(-30, -40)
	#add_child(label)
	#print("Debug visuals created for KeyItem")

#func _process(_delta):
	# Optional visualization for debugging (appears in _draw)
	#if enable_debug_visuals:
		#queue_redraw()

#func _draw():
	# Only draw debug visuals in the editor or if enabled
	#if enable_debug_visuals:
		# Draw a visible outline
		#var radius = 20
		#draw_circle(Vector2.ZERO, radius, Color(1, 1, 0, 0.3))
		#draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0.7, 0, 0.8), 2)
		
		# Draw axes for position reference
		#draw_line(Vector2(-20, 0), Vector2(20, 0), Color(1, 0, 0, 0.8), 2)
		#draw_line(Vector2(0, -20), Vector2(0, 20), Color(0, 1, 0, 0.8), 2)
