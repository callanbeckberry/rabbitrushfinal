extends Area2D

class_name NPC

# Basic NPC properties
@export var npc_name: String = "Villager"
@export var portrait_texture: Texture2D
@export var interaction_distance: float = 50.0
@export_multiline var first_time_dialogue: String = "This is my special first meeting dialogue!"
@export_multiline var dialogues: Array[String] = [
	"Hello there, traveler!",
	"Nice weather we're having.",
	"Have you collected all the coins yet?"
]

# Animation properties
@export var sprite_frames: SpriteFrames
@export var default_animation: String = "idle"
@export_enum("idle", "talk", "walk", "react") var current_animation: String = "idle"

const SILLY_TALK_SOUND = preload("res://sounds/silly_talk.wav") 
const HIGH_TALK_SOUND = preload("res://sounds/high_talk.wav")
const ENEMY_TALK_SOUND = preload("res://sounds/enemy_talk.wav")
const PLAYER_TALK_SOUND = preload("res://sounds/player_talk.wav")

# Audio player for speech
var talk_player: AudioStreamPlayer = null

var tile_size = 32  # Default tile size - match this with your player's tile_size
var interaction_zone: CollisionShape2D = null

# Enum for speech sound types
enum SpeechSoundType {
	SILLY,
	HIGH, 
	ENEMY,
	PLAYER
}

@export var speech_sound_type: SpeechSoundType = SpeechSoundType.SILLY

# References
var player = null
var dialogue_manager = null
var in_range = false
var dialogue_cooldown = false
var is_talking = false

# Track if first dialogue has been shown
var has_shown_first_dialogue := false

# Autoload reference for persistent data
var save_data = null

# Called when the node enters the scene tree for the first time
# Modify your _ready() function
func _ready():
	add_to_group("npcs")
	
	# Initialize talk player
	talk_player = AudioStreamPlayer.new()
	add_child(talk_player)
	talk_player.volume_db = -8.0  # Set appropriate volume
	
	# Initialize or get the global save manager
	_ensure_global_save_manager()
	
	# Load this NPC's dialogue state
	_load_npc_state()
	
	# Set up collision - either find existing StaticBody2D or create one
	var static_body = get_node_or_null("StaticBody2D")
	if not static_body:
		# Create a new StaticBody2D for physical collision
		static_body = StaticBody2D.new()
		static_body.name = "StaticBody2D"
		add_child(static_body)
		
		# Create a collision shape for the StaticBody2D
		var collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		
		# Copy the Area2D's collision shape if possible
		var area_collision = $CollisionShape2D
		if area_collision and area_collision.shape:
			collision.shape = area_collision.shape.duplicate()
			# Make it slightly smaller to avoid edge cases
			if collision.shape is CircleShape2D:
				collision.shape.radius = area_collision.shape.radius * 0.9
			elif collision.shape is RectangleShape2D:
				collision.shape.size = area_collision.shape.size * 0.9
		else:
			# Create a default shape if no existing one
			var shape = CircleShape2D.new()
			shape.radius = tile_size / 2
			collision.shape = shape
		
		static_body.add_child(collision)
	
	# Configure the StaticBody2D
	if static_body:
		static_body.collision_layer = 1  # Layer 1 for physical collision
		static_body.collision_mask = 0   # Don't detect collisions itself
	
	# Debug visualization for Area2D collision shape
	var collision_shape = $CollisionShape2D
	if collision_shape:
		# Store reference to our collision shape
		interaction_zone = collision_shape
		
		# Center the collision shape on the NPC
		collision_shape.position = Vector2.ZERO
		
		# Debug visualization
		collision_shape.debug_color = Color(1, 0, 0, 0.4)  # Red with transparency
	
	# Set up the animated sprite if provided
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite and sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play(default_animation)
		print("NPC " + npc_name + " playing animation: " + default_animation)
	
	# Connect signals for player entering/exiting interaction zone
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Find dialogue manager in scene tree - try multiple paths
	dialogue_manager = find_dialogue_manager()

	add_to_group("npcs")
	
	# Defer operations that need tree access
	call_deferred("_initialize_when_in_tree")

