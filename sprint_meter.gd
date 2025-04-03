extends Node2D

signal sprint_state_changed(state)

enum SprintState {
	IDLE,
	JOGGING,
	RUNNING,
	SPRINTING
}

# Animation nodes
@onready var rabbit_sprite: AnimatedSprite2D = $RabbitSprite
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var debug_label = $DebugLabel
@onready var run_sound_player = AudioStreamPlayer.new()

# Sound configuration
var run_sound = preload("res://sounds/runboop.wav")
var jogging_pitch = 0.8     # Lower pitch for jogging
var running_pitch = 1.4     # Higher pitch for running
var sprinting_pitch = 2.4   # High pitch for sprinting
var max_pitch = 4.2        # Maximum possible pitch at peak sprinting
var max_pitch_threshold = 90  # Press count for reaching max pitch

# Sprint parameters
@export var current_presses: int = 0
@export var cooldown_time: float = 5.0
@export var jogging_threshold: int = 1
@export var running_threshold: int = 21
@export var sprinting_threshold: int = 41
@export var ui_position: Vector2 = Vector2(50, 50)
@export var debug_mode: bool = false  # Changed to false to remove debug display

# Player reference
var player = null
var space_press_tracked = 0
var current_state: SprintState = SprintState.IDLE
var canvas_layer = null
var moved_to_canvas = false
var time_since_last_press: float = 0.0
var timer_running: bool = false
var is_visible = true

func _ready():
	# Make sure required nodes exist
	if cooldown_timer == null:
		# Create the timer if it doesn't exist
		cooldown_timer = Timer.new()
		add_child(cooldown_timer)
		cooldown_timer.name = "CooldownTimer"
	
	# Important: Directly connect the timeout signal (fixing the connection issue)
	if cooldown_timer.is_connected("timeout", _on_cooldown_timer_timeout):
		cooldown_timer.disconnect("timeout", _on_cooldown_timer_timeout)
	cooldown_timer.connect("timeout", _on_cooldown_timer_timeout)
	
	# Initialize the cooldown timer
	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.one_shot = true
	
	# Add debug label if in debug mode
	if debug_mode and debug_label == null:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.position = Vector2(0, -40)
		add_child(debug_label)
	elif debug_label:
		debug_label.visible = debug_mode
	
	# Check if RabbitSprite exists
	if rabbit_sprite == null:
		rabbit_sprite = find_child("RabbitSprite")
		
	if rabbit_sprite == null:
		push_warning("RabbitSprite not found. Please add an AnimatedSprite2D named 'RabbitSprite' as a child.")
	else:
		# Ensure the sprite is visible
		rabbit_sprite.visible = true
		rabbit_sprite.modulate.a = 1.0
		
		# Initialize animation state
		_update_animation()
	
	# Set up sound player
	_setup_sound_player()
	
	# Move to CanvasLayer if not already there
	call_deferred("_ensure_in_canvas_layer")
	
	# Find and connect to the player
	call_deferred("_find_and_connect_player")
	
	# Add to a group for easy reference
	add_to_group("sprint_meter")
	
	# Make sure we're visible
	visible = true
	modulate.a = 1.0
	
	if debug_mode:
		print("Sprint meter initialized. Debug mode: ", debug_mode)

func _setup_sound_player():
	# Add and configure sound player
	add_child(run_sound_player)
	run_sound_player.stream = run_sound
	run_sound_player.volume_db = -6.0  # Slightly quieter than default

func _play_run_sound():
	# Calculate a sliding pitch based on where we are between thresholds
	var pitch = jogging_pitch
	
	if current_presses < jogging_threshold:
		# Below jogging threshold, use base pitch
		pitch = jogging_pitch
	elif current_presses < running_threshold:
		# Between jogging and running - slide from jogging to running pitch
		var progress = float(current_presses - jogging_threshold) / float(running_threshold - jogging_threshold)
		pitch = lerp(jogging_pitch, running_pitch, progress)
	elif current_presses < sprinting_threshold:
		# Between running and sprinting - slide from running to sprinting pitch
		var progress = float(current_presses - running_threshold) / float(sprinting_threshold - running_threshold)
		pitch = lerp(running_pitch, sprinting_pitch, progress)
	else:
		# At or above sprinting threshold - continue increasing up to max_pitch
		var extra_presses = min(current_presses - sprinting_threshold, max_pitch_threshold - sprinting_threshold)
		var progress = float(extra_presses) / float(max_pitch_threshold - sprinting_threshold)
		pitch = lerp(sprinting_pitch, max_pitch, progress)
	
	# Set the calculated pitch
	run_sound_player.pitch_scale = pitch
	
	# Stop any currently playing sound and play the new one
	run_sound_player.stop()
	run_sound_player.play()
	
	if debug_mode:
		print("Run sound playing with pitch: ", pitch, " (presses: ", current_presses, ")")

