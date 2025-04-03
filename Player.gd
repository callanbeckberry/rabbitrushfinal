extends Area2D

# Node references 
@onready var tile_map = $"../TileMap"
@onready var space_bar_progress = $"../CanvasLayer/UI/SpaceBarProgress"
@onready var move_counter = $"../CanvasLayer/UI/MoveCounter"
@onready var decay_timer = $"../CanvasLayer/Timers/SpaceBarDecayTimer"
@onready var no_input_timer = $"../CanvasLayer/Timers/NoInputTimer"
@onready var ray = $RayCast2D
@onready var inventory_label = $"../CanvasLayer/UI/InventoryLabel"  # For displaying coin count
@onready var battle_scene = $"../BattleScene"  # Reference to the battle scene
@onready var main_ui = $"../CanvasLayer/UI"  # Reference to main UI
@onready var main_camera = $"../Camera2D"  # Reference to main camera
@onready var global_ui_manager = get_node("/root/GlobalUIManager")  # Reference to GlobalUIManager autoload
@onready var sprite = $Sprite2D  # Reference to the player sprite - add this node if you don't have it
@onready var modal_manager = get_node_or_null("/root/ModalManager") # Reference to the modal manager
@onready var water_layer = null  # Will be set in _ready
@onready var water_sprite = $water_sprite
@onready var water_tilemap = $"../WaterTileMap"
@onready var sprite_bonk: AnimatedSprite2D = $SpriteBonk
@onready var interaction_ray = $RayCast2D 


signal battle_started
signal battle_ended

const WALK_SOUND = preload("res://sounds/walk.wav")
const BUMP_SOUND = preload("res://sounds/bump.wav")
const PICKUP_SOUND = preload("res://sounds/pickupCoin.wav")
const UNLOCK_SOUND = preload("res://sounds/charge.wav")
const SPLASH_SOUND = preload("res://sounds/hit.wav")
const GET_KEY_SOUND = preload("res://sounds/getkey.wav")

var tile_size = 32  # TileMap cell size
var is_moving = false
var space_press_count = 0  # Accumulated spacebar presses (max 10)
var available_moves = 0
var target_position = Vector2.ZERO  # Destination position for movement
var can_move = true  # Flag to control movement (for dialogue system)
var facing_direction = Vector2.DOWN  # Track which direction player is facing

var is_boss_battle = false

var previous_animation: String = "idle_down"
var is_bonking: bool = false

# Add sound player nodes as class variables
var walk_sound_player: AudioStreamPlayer
var bump_sound_player: AudioStreamPlayer
var pickup_sound_player: AudioStreamPlayer
var unlock_sound_player: AudioStreamPlayer
var splash_sound_player: AudioStreamPlayer
var get_key_sound_player: AudioStreamPlayer

var is_in_water = false  # Track if player is in water

# Coin system
var coins = 0           # Current collected coins
var total_coins = 120   # Total coins in the game (will be updated by RoomManager)
var coins_per_room = 10 # Coins per room (will be updated by RoomManager)
var coin_threshold = 5  # Number of coins needed to unlock locked tile

# New variables for key/door system
var has_key = false
var key_instance = null
var previous_position = Vector2.ZERO  # Store the previous position for key following

# Battle system variables
var in_battle = false
var can_start_battle = true
var moves_since_battle = 0
var safe_moves_remaining = 0
var base_battle_chance = 0.05  # 5% chance (1 in 20)
var increased_battle_chance = 0.15  # +15% chance (becomes 20% total)

# NPC interaction related variables
var current_npc = null
var in_dialogue = false
var last_npc_check_position = Vector2.ZERO
var dialogue_cooldown = false # Add cooldown to prevent rapid dialogue triggering

# Modal system variables
var modal_active = false

func _ready():
	# DEVELOPMENT ONLY: Reset NPC dialogue states on each game start
	# Comment this out before building your final game
	var save_path = "user://npc_states.cfg"
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(save_path)
			print("*** DEV MODE: ALL NPC DIALOGUE STATES RESET ***")
			
		# Configure the raycast for NPC interaction
	interaction_ray.enabled = true
	interaction_ray.collision_mask = 2  # Set to whatever layer your NPCs are on
	interaction_ray.target_position = Vector2(0, 32)  # Cast downward by default
	
		# Configure the movement raycast (this is different from the interaction_ray)
	ray.enabled = true
	ray.collision_mask = 1  # This should match the NPCs' collision_layer
	
	add_to_group("player")
	
	_setup_sound_players()
	get_key_sound_player = AudioStreamPlayer.new()
	add_child(get_key_sound_player)
	get_key_sound_player.volume_db = -5.0 
	
		# Try to get water layer
	water_layer = get_node_or_null("../WaterTileMap")
	if water_layer:
		print("Water layer found")
	else:
		print("WARNING: Water layer not found. Water animations will not work.")
	
	# Initialize UI
	space_bar_progress.max_value = 10
	space_bar_progress.value = 0
	move_counter.text = "Moves: 0"
	update_coin_display()
	
	# Connect timers
	decay_timer.timeout.connect(_decrease_space_bar_progress)
	no_input_timer.timeout.connect(_start_decay_timer)
	
	# Store initial position
	previous_position = global_position
	last_npc_check_position = global_position
	
	# Add main camera to cameras group
	if main_camera:
		main_camera.add_to_group("cameras")
	
	# Connect battle ended signal
	if battle_scene and not battle_scene.is_connected("battle_ended", _on_battle_ended):
		battle_scene.connect("battle_ended", _on_battle_ended)
	
	# Start the global UI if it doesn't exist
	if global_ui_manager:
		global_ui_manager.start_game()
		
	# Setup dialogue manager if it doesn't exist
	setup_dialogue_manager()
	
	# Setup modal manager if needed
	setup_modal_manager()
	
	# Set initial sprite direction
	update_sprite_direction(Vector2.DOWN)
	
	# Setup directional sprites if using Method 3
	setup_directional_sprites()

	# Hide the water sprite initially, just to be safe
	if water_sprite:
		water_sprite.visible = false
	
	# Make sure the bonk sprite is initially invisible
