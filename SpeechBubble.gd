extends Node2D
class_name SpeechBubble

# UI Components - adjust node paths if needed
@onready var bubble_panel = $BubblePanel
@onready var text_label = $BubblePanel/TextContainer/Label
@onready var typing_timer = $TypingTimer

# Configuration - adjust these to your needs
var target_node: Node2D = null
var offset = Vector2(0, -60)
var typing_speed = 0.03  # Time between characters
var auto_hide_after = 3.0  # Hide bubble after this many seconds
var follow_target = true

# State variables
var full_text = ""
var current_text_length = 0
var auto_hide_timer = null
var current_tween = null

# Sound effect variables
var talk_player: AudioStreamPlayer
var is_player_bubble: bool = false  # Set to true for player, false for enemy
var player_talk_sound = preload("res://sounds/player_talk.wav")
var enemy_talk_sound = preload("res://sounds/enemy_talk.wav")

# Signals
signal typing_completed
signal bubble_hidden

func _ready():
	# Initialize with empty text and hidden
	text_label.text = ""
	visible = false
	bubble_panel.scale = Vector2.ZERO
	
	# Connect typing timer
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	
	# Create audio player for letter sounds
	talk_player = AudioStreamPlayer.new()
	add_child(talk_player)
	talk_player.volume_db = -10.0  # Adjust volume as needed

func _process(delta):
	# Update position if we have a target and should follow
	if target_node and follow_target and visible:
		global_position = target_node.global_position + offset

# Set whether this is a player or enemy bubble (for voice sounds)
func set_character_type(is_player: bool):
	is_player_bubble = is_player

# Public method to show a message
func show_message(message: String):
	# Store full message
	full_text = message
	
	# Reset current display
	current_text_length = 0
	text_label.text = ""
	
	# Cancel any previous animations
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Make visible but start with zero scale
	visible = true
	bubble_panel.scale = Vector2.ZERO
	
	# Create pop-in animation
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_ELASTIC)
	current_tween.tween_property(bubble_panel, "scale", Vector2(1, 1), 0.3)
	
	# Wait for animation to finish before starting text
	await current_tween.finished
	
	# Start typing animation
	_start_typing_effect()
	
	# Cancel any previous auto-hide timer
	if auto_hide_timer:
		if auto_hide_timer.is_connected("timeout", Callable(self, "_on_auto_hide_timeout")):
			auto_hide_timer.timeout.disconnect(_on_auto_hide_timeout)
		auto_hide_timer.queue_free()
		auto_hide_timer = null

# Start the typing effect
func _start_typing_effect():
	typing_timer.wait_time = typing_speed
	typing_timer.start()

# Called when typing timer times out
func _on_typing_timer_timeout():
	current_text_length += 1
	
	if current_text_length <= full_text.length():
		# Show one more character
		text_label.text = full_text.substr(0, current_text_length)
		
		# Play sound for this letter (unless it's a space)
		if current_text_length > 0 and full_text[current_text_length-1] != " ":
			_play_letter_sound()
	else:
		# Typing is complete
		typing_timer.stop()
		emit_signal("typing_completed")
		
		# Set up auto-hide timer
		auto_hide_timer = Timer.new()
		auto_hide_timer.one_shot = true
		auto_hide_timer.wait_time = auto_hide_after
		auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
		add_child(auto_hide_timer)
		auto_hide_timer.start()

# Play a sound for each letter with random pitch variation
func _play_letter_sound():
	talk_player.stop()  # Stop any currently playing sound
	
	# Choose appropriate sound
	if is_player_bubble:
		talk_player.stream = player_talk_sound
		# Higher pitch range for player (rabbit)
		talk_player.pitch_scale = randf_range(1.1, 1.3)
	else:
		talk_player.stream = enemy_talk_sound
		# Lower pitch range for enemy (turtle)
		talk_player.pitch_scale = randf_range(0.7, 0.9)
	
	talk_player.play()

# Called when auto-hide timer finishes
func _on_auto_hide_timeout():
	hide_bubble()

# Public method to hide the bubble
func hide_bubble():
	# Cancel any active typing
	typing_timer.stop()
	
	# Cancel any previous animations
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Create pop-out animation
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.tween_property(bubble_panel, "scale", Vector2.ZERO, 0.2)
	
	# Hide after animation completes
	current_tween.tween_callback(func():
		visible = false
		emit_signal("bubble_hidden")
	)

# Skip to the end of typing animation
func skip_typing():
	typing_timer.stop()
	text_label.text = full_text
	current_text_length = full_text.length()
	emit_signal("typing_completed")
	
	# Reset auto-hide timer
	if auto_hide_timer:
		auto_hide_timer.stop()
		auto_hide_timer.start()

# Set the node this bubble should follow
func set_target(new_target: Node2D, new_offset: Vector2 = Vector2(0, -60)):
	target_node = new_target
	offset = new_offset
	
	# Update position immediately if visible
	if target_node and visible:
		global_position = target_node.global_position + offset

# Customize speech bubble appearance
func set_colors(bubble_color: Color, text_color: Color):
	if bubble_panel is Panel:
		# Get the stylebox and change its color
		var style = bubble_panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = bubble_color
	else:
		# For other nodes like NinePatchRect, use modulate
		bubble_panel.modulate = bubble_color
	
	text_label.add_theme_color_override("font_color", text_color)