func _initialize_when_in_tree():
	# Move operations that need tree access here
	_ensure_global_save_manager()
	_load_npc_state()
	dialogue_manager = find_dialogue_manager()
	
#func _draw():
	# Draw center marker
	#draw_circle(Vector2.ZERO, 4, Color(0, 1, 0, 0.7))
	
	# Draw tile bounds
	#var half_size = tile_size / 2
	#draw_rect(Rect2(-half_size, -half_size, tile_size, tile_size), Color(0, 0, 1, 0.3), false, 2)

func _process(_delta):
	# Handle animation states (your existing code)
	if is_talking and current_animation != "talk":
		play_animation("talk")
	elif not is_talking and in_range and current_animation != "react":
		play_animation("react")  # React when player is nearby
	elif not is_talking and not in_range and current_animation != default_animation:
		play_animation(default_animation)  # Return to default when nothing happens
		
	# Keep visual debugging updated
	queue_redraw()
	
# Create or get access to a global save manager
func _ensure_global_save_manager():
	# Create a simple dictionary to store our data
	# We'll use a more straightforward approach with a class variable instead of Engine.register_singleton
	if save_data == null:
		# Access the global script singleton if it exists
		var root = get_tree().get_root()
		var global_data = root.get_node_or_null("NPCSaveManager")
		
		if global_data:
			# Use existing global singleton
			save_data = global_data
		else:
			# Initialize our own local copy of the data
			save_data = {"dialogue_states": {}}
			
			# We'll sync with disk instead of using a global object
			_load_from_disk()
	
	# For debugging - comment out in production
	# print("NPC save data: ", save_data)

# Find the dialogue manager in the scene tree
func find_dialogue_manager():
	var dm = get_node_or_null("/root/DialogueManager")
	if dm:
		print("Found DialogueManager at /root/DialogueManager")
		return dm
		
	dm = get_node_or_null("../CanvasLayer/DialogueManager")
	if dm:
		print("Found DialogueManager at ../CanvasLayer/DialogueManager")
		return dm
		
	# Try to find it anywhere in the scene
	var potential_managers = get_tree().get_nodes_in_group("dialogue_manager")
	if potential_managers.size() > 0:
		print("Found DialogueManager via group")
		return potential_managers[0]
		
	# Not found, will need to be assigned later
	return null

# Check if player is in range
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Player entered NPC range: " + npc_name)
		player = body
		in_range = true
		
		# Play reaction animation
		play_animation("react")
		
		# Check if the dialogue manager exists
		if not dialogue_manager:
			dialogue_manager = find_dialogue_manager()
		
		# Auto-trigger dialogue after short delay
		if not dialogue_cooldown:
			get_tree().create_timer(0.2).timeout.connect(func(): 
				if in_range and not dialogue_cooldown:
					print("Auto-triggering dialogue for: " + npc_name)
					show_dialogue()
			)

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("Player exited NPC range: " + npc_name)
		player = null
		in_range = false
		
		# Return to default animation
		if not is_talking:
			play_animation(default_animation)

# Play a specific animation
func play_animation(anim_name: String):
	var animated_sprite = $AnimatedSprite2D
	if animated_sprite and sprite_frames and sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		current_animation = anim_name
		print("NPC " + npc_name + " playing animation: " + anim_name)