#	sprite_bonk.visible = false
	set_notify_transform(true)



# Setup function for sound players - call this in _ready()
func _setup_sound_players():
	# Create audio players
	walk_sound_player = AudioStreamPlayer.new()
	bump_sound_player = AudioStreamPlayer.new()
	pickup_sound_player = AudioStreamPlayer.new()
	unlock_sound_player = AudioStreamPlayer.new()
	splash_sound_player = AudioStreamPlayer.new()
	
	# Add them to the scene
	add_child(walk_sound_player)
	add_child(bump_sound_player)
	add_child(pickup_sound_player)
	add_child(unlock_sound_player)
	add_child(splash_sound_player)
	
	# Set volumes
	walk_sound_player.volume_db = -8.0  
	bump_sound_player.volume_db = -5.0
	pickup_sound_player.volume_db = -3.0
	unlock_sound_player.volume_db = -4.0
	splash_sound_player.volume_db = -5.0

func setup_modal_manager():
	modal_manager = get_node_or_null("/root/ModalManager")
	
	if not modal_manager:
		modal_manager = get_node_or_null("../CanvasLayer/ModalManager")
	
	if not modal_manager:
		# Find it anywhere in the scene
		var potential_managers = get_tree().get_nodes_in_group("modal_manager")
		if potential_managers.size() > 0:
			modal_manager = potential_managers[0]
	
	# Connect to modal closed signal
	if modal_manager and not modal_manager.is_connected("modal_closed", _on_modal_closed):
		modal_manager.connect("modal_closed", _on_modal_closed)
		print("Player: Connected to modal_closed signal")
	else:
		print("Player: Could not connect to modal_closed signal")
		
# Function to set up the directional sprites with unique textures

func _play_walk_sound():
	if not WALK_SOUND or not walk_sound_player:
		return
		
	walk_sound_player.stream = WALK_SOUND
	walk_sound_player.play()

# Function to play the bump sound
func _play_bump_sound():
	if not BUMP_SOUND or not bump_sound_player:
		return
		
	bump_sound_player.stream = BUMP_SOUND
	bump_sound_player.play()

# Function to play the pickup sound
func _play_pickup_sound():
	if not PICKUP_SOUND or not pickup_sound_player:
		return
		
	pickup_sound_player.stream = PICKUP_SOUND
	pickup_sound_player.play()

# Function to play the unlock sound
func _play_unlock_sound():
	if not UNLOCK_SOUND or not unlock_sound_player:
		return
		
	unlock_sound_player.stream = UNLOCK_SOUND
	unlock_sound_player.play()

func _play_splash_sound():
	if not SPLASH_SOUND or not splash_sound_player:
		return
		
	splash_sound_player.stream = SPLASH_SOUND
	splash_sound_player.play()

func setup_directional_sprites():
	var sprite_down = get_node_or_null("SpriteDown")
	var sprite_up = get_node_or_null("SpriteUp")
	var sprite_left = get_node_or_null("SpriteLeft")
	var sprite_right = get_node_or_null("SpriteRight")
	
	if sprite_down and sprite_up and sprite_left and sprite_right:
		# Make sure all sprites are invisible initially except the default (down)
		sprite_down.visible = true
		sprite_up.visible = false
		sprite_left.visible = false
		sprite_right.visible = false
		
		# Load unique textures for each sprite if needed
		# Uncomment and modify paths as needed
		# sprite_down.texture = load("res://assets/player_down.png")
		# sprite_up.texture = load("res://assets/player_up.png")
		# sprite_left.texture = load("res://assets/player_left.png")
		# sprite_right.texture = load("res://assets/player_right.png")

# Setup the dialogue manager if it doesn't exist yet
func setup_dialogue_manager():
	# Skip if already exists
	if get_node_or_null("../CanvasLayer/DialogueManager") or get_node_or_null("/root/DialogueManager"):
		return
		
	# Find or create CanvasLayer
	var canvas_layer = get_node_or_null("../CanvasLayer")
	if canvas_layer:
		# Create DialogueManager scene
		var dialogue_manager_scene = load("res://dialogue_manager.tscn")
		if dialogue_manager_scene:
			var dialogue_manager = dialogue_manager_scene.instantiate()
			dialogue_manager.add_to_group("dialogue_manager")
			canvas_layer.add_child(dialogue_manager)
			print("Dialogue Manager added to scene")
		else:
			print("ERROR: Could not load dialogue_manager.tscn")

func get_current_tile():
	return tile_map.local_to_map(global_position)