func _ensure_in_canvas_layer():
	# Wait a frame to ensure scene is ready
	await get_tree().process_frame
	
	# Check if we're already a child of a CanvasLayer
	var parent = get_parent()
	if parent is CanvasLayer:
		canvas_layer = parent
		_update_ui_position()
		moved_to_canvas = true
		if debug_mode:
			print("Sprint meter already in CanvasLayer: ", parent.name)
		return
	
	# Try to find an existing CanvasLayer/UI node
	var ui_parent = get_node_or_null("/root/Main/CanvasLayer/UI")
	if ui_parent:
		# Store original properties before moving
		var original_visible = visible
		var original_modulate = modulate
		
		# Remove from current parent
		if get_parent():
			get_parent().remove_child(self)
		
		# Add to UI node
		ui_parent.add_child(self)
		
		# Set position to a good spot on screen
		position = ui_position
		
		# Restore visibility properties
		visible = original_visible
		modulate = original_modulate
		
		moved_to_canvas = true
		if debug_mode:
			print("Sprint meter moved to UI CanvasLayer")
		return
	
	# Try to find any CanvasLayer
	var canvas_layers = get_tree().get_nodes_in_group("canvas_layers")
	if canvas_layers.size() > 0:
		canvas_layer = canvas_layers[0]
	else:
		# Look for any CanvasLayer in the scene
		var all_canvas = get_tree().get_nodes_in_group("CanvasLayer")
		if all_canvas.size() > 0:
			canvas_layer = all_canvas[0]
	
	# If we found a CanvasLayer, move this node to it
	if canvas_layer:
		# Store original properties before moving
		var original_visible = visible
		var original_modulate = modulate
		
		# Remove from current parent
		if get_parent():
			get_parent().remove_child(self)
		
		# Add to CanvasLayer
		canvas_layer.add_child(self)
		
		# Set position to a good spot on screen
		position = ui_position
		
		# Restore visibility properties
		visible = original_visible
		modulate = original_modulate
		
		moved_to_canvas = true
		if debug_mode:
			print("Sprint meter moved to CanvasLayer: ", canvas_layer.name)
	else:
		push_warning("Could not find a CanvasLayer to hold the sprint meter. It will move with the camera.")

func _update_ui_position():
	# Set position to a good spot on screen when in a CanvasLayer
	position = ui_position
	if debug_mode:
		print("Sprint meter position updated to: ", position)

func _find_and_connect_player():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Try to find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		if debug_mode:
			print("Sprint meter connected to player: ", player.name)
		
		# Connect to player's battle signals if they exist
		if not player.is_connected("battle_started", _on_battle_started):
			player.connect("battle_started", _on_battle_started)
		if not player.is_connected("battle_ended", _on_battle_ended):
			player.connect("battle_ended", _on_battle_ended)
	else:
		push_warning("Could not find a player node in the 'player' group.")

# Add these two functions to hide/show during battles
func _on_battle_started():
	if debug_mode:
		print("Sprint meter hiding for battle")
	is_visible = false
	visible = false

func _on_battle_ended():
	if debug_mode:
		print("Sprint meter showing after battle")
	is_visible = true
	visible = true

