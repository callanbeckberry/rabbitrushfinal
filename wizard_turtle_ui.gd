extends Control

# UI Components
@onready var turtle_sprite = $TurtleSprite
@onready var dialogue_box = $DialogueBox
@onready var dialogue_text = $DialogueBox/DialogueText
@onready var typing_timer = $TypingTimer
@onready var comment_timer = $CommentTimer
@onready var letter_sound_player = AudioStreamPlayer.new()

# Configuration
var typing_speed = 0.03  # Time between characters
var min_comment_interval = 10.0  # Minimum seconds between comments
var max_comment_interval = 60.0  # Maximum seconds between comments
var talk_sound = preload("res://sounds/enemy_talk.wav")
var sound_variation = 0.1  # Pitch variation amount

# Animation configuration
var bob_amount_talking = 0.5  # Amount to bob when talking
var bob_speed_talking = 8.0  # Speed of bobbing when talking

# State variables
var talking = false
var full_text = ""
var current_text_length = 0
var auto_hide_timer = null
var current_tween = null
var original_position = Vector2.ZERO
var bob_amount = 3
var bob_speed = 2
var letter_count = 0  # To track letters for sound variation

# Array of mean comments
var mean_comments = [
	"Your movement is pathetic!",
	"Even a real turtle would collect coins faster.",
	"Are you even trying to play this game?",
	"I've seen idiots with better strategy.",
	"That move was a waste of button mash.",
	"Do you actually know what you're doing?",
	"Oh great, you are stealing my coins.",
	"At this rate you'll never revitalize the economy.",
	"You're making this WAY harder than it needs to be.",
	"I could beat this game in my shell, which is WAY harder",
	"Are you collecting coins or just wandering aimlessly?",
	"Yeah can I get uuuuuuuuuuuuuu uuuuuuuuuuuuuuu uuuuuuuuh",
	"Your style hurts my wizardly senses.",
	"I hate you so goddamn much.",
	"I'd help you, but it's funnier to watch you struggle.",
	"Rush Rabbit more like... Shush Shutup.",
	"If I had hands, I'd facepalm right now.",
	"I've seen better gameplay from a rock.",
	"My magic crystal says you suck.",
	"One day we will look back on this and laugh"
]

# Array of post-battle comments
var post_battle_comments = [
	"OW Jesus Christ!.",
	"I let you hit me, I'm into that",
	"I've seen better fighting from like, a dog.",
	"Think you're a big man hitting a turtle?",
	"I'm endangered you know.",
	"Ok that one hurt.",
	"That wasn't me that was another turtle.",
	"You call that a victory? I call it dumb luck.",
	"You're slightly less terrible thank I thought.",
	"Ahem... your mother.",
	"Don't get cocky. That was the easy one.",
	"The way you fight hurts my wizardly sensibilities.",
	"You won! NOT!",
	"This isn't even my final form.",
	"You fight like you had a bad childhood."
]

func _ready():
	# Wait one frame to ensure all nodes are loaded
	await get_tree().process_frame
	
	# Initialize with empty text and hidden panel
	if dialogue_text:
		dialogue_text.text = ""
	else:
		push_error("DialogueText node not found!")
		
	if dialogue_box:
		dialogue_box.visible = false
	else:
		push_error("DialogueBox node not found!")
	
	# Store original position for bobbing animation
	if turtle_sprite:
		original_position = turtle_sprite.position
		# Set initial animation
		_set_turtle_animation("idle")
	else:
		push_error("TurtleSprite node not found!")
	
	# Connect timers
	if typing_timer:
		typing_timer.timeout.connect(_on_typing_timer_timeout)
	else:
		push_error("TypingTimer node not found!")
		
	if comment_timer:
		comment_timer.timeout.connect(_on_comment_timer_timeout)
	else:
		push_error("CommentTimer node not found!")
	
	# Set up the sound player
	_setup_sound_player()
	
	# Start with a random interval for first comment
	start_random_timer()