func _process(_delta):
	if is_moving or in_battle or in_dialogue or not can_move or modal_active:
		return

	# Check for modal button presses
	if Input.is_action_just_pressed("recap_button"):
		open_modal("recap")
		return
		
	if Input.is_action_just_pressed("wallet_button"):
		# Simply open the wallet without trying to update yen
		open_modal("wallet")
		return
		
	if Input.is_action_just_pressed("mystery_button"):
		open_modal("mystery")
		return

	# Immediately add one move when "X" is pressed
	# Only if we're not in battle
	# In the _process() function, where you handle the "add_move" action:
	if Input.is_action_just_pressed("add_move") and not in_battle:
		# Add to movement counter
		add_move()
		
		# Play pickup coin sound
		_play_pickup_sound()
		
		# Update the yen counter in GlobalUIManager
		if global_ui_manager:
			global_ui_manager.add_yen(27)
	
	# Spacebar or interact button both add to the space bar progress
	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact")) and not in_battle:
		increment_space_bar_progress()
	
	# Process movement input (W, S, A, D) if moves are available
	if available_moves > 0:
		if Input.is_action_just_pressed("up"):
			update_sprite_direction(Vector2.UP)
			move(Vector2.UP)
		elif Input.is_action_just_pressed("down"):
			update_sprite_direction(Vector2.DOWN)
			move(Vector2.DOWN)
		elif Input.is_action_just_pressed("left"):
			update_sprite_direction(Vector2.LEFT)
			move(Vector2.LEFT)
		elif Input.is_action_just_pressed("right"):
			update_sprite_direction(Vector2.RIGHT)
			move(Vector2.RIGHT)
		# Don't change animation during bonk
	if is_bonking:
		return
		
	update_interaction_ray_direction()
	
	# Check for interaction
	if Input.is_action_just_pressed("interact"):  # Your interaction button
		check_npc_interaction()

# First, fix the update_interaction_ray_direction function
func update_interaction_ray_direction():
	# Point the ray in the direction the player is facing
	var direction = Vector2.ZERO
	
	# Set direction based on facing_direction
	if facing_direction == Vector2.DOWN:
		direction = Vector2(0, tile_size)  # Down
	elif facing_direction == Vector2.UP:
		direction = Vector2(0, -tile_size)  # Up
	elif facing_direction == Vector2.LEFT:
		direction = Vector2(-tile_size, 0)  # Left
	elif facing_direction == Vector2.RIGHT:
		direction = Vector2(tile_size, 0)  # Right
	
	interaction_ray.target_position = direction  # Use target_position instead of cast_to

func check_npc_interaction():
	# Make sure interaction ray is pointing in the facing direction
	update_interaction_ray_direction()
	
	# Force the raycast to update
	interaction_ray.force_raycast_update()
	
	# Debug: Print raycast info
	print("Raycast from: ", global_position, " in direction: ", interaction_ray.target_position)
	
	# Check if we're hitting an NPC
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		print("Raycast hit: ", collider)
		
		if collider is NPC:
			print("Found NPC: ", collider.npc_name, " starting dialogue")
			collider.show_dialogue()
			return true
	
	# If raycast fails, fall back to proximity check
	return check_nearby_npcs(true)

func open_modal(modal_type):
	if not modal_manager or modal_active:
		return
	
	modal_active = true
	
	# Make sure GlobalUIManager data is synchronized before opening wallet
	if modal_type == "wallet" and global_ui_manager:
		print("Player: Syncing with GlobalUIManager before opening wallet")
	
	match modal_type:
		"recap":
			modal_manager.open_recap_modal()
		"wallet":
			# Ensure modal_manager is available and not null
			if modal_manager:
				modal_manager.open_wallet_modal()
			else:
				print("ERROR: Cannot open wallet modal - modal_manager is null")
				modal_active = false
		"mystery":
			modal_manager.open_mystery_modal()

# Handle modal closed event
func _on_modal_closed(modal_type):
	modal_active = false
	print("Modal closed: ", modal_type)
	
	# Resume game processing
	set_process(true)
	set_physics_process(true)



# Function to add a move directly to the available moves
func add_move():
	available_moves += 1
	move_counter.text = "Moves: " + str(available_moves)

# Function to increment the space bar progress
func increment_space_bar_progress():
	space_press_count += 1
	space_bar_progress.value = space_press_count
	
	if space_press_count >= 10:
		available_moves += 1
		move_counter.text = "Moves: " + str(available_moves)
		space_press_count = 0
		space_bar_progress.value = 0
	
	no_input_timer.stop()
	no_input_timer.start()
	decay_timer.stop()