# Show dialogue from the NPC - special first time or random from list
func show_dialogue():
	if dialogue_manager == null:
		dialogue_manager = find_dialogue_manager()
		
	if dialogue_manager and not dialogue_cooldown:
		print("Showing dialogue for: " + npc_name)
		# Set cooldown to prevent dialogue spam
		dialogue_cooldown = true
		
		# Start talking animation
		is_talking = true
		play_animation("talk")
		
		var dialogue_text = ""
		
		# Check if this is the first interaction and use first-time dialogue
		if not has_shown_first_dialogue and first_time_dialogue.strip_edges() != "":
			dialogue_text = first_time_dialogue
			has_shown_first_dialogue = true
			# Save the state after first dialogue is shown
			_save_npc_state()
		# Otherwise, pick a random dialogue from the list
		elif dialogues.size() > 0:
			dialogue_text = dialogues[randi() % dialogues.size()]
		else:
			# Fallback if no regular dialogues
			dialogue_text = "..."
		
		# Display the dialogue with NPC info - now using character-by-character display
		if dialogue_manager.has_method("show_dialogue"):
			dialogue_manager.show_dialogue(npc_name, dialogue_text, portrait_texture, self)
			
			# Connect to dialogue hidden signal if available and not already connected
			if dialogue_manager.has_signal("dialogue_hidden") and not dialogue_manager.is_connected("dialogue_hidden", _on_dialogue_hidden):
				dialogue_manager.connect("dialogue_hidden", _on_dialogue_hidden)
		else:
			print("ERROR: dialogue_manager doesn't have show_dialogue method!")
			# End talking state after a delay
			get_tree().create_timer(2.0).timeout.connect(func(): is_talking = false)
		
		# Stop player movement during dialogue
		if player and player.has_method("set_can_move"):
			player.set_can_move(false)
		
		# Reset cooldown after a delay
		get_tree().create_timer(2.0).timeout.connect(func(): dialogue_cooldown = false)
	elif not dialogue_manager:
		print("ERROR: dialogue_manager is null when trying to show dialogue!")

func show_dialogue_text_with_sound(text: String):
	# Find the DialogueManager
	if dialogue_manager == null:
		dialogue_manager = find_dialogue_manager()
	
	if dialogue_manager and dialogue_manager.has_method("show_dialogue_text_with_sound"):
		# Call the method that will show one character at a time
		dialogue_manager.show_dialogue_text_with_sound(text, self)
	else:
		print("ERROR: DialogueManager not found or doesn't have required method!")

func play_speech_sound():
	if talk_player == null:
		return
	
	# Stop any current sound
	talk_player.stop()
	
	# Select the appropriate sound based on the type
	var sound_to_play = null
	match speech_sound_type:
		SpeechSoundType.SILLY:
			sound_to_play = SILLY_TALK_SOUND
		SpeechSoundType.HIGH:
			sound_to_play = HIGH_TALK_SOUND
		SpeechSoundType.ENEMY:
			sound_to_play = ENEMY_TALK_SOUND
		SpeechSoundType.PLAYER:
			sound_to_play = PLAYER_TALK_SOUND
	
	# Check if we have a valid sound
	if sound_to_play == null:
		print("WARNING: No valid speech sound selected for: " + npc_name)
		return
	
	# Set sound
	talk_player.stream = sound_to_play
	
	# Randomize pitch for variety (between 0.9 and 1.1)
	talk_player.pitch_scale = randf_range(0.9, 1.1)
	
	# Play sound
	talk_player.play()

# Called when dialogue is hidden
func _on_dialogue_hidden():
	print("Dialogue ended for " + npc_name)
	is_talking = false
	
	# Return to react animation if player is still nearby, or idle if not
	if in_range:
		play_animation("react")
	else:
		play_animation(default_animation)

# Save NPC state to persistent storage
func _save_npc_state():
	# Make sure we have access to the global save data
	_ensure_global_save_manager()
	
	if save_data and "dialogue_states" in save_data:
		# Get unique NPC ID
		var npc_id = _get_npc_id()
		
		# Save to in-memory store
		save_data["dialogue_states"][npc_id] = has_shown_first_dialogue
		
		# Also save to disk
		_save_to_disk()
		
		print("Saved dialogue state for " + npc_name + ": " + str(has_shown_first_dialogue))