func _setup_sound_player():
	# Add sound player as child
	add_child(letter_sound_player)
	
	# Set the sound
	letter_sound_player.stream = talk_sound
	
	# Default volume
	letter_sound_player.volume_db = -8.0  # Quieter for talk sounds

# Helper function to set the turtle animation
func _set_turtle_animation(animation_name):
	if turtle_sprite and turtle_sprite is AnimatedSprite2D:
		if turtle_sprite.sprite_frames.has_animation(animation_name):
			turtle_sprite.play(animation_name)
		else:
			push_error("Animation not found: " + animation_name)

func _process(delta):
	# Only animate turtle sprite bobbing when talking
	if turtle_sprite:
		if talking:
			# Use bobbing only when talking
			bob_amount = bob_amount_talking
			bob_speed = bob_speed_talking
			turtle_sprite.position.y = original_position.y + sin(Time.get_ticks_msec() * 0.005 * bob_speed) * bob_amount
		else:
			# No bobbing when idle - just maintain original position
			turtle_sprite.position.y = original_position.y
	
	# Check for key presses
	# Skip typing with UI accept or mouse click
	if typing_timer and typing_timer.is_stopped() == false:
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			print("Dialogue skip triggered by input")
			skip_typing()
	
	# Show hint text when 'hint' action is pressed (F key)
	if Input.is_action_just_pressed("hint"):
		print("Hint action detected - showing hint")
		force_comment("Hint: Get coins! Mash buttons! Spend money...")

func start_random_timer():
	if comment_timer:
		var interval = randf_range(min_comment_interval, max_comment_interval)
		comment_timer.wait_time = interval
		comment_timer.start()
		print("Wizard Turtle will speak in " + str(interval) + " seconds")

func _on_comment_timer_timeout():
	# Display a random mean comment
	show_mean_comment()
	
	# Reset timer for next comment
	start_random_timer()

func show_mean_comment():
	# Pick a random comment
	var comment = mean_comments[randi() % mean_comments.size()]
	show_message(comment)

# Public method to show a message
func show_message(message: String):
	# Make sure we have the required nodes
	if not dialogue_box or not dialogue_text:
		push_error("DialogueBox or DialogueText nodes not found!")
		return
		
	# Store full message
	full_text = message
	
	# Reset current display
	current_text_length = 0
	dialogue_text.text = ""
	letter_count = 0  # Reset letter count for sound variation
	
	# Start talking animation
	talking = true
	_set_turtle_animation("talk")  # Switch to talk animation
	
	# Cancel any previous animations
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Make panel visible but start with zero scale
	dialogue_box.visible = true
	dialogue_box.scale = Vector2.ZERO
	
	# Create pop-in animation
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_ELASTIC)
	current_tween.tween_property(dialogue_box, "scale", Vector2(1, 1), 0.3)
	
	# Wait for animation to finish before starting text
	current_tween.tween_callback(func(): _start_typing_effect())
	
	# Cancel any previous auto-hide timer
	if auto_hide_timer:
		if auto_hide_timer.is_connected("timeout", _on_auto_hide_timeout):
			auto_hide_timer.timeout.disconnect(_on_auto_hide_timeout)
		auto_hide_timer.queue_free()
		auto_hide_timer = null

# Start the typing effect
func _start_typing_effect():
	if typing_timer:
		typing_timer.wait_time = typing_speed
		typing_timer.start()

# Play a sound for the current letter
func _play_letter_sound():
	# Only play sound for actual characters (not spaces or punctuation)
	var current_char = ""
	if current_text_length > 0 and current_text_length <= full_text.length():
		current_char = full_text[current_text_length - 1]
	
	# Skip sound for spaces and punctuation
	if current_char == " " or current_char == "." or current_char == "," or current_char == "!" or current_char == "?":
		return
	
	# Stop any currently playing sound
	letter_sound_player.stop()
	
	# Vary pitch slightly based on letter count for more natural sound
	letter_count += 1
	var pitch_variation = 1.0 + (sin(letter_count * 0.5) * sound_variation)
	letter_sound_player.pitch_scale = pitch_variation
	
	# Play the sound
	letter_sound_player.play()