# New function to update sprite direction
func update_sprite_direction(direction: Vector2):
	facing_direction = direction
	
	# If in water, just ensure water sprite is visible
	if is_in_water:
		if water_sprite:
			if water_sprite and water_sprite.sprite_frames and water_sprite.sprite_frames.has_animation("water_walk"):
				water_sprite.play("water_walk")
				print("✅ Playing water_walk animation")
			else:
				print("⚠️ water_walk animation not found")
			if water_sprite and water_sprite.sprite_frames and water_sprite.sprite_frames.has_animation("water_walk"):
				water_sprite.play("water_walk")
		
		# Get all direction sprites
		var sprite_down = get_node_or_null("SpriteDown")
		var sprite_up = get_node_or_null("SpriteUp")
		var sprite_left = get_node_or_null("SpriteLeft")
		var sprite_right = get_node_or_null("SpriteRight")
		
		# Hide all regular sprites
		if sprite_down: sprite_down.visible = false
		if sprite_up: sprite_up.visible = false
		if sprite_left: sprite_left.visible = false
		if sprite_right: sprite_right.visible = false
		
		# Show water sprite
		if water_sprite:
			water_sprite.visible = true
		
		return
	
	# Otherwise, regular sprite direction logic
	var sprite_down = get_node_or_null("SpriteDown")
	var sprite_up = get_node_or_null("SpriteUp")
	var sprite_left = get_node_or_null("SpriteLeft")
	var sprite_right = get_node_or_null("SpriteRight")
	
	# Hide water sprite
	if water_sprite: water_sprite.visible = false
	
	# Show appropriate direction sprite
	if sprite_down: sprite_down.visible = direction == Vector2.DOWN
	if sprite_up: sprite_up.visible = direction == Vector2.UP
	if sprite_left: sprite_left.visible = direction == Vector2.LEFT
	if sprite_right: sprite_right.visible = direction == Vector2.RIGHT

func _start_decay_timer():
	decay_timer.start()

func _decrease_space_bar_progress():
	if space_bar_progress.value > 0:
		space_press_count = max(space_press_count - 1, 0)
		space_bar_progress.value = space_press_count
	else:
		decay_timer.stop()

func print_tile_info(tile_position: Vector2i):
	var layer_id = 0  # Assuming you're using layer 0 in your base TileMap

	# New: pass 3 arguments to avoid the error
	var atlas_coords = tile_map.get_cell_atlas_coords(layer_id, tile_position, false)
	if atlas_coords == Vector2i(-1, -1):
		print("No tile at position ", tile_position)
		return

	var alternative_tile = tile_map.get_cell_alternative_tile(layer_id, tile_position)

	print("Tile at position ", tile_position, ":")
	print("- Atlas coords: ", atlas_coords)
	print("- Alternative tile: ", alternative_tile)
	print("- Custom data check skipped to avoid errors")


func debug_current_tile():
	var current_tile = get_current_tile()
	print("====== TILE DEBUG INFO ======")
	print("Player at tile position: ", current_tile)
	print_tile_info(current_tile)
	
	# Check surrounding tiles
	print("\nSurrounding tiles:")
	var directions = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	for dir in directions:
		var neighbor_pos = current_tile + dir
		print("Direction ", dir, ":")
		print_tile_info(neighbor_pos)
	print("============================")

func move(direction: Vector2):
	if is_moving or available_moves <= 0 or in_battle or in_dialogue or not can_move:
		return
	
	# Store the current position before moving
	previous_position = global_position

	# Use RayCast2D to check for obstacles:
	ray.target_position = direction * tile_size
	ray.force_raycast_update()

	# Determine where we're about to go
	var current_tile = tile_map.local_to_map(global_position - Vector2(tile_size / 2, tile_size / 2))
	var target_tile = current_tile + Vector2i(direction.x, direction.y)

	# Check for water entry
	var was_in_water = is_in_water
	var is_going_to_be_in_water = is_water_tile(target_tile)
	is_in_water = is_going_to_be_in_water

	if not was_in_water and is_in_water:
		_play_splash_sound()
	
	# Debug current tile and target tile
	print("DEBUG: Moving from ", current_tile, " to ", target_tile)
	
	# Debug target tile to see if it should be a water tile
	print("DEBUG: Target tile info:")
	print_tile_info(target_tile)

	# Check for other collisions
		# Check for any collisions
	if ray.is_colliding():
		var collider = ray.get_collider()
		print("❌ BLOCKED: Collision detected with", collider)
		
		# Pass the direction to play_bonk_animation
		play_bonk_animation(direction)
		
		return
	
	if is_going_to_be_in_water:
		debug_water_tile_pos = water_tilemap.map_to_local(target_tile) + Vector2(16, 16)
		debug_show_water_tile = true
		call_deferred("update")
  # forces _draw()
	else:
		debug_show_water_tile = false
		call_deferred("update")


	
	# Reduce available moves
	available_moves -= 1
	move_counter.text = "Moves: " + str(available_moves)
	
	is_moving = true
	target_position = tile_map.map_to_local(target_tile) + Vector2(tile_size / 2, tile_size / 2)

	# Trigger splash only if we're *entering* water
	if not was_in_water and is_in_water:
		_play_splash_sound()	
		
		# Play appropriate movement sound - using the same walk sound for both
		_play_walk_sound()
		
	# Update sprite visibility based on water state
	if is_in_water != was_in_water:
		update_water_state(direction)
		print("🔥 update_water_state() called. is_in_water = ", is_in_water)

	else:
		# Just update direction if needed
		update_sprite_direction(direction)
	
	# Track moves for battle chance
	moves_since_battle += 1
	
	# Random battle chance logic
	if can_start_battle and safe_moves_remaining <= 0:
		var battle_roll = randf()
		var current_chance = base_battle_chance
		
		# Increase chance after 10 moves
		if moves_since_battle > 10:
			current_chance = base_battle_chance + increased_battle_chance
			
		# Print debug info about battle chance
		print("Battle chance: ", current_chance * 100, "%, Roll: ", battle_roll)
		
		if battle_roll < current_chance:
			# Set a flag to start the battle after movement is complete
			await get_tree().create_timer(0.1).timeout
			start_battle()
	else:
		if safe_moves_remaining > 0:
			safe_moves_remaining -= 1
			print("Safe moves remaining: ", safe_moves_remaining)