func _process(delta):
	# Update timer tracking
	if timer_running:
		time_since_last_press += delta
		
		# Manual cooldown check to ensure it works
		if time_since_last_press >= cooldown_time:
			timer_running = false
			time_since_last_press = 0
			_on_cooldown_timer_timeout()
	
	# Update debug information
	if debug_mode and debug_label:
		# Show debug info
		var state_names = ["IDLE", "JOGGING", "RUNNING", "SPRINTING"]
		var debug_text = "State: " + state_names[current_state]
		debug_text += "\nPresses: " + str(current_presses)
		debug_text += "\nTimer: " + str(int(cooldown_time - time_since_last_press)) + "s"
		debug_text += "\nPosition: " + str(position)
		debug_text += "\nVisible: " + str(visible)
		debug_label.text = debug_text
	
	# Check visibility after moving to canvas (but respect battle state)
	if moved_to_canvas and not visible and is_visible:
		visible = true
		if rabbit_sprite:
			rabbit_sprite.visible = true
		if debug_mode:
			print("Forcing sprint meter to be visible")
	
	if player == null:
		# Try to find player again if not found
		_find_and_connect_player()
		return
	
	# Skip updating if in battle
	if player.in_battle:
		return
		
	# Check if the player's space bar count has changed
	var new_space_count = player.space_press_count
	
	if new_space_count != space_press_tracked:
		# Space bar has been pressed, increment our counter
		if new_space_count > space_press_tracked:
			current_presses += 1
			
			# Reset the timer (both object and manual tracking)
			cooldown_timer.stop()
			cooldown_timer.start(cooldown_time)
			time_since_last_press = 0
			timer_running = true
			
			# Update animation based on new press count
			_update_state()
			_update_animation()
			
			# Play run sound with appropriate pitch
			_play_run_sound()
		
		# Update our tracked value
		space_press_tracked = new_space_count

func _on_cooldown_timer_timeout():
	if debug_mode:
		print("Cooldown timer timeout triggered")
	
	# Decrease state by one level after cooldown
	if current_presses > 0:
		match current_state:
			SprintState.SPRINTING:
				current_presses = running_threshold
				if debug_mode:
					print("Decreasing from SPRINTING to RUNNING")
			SprintState.RUNNING:
				current_presses = jogging_threshold
				if debug_mode:
					print("Decreasing from RUNNING to JOGGING")
			SprintState.JOGGING:
				current_presses = 0
				if debug_mode:
					print("Decreasing from JOGGING to IDLE")
		
		# Update animation based on new state
		_update_state()
		_update_animation()
		
		# Restart timer if not at idle
		if current_state != SprintState.IDLE:
			cooldown_timer.stop()
			cooldown_timer.start(cooldown_time)
			time_since_last_press = 0
			timer_running = true

func _update_state():
	# Determine the current state based on press count
	var new_state
	if current_presses >= sprinting_threshold:
		new_state = SprintState.SPRINTING
	elif current_presses >= running_threshold:
		new_state = SprintState.RUNNING
	elif current_presses >= jogging_threshold:
		new_state = SprintState.JOGGING
	else:
		new_state = SprintState.IDLE
	
	# Only update if state changed
	if new_state != current_state:
		current_state = new_state
		
		# Emit signal when state changes
		emit_signal("sprint_state_changed", current_state)
		if debug_mode:
			print("Sprint state changed to: ", current_state)

func _update_animation():
	# Only update animation if sprite exists
	if rabbit_sprite:
		# Make sure sprite is visible
		rabbit_sprite.visible = true
		
		# Change animation based on current state
		match current_state:
			SprintState.IDLE:
				rabbit_sprite.play("idle")
			SprintState.JOGGING:
				rabbit_sprite.play("jogging")
			SprintState.RUNNING:
				rabbit_sprite.play("running")
			SprintState.SPRINTING:
				rabbit_sprite.play("sprinting")
				
		if debug_mode:
			print("Playing animation: ", rabbit_sprite.animation)
	else:
		# Print debug info about current state even without sprite
		if debug_mode:
			print("Cannot play animation - sprite missing")

# Public method to reset counter
func reset_counter():
	current_presses = 0
	_update_state()
	_update_animation()

# Get current state (for other scripts to check)
func get_current_state() -> int:
	return current_state
	
# Force visibility (call this from outside if needed)
func force_visible():
	if is_visible:  # Only force visible if we're supposed to be visible (not in battle)
		visible = true
		if rabbit_sprite:
			rabbit_sprite.visible = true
		if debug_mode:
			print("Visibility forced on")