# Called when typing timer times out
func _on_typing_timer_timeout():
	if not dialogue_text:
		typing_timer.stop()
		return
		
	current_text_length += 1
	
	if current_text_length <= full_text.length():
		# Show one more character
		dialogue_text.text = full_text.substr(0, current_text_length)
		
		# Play sound for this letter
		_play_letter_sound()
	else:
		# Typing is complete
		typing_timer.stop()
		
		# Set up auto-hide timer
		auto_hide_timer = Timer.new()
		auto_hide_timer.one_shot = true
		auto_hide_timer.wait_time = 4.0  # Show for 4 seconds
		auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
		add_child(auto_hide_timer)
		auto_hide_timer.start()

# Called when auto-hide timer finishes
func _on_auto_hide_timeout():
	hide_bubble()

# Public method to hide the bubble
func hide_bubble():
	if not dialogue_box or not turtle_sprite:
		return
		
	# Cancel any active typing
	if typing_timer:
		typing_timer.stop()
	
	# Cancel any previous animations
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	# Create pop-out animation
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.tween_property(dialogue_box, "scale", Vector2.ZERO, 0.2)
	
	# Hide after animation completes
	current_tween.tween_callback(func():
		dialogue_box.visible = false
		talking = false
		# Reset turtle position
		turtle_sprite.position = original_position
		# Return to idle animation
		_set_turtle_animation("idle")
	)

# Skip to the end of typing animation
func skip_typing():
	if not dialogue_text or not typing_timer:
		return
		
	typing_timer.stop()
	dialogue_text.text = full_text
	current_text_length = full_text.length()
	
	# Stop any active sound
	letter_sound_player.stop()
	
	# Reset auto-hide timer for shorter duration
	if auto_hide_timer:
		auto_hide_timer.stop()
		auto_hide_timer.queue_free()
	
	# Create new auto-hide timer with shorter duration
	auto_hide_timer = Timer.new()
	auto_hide_timer.one_shot = true
	auto_hide_timer.wait_time = 2.0  # Shorter display time when skipped
	auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
	add_child(auto_hide_timer)
	auto_hide_timer.start()

# Call this function to force a comment (for testing or gameplay events)
func force_comment(specific_comment = ""):
	# Cancel any active timers
	if comment_timer:
		comment_timer.stop()
	
	if specific_comment != "":
		show_message(specific_comment)
	else:
		show_mean_comment()
	
	# Restart timer for next comment
	start_random_timer()

# Call this to add a new mean comment to the list
func add_mean_comment(comment):
	mean_comments.append(comment)

# Public method to hide the entire wizard turtle UI
func hide_wizard_turtle():
	# Hide dialogue bubble if it's visible
	if dialogue_box and dialogue_box.visible:
		hide_bubble()
	
	# Stop any pending comments
	if comment_timer:
		comment_timer.stop()
	
	# Hide the turtle sprite
	if turtle_sprite:
		turtle_sprite.visible = false
	
	# Hide self (entire control node)
	visible = false

# Public method to show the wizard turtle UI again
func show_wizard_turtle():
	# Show the turtle sprite
	if turtle_sprite:
		turtle_sprite.visible = true
		_set_turtle_animation("idle")  # Set to idle animation when showing
		
	# Show self (entire control node)
	visible = true
	
	# Restart the random comment timer
	start_random_timer()
	
# Display a random post-battle comment when called
func show_post_battle_comment():
	# Show the turtle first if it's hidden
	if not visible or (turtle_sprite and not turtle_sprite.visible):
		show_wizard_turtle()
	
	# Get a random post-battle comment
	var comment = post_battle_comments[randi() % post_battle_comments.size()]
	
	# Show the comment
	show_message(comment)
	
	# Restart the timer for regular comments after showing this one
	start_random_timer()
	
# Call this when a battle ends to show a post-battle comment
func battle_ended():
	# Show the wizard turtle first
	show_wizard_turtle()
	
	# Show a post-battle comment
	show_post_battle_comment()