# Replace these functions with simplified versions that use the water layer
func get_tile_for_water_check() -> Vector2i:
	return tile_map.local_to_map(global_position)

func is_water_tile(tile_position: Vector2i) -> bool:
	if not water_tilemap:
		return false

	var tile_data = water_tilemap.get_cell_tile_data(0, tile_position)
	return tile_data != null

# Function to update the water state of the player
func update_water_state(direction: Vector2):
	print("WATER DEBUG: is_in_water = ", is_in_water)
	print("Playing animation: water_walk")  # or water_bump
	
	# Get all direction sprites
	var sprite_down = get_node_or_null("SpriteDown")
	var sprite_up = get_node_or_null("SpriteUp")
	var sprite_left = get_node_or_null("SpriteLeft")
	var sprite_right = get_node_or_null("SpriteRight")
	
	# Update sprite visibility based on water state
	if is_in_water:
		print("Player is in water - showing water sprite")
		
		# Hide all regular sprites
		if sprite_down: sprite_down.visible = false
		if sprite_up: sprite_up.visible = false
		if sprite_left: sprite_left.visible = false
		if sprite_right: sprite_right.visible = false
		
		# Show water sprite and play animation
		if water_sprite:
			water_sprite.visible = true
			
			# Check if the animation exists before playing it
			if water_sprite and water_sprite.sprite_frames and water_sprite.sprite_frames.has_animation("water_walk"):
				water_sprite.play("water_walk")

				print("Playing water_walk animation")
			else:
				print("Warning: water_walk animation not found in water_sprite")
		else:
			print("Warning: water_sprite is null")
	else:
		print("Player is not in water - showing regular sprites")
		
		# Hide water sprite
		if water_sprite: 
			water_sprite.visible = false
			if water_sprite.has_method("stop"):
				water_sprite.stop()
		
		# Show appropriate direction sprite
		if sprite_down: sprite_down.visible = direction == Vector2.DOWN
		if sprite_up: sprite_up.visible = direction == Vector2.UP
		if sprite_left: sprite_left.visible = direction == Vector2.LEFT
		if sprite_right: sprite_right.visible = direction == Vector2.RIGHT
	
	# Update facing direction
	facing_direction = direction
	
# Add this updated bump animation function to your player script

var debug_water_tile_pos: Vector2 = Vector2.ZERO
var debug_show_water_tile = false

func _draw():
	if debug_show_water_tile:
		var size = Vector2(32, 32)
		var pos = debug_water_tile_pos - size / 2
		draw_rect(Rect2(pos, size), Color(0, 0.5, 1, 0.5), true)
		draw_rect(Rect2(pos, size), Color(0, 0, 1), false, 2)



func play_bump_animation(direction: Vector2, is_water_bump = false):
	# Find the currently active sprite based on direction
	var sprite_down = get_node_or_null("SpriteDown")
	var sprite_up = get_node_or_null("SpriteUp")
	var sprite_left = get_node_or_null("SpriteLeft")
	var sprite_right = get_node_or_null("SpriteRight")
	
	# Determine which sprite is active based on facing direction
	var active_sprite = null
	if facing_direction == Vector2.DOWN and sprite_down and sprite_down.visible:
		active_sprite = sprite_down
	elif facing_direction == Vector2.UP and sprite_up and sprite_up.visible:
		active_sprite = sprite_up
	elif facing_direction == Vector2.LEFT and sprite_left and sprite_left.visible:
		active_sprite = sprite_left
	elif facing_direction == Vector2.RIGHT and sprite_right and sprite_right.visible:
		active_sprite = sprite_right
	
	# For water bump, try to play the special water_bump animation if available
	if is_water_bump and water_sprite:
		if water_sprite and water_sprite.sprite_frames and water_sprite.sprite_frames.has_animation("water_bump"):
			# Switch to water sprite and play bump animation
			if not is_in_water:
				# Hide all regular sprites temporarily
				if sprite_down: sprite_down.visible = false
				if sprite_up: sprite_up.visible = false
				if sprite_left: sprite_left.visible = false
				if sprite_right: sprite_right.visible = false
				
				# Show water sprite
				water_sprite.visible = true
			
			# Play the bump animation
			water_sprite.play("water_bump")
			
			# After animation, return to normal state
			await water_sprite.animation_finished
			
			if not is_in_water:
				water_sprite.visible = false
				update_sprite_direction(facing_direction)
			else:
				water_sprite.play("water_walk")
				
				# Show the appropriate directional sprite
				if sprite_down: sprite_down.visible = facing_direction == Vector2.DOWN
				if sprite_up: sprite_up.visible = facing_direction == Vector2.UP
				if sprite_left: sprite_left.visible = facing_direction == Vector2.LEFT
				if sprite_right: sprite_right.visible = facing_direction == Vector2.RIGHT
			
			return
	
	# If we're using the water sprite
	if is_in_water and water_sprite and water_sprite.visible:
		active_sprite = water_sprite
	
	# Set up different animation parameters based on bump type
	var shake_distance = 5.0
	var shake_time_out = 0.1
	var bounce_time = 0.3
	var tween_trans = Tween.TRANS_ELASTIC
	
	# Adjust parameters for water bump if needed
	if is_water_bump:
		shake_distance = 7.0  # Larger shake for water
		shake_time_out = 0.15  # Slightly slower initial movement
		bounce_time = 0.4  # Slower bounce back
		# Could use a different transition type for water if desired
	
	# If we found an active sprite, make it shake
	if active_sprite:
		# Store original position
		var original_position = active_sprite.position
		
		# Create a tween for the shake animation
		var bump_tween = create_tween().set_trans(tween_trans).set_ease(Tween.EASE_OUT)
		
		# Shake the sprite in the collision direction
		bump_tween.tween_property(active_sprite, "position", original_position + direction * shake_distance, shake_time_out)
		bump_tween.tween_property(active_sprite, "position", original_position, bounce_time)
	else:
		# Fallback - shake the entire player object if no active sprite is found
		var original_position = global_position
		var bump_tween = create_tween().set_trans(tween_trans).set_ease(Tween.EASE_OUT)
		
		# Shake the player in the collision direction
		bump_tween.tween_property(self, "position", original_position + direction * shake_distance, shake_time_out)
		bump_tween.tween_property(self, "position", original_position, bounce_time)