# Load NPC state from persistent storage
func _load_npc_state():
	# Make sure we have access to the global save data
	_ensure_global_save_manager()
	
	# Default state - hasn't shown first dialogue yet
	has_shown_first_dialogue = false
	
	# Get unique NPC ID
	var npc_id = _get_npc_id()
	
	if save_data and save_data.has("dialogue_states"):
		# Check if we have saved state for this NPC
		if npc_id in save_data["dialogue_states"]:
			has_shown_first_dialogue = save_data["dialogue_states"][npc_id]
			print("Loaded dialogue state for " + npc_name + ": " + str(has_shown_first_dialogue))
		else:
			print("No saved dialogue state for " + npc_name + ", using default (false)")
	
	# Also try loading from disk if memory store is empty
	if save_data and save_data.has("dialogue_states") and save_data["dialogue_states"].is_empty():
		_load_from_disk()
		
		# Check again after loading from disk
		if save_data.has("dialogue_states") and npc_id in save_data["dialogue_states"]:
			has_shown_first_dialogue = save_data["dialogue_states"][npc_id]
			print("Loaded dialogue state from disk for " + npc_name + ": " + str(has_shown_first_dialogue))

# Get a unique identifier for this NPC
func _get_npc_id() -> String:
	# Create a case-sensitive, unique ID by replacing spaces with underscores
	# This ensures "Villager", "Farmer", etc. all get separate IDs
	return npc_name

# Save all NPC states to disk
func _save_to_disk():
	var config = ConfigFile.new()
	var save_path = "user://npc_states.cfg"
	
	# First try to load existing file if it exists
	if FileAccess.file_exists(save_path):
		var err = config.load(save_path)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			print("Error loading NPC save file: ", err)
	
	# Save all the in-memory NPC states to disk
	if "dialogue_states" in save_data:
		for npc_id in save_data["dialogue_states"]:
			config.set_value("npc_dialogues", npc_id, save_data["dialogue_states"][npc_id])
	
	# Write the file
	var err = config.save(save_path)
	if err != OK:
		print("Error saving NPC states: ", err)
	else:
		print("NPC dialogue states saved to disk")

# Load all NPC states from disk
func _load_from_disk():
	var config = ConfigFile.new()
	var save_path = "user://npc_states.cfg"
	
	# Check if file exists
	if not FileAccess.file_exists(save_path):
		print("No NPC save file found")
		return
	
	# Load the file
	var err = config.load(save_path)
	if err != OK:
		print("Error loading NPC save file: ", err)
		return
	
	# Make sure our data structure is initialized
	if not save_data.has("dialogue_states"):
		save_data["dialogue_states"] = {}
	
	# Read all the saved NPC states
	var section_keys = config.get_section_keys("npc_dialogues")
	for npc_id in section_keys:
		var dialogue_shown = config.get_value("npc_dialogues", npc_id, false)
		save_data["dialogue_states"][npc_id] = dialogue_shown
		print("Loaded from disk: " + npc_id + " = " + str(dialogue_shown))

# Function to reset this NPC's dialogue state (call from inspector for testing)
func reset_dialogue_state():
	has_shown_first_dialogue = false
	
	# Also update the persistent storage
	_ensure_global_save_manager()
	
	if save_data and "dialogue_states" in save_data:
		var npc_id = _get_npc_id()
		save_data["dialogue_states"][npc_id] = false
		_save_to_disk()
	
	print("*** RESET DIALOGUE STATE FOR: " + npc_name + " ***")

# Function you can call directly from the Inspector for testing
func test_first_time_dialogue():
	print("*** TESTING FIRST TIME DIALOGUE FOR: " + npc_name + " ***")
	
	# Force reset this NPC's dialogue state
	has_shown_first_dialogue = false
	
	# Trigger dialogue immediately
	if not is_talking and not dialogue_cooldown:
		show_dialogue()
	
	# Let the user know how to set this up permanently
	print("TIP: To make this permanent, call reset_dialogue_state()")

# Static function to reset ALL NPC dialogue states
static func reset_all_dialogue_states():
	# Delete the save file
	var save_path = "user://npc_states.cfg"
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(save_path)
			print("*** ALL NPC DIALOGUE STATES RESET ***")
			
	# Note: Each NPC will reset its own state when it loads next time
