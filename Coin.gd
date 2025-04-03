extends Area2D

var collected = false
var float_speed = 2.0  # Speed of the floating animation
var float_amplitude = 2.0  # How high/low the coin floats
var initial_y = 0.0  # Store the initial y position

func _ready():
	# Store the initial position
	initial_y = position.y
	
	# Add to collectibles group
	add_to_group("collectibles")
	
	# Connect to the collision signals
	connect("body_entered", _on_body_entered)
	connect("area_entered", _on_area_entered)
	
	# Create debug visuals if needed
	if not has_node("Sprite2D") or get_node("Sprite2D").texture == null:
		create_debug_visual()

func _process(delta):
	# Floating up and down animation
	if not collected:
		var offset = sin(Time.get_ticks_msec() * 0.002 * float_speed) * float_amplitude
		position.y = initial_y + offset

func _on_body_entered(body):
	if body.is_in_group("player") and not collected:
		collect(body)

func _on_area_entered(area):
	if area.is_in_group("player") and not collected:
		var player = area.get_parent() if area.get_parent().is_in_group("player") else area
		collect(player)

func collect(player):
	if collected:
		return
		
	# Prevent multiple collections
	collected = true
	
	print("Coin collected!")
	
	# Check if player has an add_coin method
	if player.has_method("add_coin"):
		player.add_coin()
		
		# Play collection animation - float upward and fade out
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 20, 0.3)
		tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.3)
		
		# Remove the coin after animation completes
		await tween.finished
		queue_free()
	else:
		print("Player doesn't have add_coin method!")
		# If player doesn't have add_coin method, just remove the coin
		queue_free()

func create_debug_visual():
	# Create a yellow coin sprite if none exists
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	
	# Create a yellow circle texture
	var img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Start with transparent
	
	# Draw a gold coin
	var center = Vector2(12, 12)
	var radius = 10
	var coin_color = Color(1.0, 0.9, 0.2)  # Gold color
	var outline_color = Color(0.9, 0.7, 0.1)  # Darker gold for outline
	
	# Draw outline
	for x in range(24):
		for y in range(24):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist <= radius and dist >= radius - 2:
				img.set_pixel(x, y, outline_color)
	
	# Draw coin body
	for x in range(24):
		for y in range(24):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist < radius - 2:
				img.set_pixel(x, y, coin_color)
	
	# Create inner details to make it look like a coin
	for i in range(radius-4):
		var angle = PI / 4  # 45 degrees
		var length = i * 0.8
		var x1 = center.x + cos(angle) * length
		var y1 = center.y + sin(angle) * length
		var x2 = center.x - cos(angle) * length
		var y2 = center.y - sin(angle) * length
		
		if x1 >= 0 and x1 < 24 and y1 >= 0 and y1 < 24:
			img.set_pixel(x1, y1, outline_color)
		if x2 >= 0 and x2 < 24 and y2 >= 0 and y2 < 24:
			img.set_pixel(x2, y2, outline_color)
	
	var tex = ImageTexture.create_from_image(img)
	sprite.texture = tex
	add_child(sprite)
	
	# Also add a collision shape if missing
	if not has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 12
		collision.shape = circle_shape
		add_child(collision)
	
	print("Created debug coin visuals")