func play_bonk_animation(direction: Vector2 = Vector2.ZERO):
	if is_bonking:
		return
	
	# If no direction was provided, use facing_direction
	if direction == Vector2.ZERO:
		direction = facing_direction
	
	print("Playing bonk animation")
	
	# Set bonking flag
	is_bonking = true
	
	# Get all direction sprites
	var sprite_down = get_node_or_null("SpriteDown")
	var sprite_up = get_node_or_null("SpriteUp")
	var sprite_left = get_node_or_null("SpriteLeft")
	var sprite_right = get_node_or_null("SpriteRight")
	
	# Store which sprites were visible
	var was_in_water = is_in_water
	
	# Hide all regular sprites
	if sprite_down: sprite_down.visible = false
	if sprite_up: sprite_up.visible = false
	if sprite_left: sprite_left.visible = false
	if sprite_right: sprite_right.visible = false
	if water_sprite: water_sprite.visible = false
	
	# Show and play bonk animation
	if sprite_bonk:
		sprite_bonk.visible = true
		
		# Check if the animation exists before playing it
		if sprite_bonk.sprite_frames and sprite_bonk.sprite_frames.has_animation("bonk"):
			sprite_bonk.play("bonk")
		else:
			print("Warning: bonk animation not found in sprite_bonk")
	
	# Play bump sound
	_play_bump_sound()
	
	# Add the jiggle effect on the bonk sprite
	var original_position = sprite_bonk.position
	var shake_distance = 5.0
	var shake_time_out = 0.1
	var bounce_time = 0.3
	var tween_trans = Tween.TRANS_ELASTIC
	
	# Create a tween for the shake animation
	var bump_tween = create_tween().set_trans(tween_trans).set_ease(Tween.EASE_OUT)
	
	# Shake the sprite in the collision direction
	bump_tween.tween_property(sprite_bonk, "position", original_position + direction * shake_distance, shake_time_out)
	bump_tween.tween_property(sprite_bonk, "position", original_position, bounce_time)
	
	# Create timer to end bonk animation after 0.5 seconds
	get_tree().create_timer(0.5).timeout.connect(func():
		# Hide bonk sprite
		if sprite_bonk: sprite_bonk.visible = false
		
		# Restore previous state
		if is_in_water and water_sprite:
			water_sprite.visible = true
			if water_sprite.sprite_frames and water_sprite.sprite_frames.has_animation("water_walk"):
				water_sprite.play("water_walk")
		else:
			# Restore appropriate direction sprite
			if sprite_down: sprite_down.visible = facing_direction == Vector2.DOWN
			if sprite_up: sprite_up.visible = facing_direction == Vector2.UP
			if sprite_left: sprite_left.visible = facing_direction == Vector2.LEFT
			if sprite_right: sprite_right.visible = facing_direction == Vector2.RIGHT
		
		# Reset the bonking flag
		is_bonking = false
	)

func _physics_process(delta):
	if is_moving and not in_battle and not in_dialogue:
		global_position = global_position.move_toward(target_position, 100 * delta)
		
		if global_position.distance_to(target_position) < 1:
			global_position = target_position
			is_moving = false
			
			# Update the key's position after player movement completes
			if has_key and key_instance != null and key_instance.following_player:
				key_instance.update_position(previous_position)
			
			# Check for nearby doors after movement
			check_nearby_doors()
			
			# Check for nearby NPCs after movement
			check_nearby_npcs()

func check_nearby_doors():
	if has_key and key_instance != null:
		print("Checking for nearby doors. Player has key:", has_key)
		
		# Get all doors in the scene
		var doors = get_tree().get_nodes_in_group("door")
		print("Found", doors.size(), "doors in scene")
		
		for door in doors:
			# Check if player is next to the door
			var player_tile = get_current_tile()
			
			# Ensure door has tile_position property
			if not door.has_method("get") or not door.get("tile_position"):
				print("WARNING: Door doesn't have tile_position property. Using global_position instead.")
				# Calculate approximate tile position
				var door_pos = door.global_position
				var door_tile = tile_map.local_to_map(door_pos - Vector2(tile_size / 2, tile_size / 2))
				
				# Check if adjacent (not diagonal)
				var dx = abs(player_tile.x - door_tile.x)
				var dy = abs(player_tile.y - door_tile.y)
				print("Door at tile:", door_tile, "Player at tile:", player_tile, "Distance:", Vector2(dx, dy))
				
				if (dx <= 1 and dy == 0) or (dy <= 1 and dx == 0):
					print("Player is adjacent to door at position:", door.global_position)
					try_unlock_door(door)
			else:
				var door_tile = door.tile_position
				
				# Check if adjacent (not diagonal)
				var dx = abs(player_tile.x - door_tile.x)
				var dy = abs(player_tile.y - door_tile.y)
				print("Door at tile:", door_tile, "Player at tile:", player_tile, "Distance:", Vector2(dx, dy))
				
				if (dx <= 1 and dy == 0) or (dy <= 1 and dx == 0):
					print("Player is adjacent to door at position:", door.global_position)
					try_unlock_door(door)

func try_unlock_door(door):
	print("Attempting to unlock door:", door)
	
	# Check if key exists
	if not key_instance:
		print("ERROR: Key instance is null")
		return
	
	# Get door's global position
	var door_position = door.global_position
	print("Door position:", door_position)
	print("Key position:", key_instance.global_position)
	
	# Calculate tile positions manually if key's is_near_door method isn't working right
	var key_tile = tile_map.local_to_map(key_instance.global_position)
	var door_tile = tile_map.local_to_map(door_position)
	
	# Calculate Manhattan distance
	var distance = abs(key_tile.x - door_tile.x) + abs(key_tile.y - door_tile.y)
	
	# Debug info
	print("Key tile position:", key_tile)
	print("Door tile position:", door_tile)
	print("Distance between key and door:", distance)
	
	# Try the original method first
	var is_near = false
	if key_instance.has_method("is_near_door"):
		is_near = key_instance.is_near_door(door_position)
		print("Key's is_near_door method returned:", is_near)
	
	# Override with our own distance check if needed
	var custom_is_near = distance <= 5  # Consider them near if they are at most 5 tiles apart
	print("Custom proximity check returned:", custom_is_near)
	
	# Use either method that returns true
	is_near = is_near || custom_is_near
	print("Final is_near decision:", is_near)
	
	if is_near:
		print("Key and player are near door - unlocking!")
		
		# Play unlock sound
		_play_unlock_sound()
		
		# Unlock the door
		if door.has_method("unlock"):
			door.unlock()
			print("Door.unlock() method called successfully")
		else:
			print("ERROR: Door doesn't have unlock method")
			
			# Try fallback methods to unlock door
			if door.has_method("queue_free"):
				door.queue_free()
				print("Door removed as fallback")
			elif door.has_method("hide"):
				door.hide()
				print("Door hidden as fallback")
		
		# Consume the key
		if key_instance.has_method("consume"):
			key_instance.consume()
			print("Key consumed successfully")
		else:
			print("WARNING: Key doesn't have consume method")
			
			# Hide key as fallback
			if key_instance:
				key_instance.visible = false
				print("Key hidden as fallback")
				
		has_key = false
		print("Player's has_key set to false")
# New function to check for NPCs within 1 grid square and trigger dialogue
# Modified to optionally be triggered explicitly and return whether it found an NPC
func check_nearby_npcs(explicit_check = false):
	# Skip checks if we're in dialogue or cooldown period
	if in_dialogue or dialogue_cooldown:
		return false
	
	# For automatic checks, verify we've moved to a new position
	if !explicit_check and global_position.distance_to(last_npc_check_position) < 1:
		return false
	
	last_npc_check_position = global_position
	
	var player_tile = get_current_tile()
	var npcs = get_tree().get_nodes_in_group("npcs")
	var found_npc = false
	
	for npc in npcs:
		# Get NPC's tile position
		var npc_pos = npc.global_position
		var npc_tile = tile_map.local_to_map(npc_pos)
		
		# Debug: Print distance info
		print("NPC: ", npc.npc_name, " at tile: ", npc_tile, " player at: ", player_tile)
		
		# Check if adjacent (including diagonals)
		var dx = abs(player_tile.x - npc_tile.x)
		var dy = abs(player_tile.y - npc_tile.y)
		
		# If within 1 tile (manhattan distance of 1, not diagonals)
		if (dx == 1 and dy == 0) or (dx == 0 and dy == 1):
			print("Found NPC in adjacent tile: ", npc.npc_name)
			
			# Found an NPC within range, trigger dialogue
			current_npc = npc
			trigger_npc_dialogue(npc)
			found_npc = true
			break
	
	return found_npc

func trigger_npc_dialogue(npc):
	if dialogue_cooldown:
		return
		
	dialogue_cooldown = true
	in_dialogue = true
	can_move = false
	
	# Find dialogue manager using improved search
	var dialogue_manager = find_dialogue_manager()
	
	if dialogue_manager and npc.has_method("show_dialogue"):
		npc.show_dialogue()
	elif npc.dialogues.size() > 0:
		# Fallback if dialogue manager not found
		var random_dialogue = npc.dialogues[randi() % npc.dialogues.size()]
		print("[NPC " + npc.npc_name + "]: " + random_dialogue)
		await get_tree().create_timer(2.0).timeout
		end_dialogue()
	
	# Reset cooldown after a short delay
	await get_tree().create_timer(2.0).timeout
	dialogue_cooldown = false

# Improved function to find dialogue manager
func find_dialogue_manager():
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		return dm
		
	dm = get_node_or_null("../CanvasLayer/DialogueManager")
	if dm:
		return dm
		
	# Try to find using group
	var potential_managers = get_tree().get_nodes_in_group("dialogue_manager")
	if potential_managers.size() > 0:
		return potential_managers[0]
		
	return null

func end_dialogue():
	in_dialogue = false
	can_move = true
	current_npc = null

func check_unlock_door(door):
	try_unlock_door(door)

func _play_get_key_sound():
	if not GET_KEY_SOUND or not get_key_sound_player:
		return
		
	get_key_sound_player.stream = GET_KEY_SOUND
	get_key_sound_player.play()

func pickup_key():
	print("Key picked up!")
	has_key = true
	
	# Play key pickup sound instead of generic pickup sound
	_play_get_key_sound()

func spawn_and_attach_key():
	var key_scene = load("res://key.tscn")
	key_instance = key_scene.instantiate()
	get_parent().add_child(key_instance)
	key_instance.start_following(self)
	has_key = true
	
	# Play key pickup sound when spawning a key
	_play_get_key_sound()

# Function to enable/disable player movement (used by DialogueManager)
func set_can_move(value):
	can_move = value
	
	# If we can move again, we're not in dialogue
	if value == true:
		in_dialogue = false

# COIN SYSTEM

func add_coin():
	coins += 1
	print("Coin added. Total coins:", coins, "/", total_coins)
	update_coin_display()
	
	# Play pickup sound
	_play_pickup_sound()
	
	# Check if all coins are collected
	if coins >= total_coins:
		unlock_final_boss()

func update_coin_display():
	inventory_label.text = "Coins: " + str(coins) + "/" + str(total_coins)

func unlock_final_boss():
	print("All coins collected! Final boss door unlocked!")
	
	# Find the final boss door and unlock it
	var final_doors = get_tree().get_nodes_in_group("final_boss_door")
	for door in final_doors:
		door.unlock()
	
	# Maybe display a special message or play a sound
	var popup_label = Label.new()
	popup_label.text = "All Coins Collected! Final door unlocked!"
	popup_label.position = Vector2(512, 300)  # Center of screen
	popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_label.add_theme_font_size_override("font_size", 24)
	get_node("../CanvasLayer").add_child(popup_label)
	
	# Remove the message after 3 seconds
	var t = get_tree().create_timer(3.0)
	t.timeout.connect(func(): popup_label.queue_free())

# BATTLE SYSTEM CODE

func start_battle(is_boss = false):
	print("Battle started! Is boss battle:", is_boss)
	in_battle = true
	is_boss_battle = is_boss  # Set the boss battle flag
	print("A battle has started!")
	in_battle = true
	
	emit_signal("battle_started")
	
	# Hide main UI
	if main_ui:
		main_ui.visible = false
	
	# Hide key if it's following the player
	if has_key and key_instance != null:
		key_instance.visible = false
	
	var ui_background = get_node_or_null("../CanvasLayer/UIBackground")
	if ui_background:
		ui_background.visible = false
	
	# Hide the wizard turtle
	var wizard_turtle = get_node_or_null("../CanvasLayer/WizardTurtleUI")
	if wizard_turtle:
		wizard_turtle.hide_wizard_turtle()
		
	if water_sprite:
		water_sprite.visible = false
	
	# Hide all collectibles (coins, etc.)
	for collectible in get_tree().get_nodes_in_group("collectibles"):
		collectible.visible = false
	
	# Hide all NPCs
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = false
	
	# Disable main camera if it exists
	if main_camera:
		main_camera.enabled = false
	
	# Ensure GlobalUI remains visible during battle
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Show and start the battle scene with transition
	if battle_scene:
		battle_scene.visible = true
		battle_scene.start_battle_with_transition()
		
		# Disable player movement during battle
		set_process(false)
		set_physics_process(false)
	else:
		print("ERROR: Battle scene not found!")
		in_battle = false

func _on_battle_ended():
	
	print("Battle ended, returning to main game")
	
	emit_signal("battle_ended")
	
	# Resume normal game processing
	set_process(true)
	set_physics_process(true)
	
	# Show main UI again
	if main_ui:
		main_ui.visible = true
	
	var ui_background = get_node_or_null("../CanvasLayer/UIBackground")
	if ui_background:
		ui_background.visible = true
	
	var wizard_turtle = get_node_or_null("../CanvasLayer/WizardTurtleUI")
	if wizard_turtle:
		wizard_turtle.show_wizard_turtle()
	
	# After battle ends and when returning to the main game scene
	if wizard_turtle:
		wizard_turtle.battle_ended()
	
	if is_in_water and water_sprite:
		water_sprite.visible = true
	
	# Show key again if the player has one
	if has_key and key_instance != null:
		key_instance.visible = true
	
	# Show all collectibles again
	for collectible in get_tree().get_nodes_in_group("collectibles"):
		collectible.visible = true
	
	# Show all NPCs again
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = true
	
	# Re-enable main camera if it exists
	if main_camera:
		main_camera.enabled = true
	
	# Reset battle state
	in_battle = false
	
	# Reset battle tracking
	moves_since_battle = 0
	safe_moves_remaining = 5
	
	# Prevent immediate battle starting again
	can_start_battle = false
	get_tree().create_timer(2.0).timeout.connect(_enable_battles)

# Function to enable battles again after cooldown
func _enable_battles():
	can_start_battle = true
