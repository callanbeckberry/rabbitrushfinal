extends Node2D

# References to nodes (updated to use AnimatedSprite2D)
@onready var player_sprite = $PlayerSprite
@onready var enemy_sprite = $EnemySprite
@onready var player_attack_bar = $UI/AttackBar
@onready var direction_prompt = $UI/DirectionPrompt
@onready var attack_menu = $UI/AttackMenu
@onready var transition_rect = $TransitionRect  # Add this manually in editor
@onready var camera = $Camera2D  # Add this manually in editor
@onready var attack_timer = $Timers/EnemyAttackTimer
@onready var global_ui_manager = get_node("/root/GlobalUIManager")  # Reference to GlobalUIManager autoload
@onready var speed_up_label = $UI/SpeedUpLabel 
@onready var talk_player = AudioStreamPlayer.new()
@onready var effect_player = AudioStreamPlayer.new()
@onready var ui_player = AudioStreamPlayer.new()  # For success/fail sounds
var coin_sound_player: AudioStreamPlayer

# Preload the speech bubble scene
const SpeechBubbleScene = preload("res://SpeechBubble.tscn")
const CustomFont = preload("res://orangekid.otf")
const PLAYER_TALK_SOUND = preload("res://sounds/player_talk.wav")  # Higher-pitched rabbit sound
const ENEMY_TALK_SOUND = preload("res://sounds/enemy_talk.wav")    # Lower-pitched turtle sound
const ATTACK_SOUND = preload("res://sounds/attack.wav")            # Whoosh/strike sound
const HIT_SOUND = preload("res://sounds/hit.wav")                  # Impact sound
const CHARGE_SOUND = preload("res://sounds/charge.wav")            # Energetic buildup sound
const SUCCESS_SOUND = preload("res://sounds/success.wav")          # Positive ding/bell
const FAIL_SOUND = preload("res://sounds/fail.wav")                # Negative buzzer/thud
const COIN_SOUND = preload("res://sounds/pickupCoin.wav")

# Signals
signal battle_started 
signal battle_ended
signal final_boss_defeated

# Battle variables
var in_battle = false
var direction_inputs_correct = 0
var current_prompt_direction = ""
var attack_charging = false
var attack_menu_open = false
var selected_attack_index = 0
var enemy_health = 1
var speed_up_counter = 0
var max_speed_up = 4
var current_boss = null
var is_boss_battle = false
var is_final_boss = false

# Sprite animation states
var player_animation_state = "idle"
var enemy_animation_state = "idle"
var player_animations = ["idle", "attack", "hit", "charged"]
var enemy_animations = ["idle", "attack", "hit"]

# Transition effect variables
var transition_duration = 1.5
var transition_blocks = []

# Speech bubbles
var enemy_speech_bubble = null
var player_speech_bubble = null
var is_player_bubble: bool = false  # Set to true for player, false for enemy
var player_talk_sound = preload("res://sounds/player_talk.wav")
var enemy_talk_sound = preload("res://sounds/enemy_talk.wav")
var letter_index: int = 0
var text_to_display: String = ""
var letter_timer: Timer

# UI content arrays
var enemy_attack_names = ["Menacing Glare", "Intimidating Growl", "Mighty Roar", "Fierce Scratch", "Scary Face", "Tail Whip", "Fearsome Bite", "Evil Eye", "Spooky Dance", "Mysterious Chant"]
var enemy_defeat_messages = ["Ouchie that hurt!", "I'll be back!", "You'll regret this!", "This isn't over!", "Nooooooo!", "How could you?!", "I was just kidding!", "My power failed me!", "Impossible!", "This is embarrassing..."]
var boss_attack_names = ["Ultimate Destruction", "Dark Energy Blast", "Soul Drain", "Shadow Strike", "Void Crusher"]
var boss_defeat_messages = ["This cannot be! I am... invincible...", "My power... how could a mere mortal...", "I shall return stronger than ever!", "Remember this day... for it marks the beginning of your doom...", "The darkness... it calls to me..."]
var player_attacks = ["Heroic Punch", "Valiant Slash", "Righteous Beam", "Courageous Strike", "Legendary Smash"]
var directions = ["battleup", "battledown", "battleleft", "battleright"]

# Battle logic functions go here

func _ready():
	add_to_group("battle_scene")
	visible = false
	attack_menu.visible = false
	attack_menu_open = false
	attack_charging = false
	selected_attack_index = 0
	if camera:
		camera.add_to_group("cameras")
		camera.enabled = false
	player_attack_bar.max_value = 20
	player_attack_bar.value = 0
	attack_timer.timeout.connect(_on_enemy_attack_timer_timeout)
	_setup_sound_players()  # Note: The asterisks should be underscores
	_setup_sprite_animations()  # Note: The asterisks should be underscores
	setup_speech_bubbles()
	direction_prompt.visible = false
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	# Set up the direction prompt with the battlebuttons SpriteFrames
	if direction_prompt is AnimatedSprite2D:
		if ResourceLoader.exists("res://battlebuttons.tres"):
			direction_prompt.sprite_frames = load("res://battlebuttons.tres")
			# Set a larger default scale - adjust these values as needed
			direction_prompt.scale = Vector2(2.0, 2.0)  # Makes it twice as big

# Update your show_message function to use letter-by-letter display
func show_message(text_content, duration = 3.0):
	visible = true
	text_to_display = text_content
	letter_index = 0
	$MessageLabel.text = ""  # Clear text first
	
	# Start the letter timer
	letter_timer.start()

func _setup_sound_players():
	# Add and configure audio players
	add_child(talk_player)
	add_child(effect_player)
	add_child(ui_player)
	
	# Set default volumes
	talk_player.volume_db = -8.0  # Quieter for talk sounds
	effect_player.volume_db = -5.0
	ui_player.volume_db = -10.0
	
	coin_sound_player = AudioStreamPlayer.new()
	add_child(coin_sound_player)
	coin_sound_player.volume_db = -5.0  # Adjust as needed

func _play_coin_sound():
	if not COIN_SOUND or not coin_sound_player:
		return
		
	coin_sound_player.stream = COIN_SOUND
	coin_sound_player.play()

func _play_talk_sound(is_player):
	# Stop any current talk sound
	talk_player.stop()
	
	# Set the appropriate sound based on who's talking
	if is_player:
		talk_player.stream = PLAYER_TALK_SOUND  # Rabbit sound
	else:
		talk_player.stream = ENEMY_TALK_SOUND   # Turtle sound
	
	# Play the sound
	talk_player.play()
	
func _play_effect_sound(sound_type):
	# Stop any current effect sound
	effect_player.stop()
	
	# Set the appropriate sound
	match sound_type:
		"attack":
			effect_player.stream = ATTACK_SOUND
		"hit":
			effect_player.stream = HIT_SOUND
		"charge":
			effect_player.stream = CHARGE_SOUND
		_:
			print("Unknown sound effect: " + sound_type)
			return
	
	# Play the sound
	effect_player.play()

func _play_ui_sound(sound_type):
	# Stop any current UI sound
	ui_player.stop()
	
	# Set the appropriate sound
	match sound_type:
		"success":
			ui_player.stream = SUCCESS_SOUND
		"fail":
			ui_player.stream = FAIL_SOUND
		_:
			print("Unknown UI sound: " + sound_type)
			return
	
	# Play the sound
	ui_player.play()

# Update _setup_sprite_animations to handle PlayerSprite2
func _setup_sprite_animations():
	# Set up player sprite animations if it's an AnimatedSprite2D
	if player_sprite is AnimatedSprite2D:
		# Check if it has an "idle" animation and play it
		if player_sprite.sprite_frames.has_animation("idle"):
			player_sprite.play("idle")
			player_animation_state = "idle"
	
	# Set up enemy sprite animations if it's an AnimatedSprite2D
	if enemy_sprite is AnimatedSprite2D:
		# Check if it has an "idle" animation and play it
		if enemy_sprite.sprite_frames.has_animation("idle"):
			enemy_sprite.play("idle")
			enemy_animation_state = "idle"
			
	# Also handle PlayerSprite2 if it exists
	var player_sprite2 = get_node_or_null("PlayerSprite2")
	if player_sprite2 and player_sprite2 is AnimatedSprite2D:
		if player_sprite2.sprite_frames.has_animation("idle"):
			player_sprite2.play("idle")

func setup_speech_bubbles():
	enemy_speech_bubble = SpeechBubbleScene.instantiate()
	add_child(enemy_speech_bubble)
	# Set position
	enemy_speech_bubble.position = Vector2(900, 75)
	enemy_speech_bubble.set_colors(Color(1, 0.8, 0.8), Color(0, 0, 0))
	# Set this as enemy bubble
	enemy_speech_bubble.set_character_type(false)
	
	player_speech_bubble = SpeechBubbleScene.instantiate()
	add_child(player_speech_bubble)
	# Set position
	player_speech_bubble.position = Vector2(600, 150)
	player_speech_bubble.set_colors(Color(0.8, 0.9, 1.0), Color(0, 0, 0))
	# Set this as player bubble
	player_speech_bubble.set_character_type(true)

# Start a boss battle with the given boss NPC
func start_boss_battle(boss_npc = null):
	
	emit_signal("battle_started")
	
	# Optionally set z_index for all children
	for child in get_children():
		if child is CanvasItem:
			child.z_index = 1000
			
	print("Starting BOSS battle!")
	
	# Store reference to boss and set flag
	current_boss = boss_npc
	is_final_boss = boss_npc.is_final_boss if boss_npc else false
	is_boss_battle = true
	
	# Use special battle settings
	enemy_health = 1  # Make boss harder
	
	# Maybe use a different enemy sprite
	if boss_npc and enemy_sprite:
		# If boss has a portrait, use it for battle
		if boss_npc.portrait_texture:
			# For AnimatedSprite2D, we would need a different approach
			# We can't directly set texture - instead we might change animation
			if enemy_sprite is AnimatedSprite2D and enemy_sprite.sprite_frames.has_animation("boss"):
				enemy_sprite.play("boss")
				enemy_animation_state = "boss"
			print("Using boss battle animation")
	
	# If boss speech bubble exists, make it more intimidating
	#if enemy_speech_bubble:
		#enemy_speech_bubble.set_colors(Color(0.2, 0.2, 0.3, 0.9), Color(1, 0.9, 0.9))
	
	# Start with special intro
	show_enemy_speech("So, you dare to challenge me?")
	
	# Ensure battle scene is rendered on top
	z_index = 100  # Set a high z-index to ensure it renders above other elements
	
	# Ensure all battle UI elements are on top
	for child in get_children():
		if child is CanvasItem:
			child.z_index = 100
	
	# Continue with normal battle start
	start_battle_with_transition()

func start_battle_with_transition():
	# Make scene visible but prepare for transition
	visible = true
	
	# Reset battle menu state
	attack_menu.visible = false
	attack_menu_open = false
	attack_charging = false
	direction_inputs_correct = 0
	player_attack_bar.value = 0
	
	# Hide all NPCs
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = false
	
	# Ensure GlobalUI stays visible
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Set camera to a consistent position
	camera.position = Vector2.ZERO  
	camera.global_position = Vector2.ZERO
	camera.offset = Vector2.ZERO
	
	# Make sure it has no limits
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	
	# Enable camera with correct settings
	camera.enabled = true
	camera.make_current()
	
	# Force camera update to take effect immediately
	camera.force_update_scroll()
	
	# Debug output for camera
	print("Battle camera position: ", camera.global_position)
	print("Battle camera offset: ", camera.offset)
	print("Battle camera enabled: ", camera.enabled)
	
	# Start the digital transition
	_start_digital_transition_in()

func start_battle():
	print("Battle started!")
	in_battle = true
	
	# Reset battle state
	if not is_boss_battle:
		enemy_health = 1
	# Boss health is set in start_boss_battle
	
	direction_inputs_correct = 0
	player_attack_bar.value = 0
	attack_charging = true
	attack_menu_open = false
	selected_attack_index = 0
	
	# Play idle animations
	_play_player_animation("idle")
	_play_enemy_animation("idle")
	
	if speed_up_label:
		speed_up_label.text = "Speed up the battle: 0/100 ¥ added"
	
  # Show direction prompt
	direction_prompt.visible = true
	direction_prompt.modulate = Color(1, 1, 1, 1)  # Reset any color modulation
	attack_menu.visible = false
	
	# Set a random initial prompt
	_set_new_direction_prompt()
	
	# Stop any existing timer first
	if attack_timer.time_left > 0:
		attack_timer.stop()
	
	# Start enemy attack timer with longer initial delay to give player time
	var initial_delay = 15.0  # 15 seconds before first attack
	print("Initial battle delay: Enemy will wait " + str(initial_delay) + " seconds before first attack")
	attack_timer.start(initial_delay)

func _process(_delta):
	if not in_battle:
		return
		
	# First, handle "X" key presses for speeding up battle
	# In the _process() function of battle_scene.gd, modify the add_move handling:
	if Input.is_action_just_pressed("add_move"):  # This is your "X" key
		speed_up_counter += 1
		var yen_added = speed_up_counter * 25
		
		# Play coin sound
		_play_coin_sound()
		
		# Update the speed up label - change "yen" to "¥" symbol
		if speed_up_label:
			speed_up_label.text = "Speed up the battle: " + str(yen_added) + "/100 ¥ added"
		
		# If we've reached the threshold, open the attack menu
		if speed_up_counter >= max_speed_up:
			# Add yen to global UI manager
			if global_ui_manager:
				global_ui_manager.add_yen(100)  # Add 100 yen to the global counter
			
			# Skip to attack menu
			_open_attack_menu()
			
			# Reset counter
			speed_up_counter = 0
			if speed_up_label:
				speed_up_label.text = "Speed up the battle: 0/100 ¥ added"
		
		return  # Process no further input for this frame
	
	if attack_charging and not attack_menu_open:
		# Check for direction inputs
		if Input.is_action_just_pressed("battleup"):
			_check_direction_input("battleup")
		elif Input.is_action_just_pressed("battledown"):
			_check_direction_input("battledown")
		elif Input.is_action_just_pressed("battleleft"):
			_check_direction_input("battleleft")
		elif Input.is_action_just_pressed("battleright"):
			_check_direction_input("battleright")
	elif attack_menu_open:
		# Handle menu navigation
		if Input.is_action_just_pressed("up"):
			selected_attack_index = max(0, selected_attack_index - 1)
			_update_selected_attack()
		elif Input.is_action_just_pressed("down"):
			selected_attack_index = min(4, selected_attack_index + 1)
			_update_selected_attack()
		elif Input.is_action_just_pressed("ui_accept"):
			_execute_player_attack(selected_attack_index)

func _check_direction_input(input_direction):
	if input_direction == current_prompt_direction:
		# Play success sound
		_play_ui_sound("success")
		
		# Correct input - animate prompt
		_animate_prompt_success()
		
		# Correct input
		direction_inputs_correct += 1
		player_attack_bar.value = direction_inputs_correct
		
		# Play a charging animation on the player sprite if there's room to charge
		if direction_inputs_correct < 19:
			_play_player_animation("charge")
		else:
			# Play the charged animation when meter is full
			_play_player_animation("charged")
			# Don't play charge sound here anymore - moved to _open_attack_menu
		
		# Check if attack bar is full
		if direction_inputs_correct >= 20:
			_open_attack_menu()
		else:
			# Set new direction prompt after animation
			await get_tree().create_timer(0.3).timeout
			_set_new_direction_prompt()
	else:
		# Play fail sound
		_play_ui_sound("fail")
		
		# Wrong input - animate error
		_animate_prompt_error()
		
		# Wrong input, reset progress
		direction_inputs_correct = 0
		player_attack_bar.value = 0
		
		# No specific animation for failure, just return to idle
		_play_player_animation("idle")
		
		# Set new direction prompt after animation
		await get_tree().create_timer(0.5).timeout
		_set_new_direction_prompt()

# Helper functions to play animations on sprites
func _play_player_animation(anim_name):
	if player_sprite is AnimatedSprite2D and player_sprite.sprite_frames.has_animation(anim_name):
		player_sprite.play(anim_name)
		player_animation_state = anim_name
		
		# Special handling for hit animation - return to idle after 4 seconds
		if anim_name == "hit":
			if player_sprite.is_connected("animation_finished", Callable(self, "_on_player_animation_finished")):
				player_sprite.animation_finished.disconnect(_on_player_animation_finished)
			# Use timer instead of animation_finished signal for hit animation
			get_tree().create_timer(4.0).timeout.connect(func(): 
				if player_animation_state == "hit":
					_play_player_animation("idle")
			)
		# For other non-idle animations, use the animation_finished signal
		elif anim_name != "idle" and anim_name != "charged":
			# Wait until the animation finishes
			if not player_sprite.is_connected("animation_finished", Callable(self, "_on_player_animation_finished")):
				player_sprite.animation_finished.connect(_on_player_animation_finished)

func _play_enemy_animation(anim_name):
	# Make sure we're handling both the main enemy sprite and PlayerSprite2 if it exists
	var sprites_to_animate = []
	
	# Add enemy_sprite if valid
	if is_instance_valid(enemy_sprite):
		sprites_to_animate.append(enemy_sprite)
	
	# Add PlayerSprite2 if it exists and is valid
	var player_sprite2 = get_node_or_null("PlayerSprite2")
	if player_sprite2 and player_sprite2 is AnimatedSprite2D:
		sprites_to_animate.append(player_sprite2)
	
	# Animate all enemy sprites
	for sprite in sprites_to_animate:
		if sprite is AnimatedSprite2D and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
	
	enemy_animation_state = anim_name
	
	# For non-idle animations, ensure we're tracking when they end
	if anim_name != "idle" and is_instance_valid(enemy_sprite):
		# First disconnect any existing connection to avoid duplicates
		if enemy_sprite.is_connected("animation_finished", Callable(self, "_on_enemy_animation_finished")):
			enemy_sprite.animation_finished.disconnect(_on_enemy_animation_finished)
		
		# Then connect the signal to handle animation completion
		enemy_sprite.animation_finished.connect(_on_enemy_animation_finished)
		print("Connected animation_finished signal for enemy sprite")
		
		# Also use a timer as a fallback to ensure animations don't get stuck
		# This ensures animations will return to idle even if the signal somehow fails
		var reset_timer = get_tree().create_timer(2.0)  # 2 seconds should be enough for most attack animations
		reset_timer.timeout.connect(func():
			if enemy_animation_state != "idle":
				print("Animation reset via timer fallback")
				# If we're still not in idle after 2 seconds, force reset
				enemy_animation_state = "idle"
				
				for sprite in sprites_to_animate:
					if sprite is AnimatedSprite2D and sprite.sprite_frames.has_animation("idle"):
						sprite.play("idle")
		)
func _on_player_animation_finished():
	# Return to idle unless we're in a specific state that should continue
	if player_animation_state != "idle" and player_animation_state != "charged" and player_animation_state != "hit":
		_play_player_animation("idle")
		
	# Disconnect to avoid multiple connections - add null check
	if is_instance_valid(player_sprite) and player_sprite.is_connected("animation_finished", Callable(self, "_on_player_animation_finished")):
		player_sprite.animation_finished.disconnect(_on_player_animation_finished)

# Add shake effects for attacks and hits
func _shake_sprite(sprite, intensity = 5.0, duration = 0.5, is_hit = false):
	if not is_instance_valid(sprite):
		return
		
	var original_pos = sprite.position
	var tween = create_tween()
	
	# More violent shake if this is a hit reaction
	var shake_count = 5
	var shake_intensity = intensity
	
	if is_hit:
		shake_count = 7
		shake_intensity = intensity * 1.5
	
	# Create shake effect
	for i in range(shake_count):
		var offset_x = randf_range(-shake_intensity, shake_intensity)
		var offset_y = randf_range(-shake_intensity, shake_intensity) if is_hit else 0.0
		tween.tween_property(sprite, "position", original_pos + Vector2(offset_x, offset_y), duration / (shake_count * 2))
		tween.tween_property(sprite, "position", original_pos, duration / (shake_count * 2))
	
	# Ensure we end at the original position
	tween.tween_property(sprite, "position", original_pos, 0.05)

func _on_enemy_animation_finished():
	# Instead of checking animation state, directly play idle for all enemy sprites
	# This ensures they always return to idle after any animation completes
	
	print("Enemy animation finished, resetting to idle")
	
	# Reset the state tracker
	enemy_animation_state = "idle"
	
	# Reset main enemy sprite
	if is_instance_valid(enemy_sprite) and enemy_sprite is AnimatedSprite2D:
		if enemy_sprite.sprite_frames.has_animation("idle"):
			enemy_sprite.play("idle")
			print("Main enemy sprite reset to idle")
	
	# Reset PlayerSprite2 if it exists
	var player_sprite2 = get_node_or_null("PlayerSprite2")
	if player_sprite2 and player_sprite2 is AnimatedSprite2D:
		if player_sprite2.sprite_frames.has_animation("idle"):
			player_sprite2.play("idle")
			print("Player sprite 2 reset to idle")
	
	# Disconnect to avoid multiple connections
	if is_instance_valid(enemy_sprite) and enemy_sprite.is_connected("animation_finished", Callable(self, "_on_enemy_animation_finished")):
		enemy_sprite.animation_finished.disconnect(_on_enemy_animation_finished)

func _animate_prompt_success():
	var tween = create_tween()
	# Scale up from the base enlarged size
	tween.tween_property(direction_prompt, "scale", Vector2(2.4, 2.4), 0.1)  # 120% of base size
	tween.tween_property(direction_prompt, "scale", Vector2(2.0, 2.0), 0.1)  # Back to base size
	direction_prompt.modulate = Color(0, 1, 0, 1)  # Green tint
	await get_tree().create_timer(0.2).timeout
	direction_prompt.modulate = Color(1, 1, 1, 1)  # Reset to normal

func _animate_prompt_error():
	var original_pos = direction_prompt.position
	var tween = create_tween()
	
	# Shake effect
	for i in range(5):
		var offset = 5
		tween.tween_property(direction_prompt, "position:x", original_pos.x - offset, 0.05)
		tween.tween_property(direction_prompt, "position:x", original_pos.x + offset, 0.05)
	
	tween.tween_property(direction_prompt, "position:x", original_pos.x, 0.05)
	
	# Red tint flash
	direction_prompt.modulate = Color(1, 0.3, 0.3, 1)  # Red tint
	await get_tree().create_timer(0.4).timeout
	direction_prompt.modulate = Color(1, 1, 1, 1)  # Reset to normal

func _set_new_direction_prompt():
	# Choose a random direction
	current_prompt_direction = directions[randi() % directions.size()]
	
	# Update the direction prompt sprite with corresponding animation
	var animation_name = current_prompt_direction.substr(6)  # Remove 'battle' prefix
	
	# Play the corresponding animation
	if direction_prompt is AnimatedSprite2D and direction_prompt.sprite_frames.has_animation(animation_name):
		direction_prompt.play(animation_name)
	
	# Reset scale to our preferred larger size
	direction_prompt.scale = Vector2(2.0, 2.0)  # Keep it twice as big

func _open_attack_menu():
	attack_charging = false
	attack_menu_open = true
	
	# Hide direction prompt, show attack menu
	direction_prompt.visible = false
	
	# Play charged animation when attack menu is open
	_play_player_animation("charged")
	
	# Play charge sound when attack menu opens
	_play_effect_sound("charge")
	
	# Clear any existing buttons
	for child in attack_menu.get_children():
		if child.name != "MenuLabel":  # Keep the label
			child.queue_free()
	
	# Create attack buttons vertically using a different approach
	for i in range(5):
		var button = Button.new()
		button.text = player_attacks[i]
		button.name = "AttackButton" + str(i+1)
		
		# Set custom style for easy highlighting
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.4, 0.5, 1.0)  # Dark teal
		normal_style.set_corner_radius_all(4)
		# Add padding to the style for better text appearance
		normal_style.content_margin_top = 8
		normal_style.content_margin_bottom = 8
		normal_style.content_margin_left = 12
		normal_style.content_margin_right = 12
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.45, 0.55, 1.0)  # Slightly lighter
		hover_style.set_corner_radius_all(4)
		# Copy the same padding
		hover_style.content_margin_top = 8
		hover_style.content_margin_bottom = 8
		hover_style.content_margin_left = 12
		hover_style.content_margin_right = 12
		
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.3, 0.6, 0.8, 1.0)  # Highlight blue
		selected_style.set_corner_radius_all(4)
		# Copy the same padding
		selected_style.content_margin_top = 8
		selected_style.content_margin_bottom = 8
		selected_style.content_margin_left = 12
		selected_style.content_margin_right = 12
		
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		
		# Apply the custom font
		button.add_theme_font_override("font", CustomFont)
		
		# Set font size
		button.add_theme_font_size_override("font_size", 24)  # Adjust size as needed
		
		# Add to menu
		attack_menu.add_child(button)
		
		# Connect button press to attack function using an intermediate variable
		var attack_idx = i  # Store index in a variable to avoid lambda capture issues
		button.pressed.connect(func(): _execute_player_attack(attack_idx))
	
	# Force a full rebuild of the menu to ensure nodes are updated
	attack_menu.visible = true
	
	# Initialize selection after a short delay to ensure buttons are added
	selected_attack_index = 0
	call_deferred("_apply_selection_after_delay")

func _apply_selection_after_delay():
	# Wait two frames to ensure UI has updated
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Now apply initial selection
	_update_selected_attack()
	print("Selection applied after delay - index:", selected_attack_index)

func _update_selected_attack():
	print("Updating selected attack to index:", selected_attack_index)
	
	# First reset all buttons
	for i in range(5):
		var button_name = "AttackButton" + str(i+1)
		var button = attack_menu.get_node_or_null(button_name)
		if button:
			# Get the default style
			var style = button.get_theme_stylebox("normal")
			if style is StyleBoxFlat:
				style.bg_color = Color(0.2, 0.4, 0.5, 1.0)  # Reset to normal color
			
			# Reset text color
			button.add_theme_color_override("font_color", Color(1, 1, 1))
	
	# Now highlight the selected button
	var selected_button_name = "AttackButton" + str(selected_attack_index + 1)
	var selected_button = attack_menu.get_node_or_null(selected_button_name)
	
	if selected_button:
		# Apply selection style
		var style = selected_button.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			style.bg_color = Color(0.3, 0.6, 0.8, 1.0)  # Highlight blue
		
		# Make text yellow
		selected_button.add_theme_color_override("font_color", Color(1, 0.9, 0, 1))
		print("Highlighted button:", selected_button_name)
	else:
		print("ERROR: Button not found for highlighting:", selected_button_name)
		# Fall back to listing available buttons
		var children = attack_menu.get_children()
		print("Available buttons:", children.size())
		for child in children:
			print(" - ", child.name)

func _execute_player_attack(attack_index):
	print("Player preparing to use " + player_attacks[attack_index] + "!")
	
	# Show player speech bubble with attack name
	show_player_speech(player_attacks[attack_index])
	
	# Play attack animation
	_play_player_animation("attack")
	
	# Shake player during attack (mild shake)
	_shake_sprite(player_sprite, 3.0, 0.4, false)
	
	# Play attack sound
	_play_effect_sound("attack")
	
	# Wait 1 second before performing the attack
	await get_tree().create_timer(1.0).timeout
	
	print("Player used " + player_attacks[attack_index] + "!")
	
	# IMPORTANT: Cancel any pending enemy attacks immediately after player attack
	# This ensures that no queued attacks will happen
	if attack_timer.time_left > 0:
		attack_timer.stop()
		print("Stopped pending enemy attack")
	
	# Damage enemy
	if is_boss_battle:
		enemy_health -= 1
		
		# Play hit animation for enemy
		_play_enemy_animation("hit")
		
		# Play hit sound
		_play_effect_sound("hit")
		
		# Shake enemy violently (stronger shake for hit)
		_shake_sprite(enemy_sprite, 5.0, 0.7, true)
		
		# Also shake PlayerSprite2 if it exists
		var player_sprite2 = get_node_or_null("PlayerSprite2")
		if player_sprite2:
			_shake_sprite(player_sprite2, 5.0, 0.7, true)
		
		# Check if boss is defeated
		if enemy_health <= 0:
			# Boss defeated
			_handle_boss_defeat()
		else:
			# Boss took damage but still alive
			show_enemy_speech("You're stronger than I thought... but not strong enough!")
			
			# Continue battle
			attack_menu_open = false
			attack_charging = true
			direction_inputs_correct = 0
			player_attack_bar.value = 0
			
			# Show direction prompt again
			direction_prompt.visible = true
			attack_menu.visible = false
			
			# Set a new prompt
			_set_new_direction_prompt()
			
			# --- Start a new timer with a guaranteed 10-second delay ---
			print("Enemy stunned for 10 seconds after player attack")
			attack_timer.start(10.0)
	else:
		# Regular enemy - just defeat them
		enemy_health = 0
		
		# Play hit animation for enemy defeat
		_play_enemy_animation("hit")
		
		# Play hit sound
		_play_effect_sound("hit")
		
		# Shake enemy violently
		_shake_sprite(enemy_sprite, 5.0, 0.8, true)
		
		# Also shake PlayerSprite2 if it exists
		var player_sprite2 = get_node_or_null("PlayerSprite2")
		if player_sprite2:
			_shake_sprite(player_sprite2, 5.0, 0.8, true)
		
		# Show defeat message
		show_enemy_speech(enemy_defeat_messages[randi() % enemy_defeat_messages.size()])
		
		# End battle after a short delay
		await get_tree().create_timer(2.0).timeout
		end_battle_with_transition()

func _handle_boss_defeat():
	# Show boss defeat message
	show_enemy_speech(boss_defeat_messages[randi() % boss_defeat_messages.size()])
	
	# Play hit animation for boss defeat
	_play_enemy_animation("hit")
	
	# Wait for a moment before proceeding
	await get_tree().create_timer(2.0).timeout
	
	# Check if this was the final boss - add extra debug prints
	print("Boss defeated! is_final_boss flag =", is_final_boss)
	
	if is_final_boss:
		print("FINAL BOSS DEFEATED! Emitting signal final_boss_defeated...")
		
		# Add a dramatic pause/delay before emitting the final boss defeated signal
		# Increase this value to make the pause longer (5.0 = 5 seconds)
		await get_tree().create_timer(5.0).timeout
		
		# Signal that the final boss was defeated
		emit_signal("final_boss_defeated")
		
		# Additional delay before ending the battle
		await get_tree().create_timer(1.0).timeout
	else:
		# For regular bosses, just wait the standard amount of time
		await get_tree().create_timer(3.0).timeout
	
	# End battle with transition
	end_battle_with_transition()


func _on_enemy_attack_timer_timeout():
	# Choose attack name based on whether this is a boss battle
	var attack_name
	if is_boss_battle:
		attack_name = boss_attack_names[randi() % boss_attack_names.size()]
	else:
		attack_name = enemy_attack_names[randi() % enemy_attack_names.size()]
	
	print("Enemy preparing to use " + attack_name + "!")
	
	# Show speech bubble with attack name first
	show_enemy_speech(attack_name)
	
	# Play enemy attack animation
	_play_enemy_animation("attack")
	
	# Play attack sound
	_play_effect_sound("attack")
	
	# Shake enemy during attack (mild shake)
	_shake_sprite(enemy_sprite, 3.0, 0.4, false)
	
	# Also shake PlayerSprite2 if it exists
	var player_sprite2 = get_node_or_null("PlayerSprite2")
	if player_sprite2:
		_shake_sprite(player_sprite2, 3.0, 0.4, false)
	
	# Wait 1 second before performing the attack
	await get_tree().create_timer(1.0).timeout
	
	# Now perform the attack
	print("Enemy used " + attack_name + "!")
	
	# Wait a bit before shaking player (as if attack landed)
	await get_tree().create_timer(0.5).timeout
	
	# Play hit animation on player
	_play_player_animation("hit")
	
	# Play hit sound
	_play_effect_sound("hit")
	
	# Shake player violently (stronger shake for hit)
	_shake_sprite(player_sprite, 6.0, 0.8, true)
	
	# Explicitly force enemy back to idle after attack animation completes
	# Wait for a bit more than the attack animation would take
	await get_tree().create_timer(1.5).timeout
	
	# Force reset of enemy animation state
	print("Forcing enemy animation reset to idle")
	enemy_animation_state = "idle"
	
	# Reset all enemy sprites
	if is_instance_valid(enemy_sprite) and enemy_sprite is AnimatedSprite2D:
		if enemy_sprite.sprite_frames.has_animation("idle"):
			enemy_sprite.play("idle")
			print("Main enemy sprite reset to idle")
	
	# Also reset PlayerSprite2
	if player_sprite2 and player_sprite2 is AnimatedSprite2D:
		if player_sprite2.sprite_frames.has_animation("idle"):
			player_sprite2.play("idle")
			print("PlayerSprite2 reset to idle")
	
	# Disconnect any leftover connections
	if is_instance_valid(enemy_sprite) and enemy_sprite.is_connected("animation_finished", Callable(self, "_on_enemy_animation_finished")):
		enemy_sprite.animation_finished.disconnect(_on_enemy_animation_finished)
	
	# Start the timer for next attack
	_start_random_enemy_attack_timer()

# Updated speech handling using the new SpeechBubble class
func show_enemy_speech(text_content):
	if enemy_speech_bubble:
		enemy_speech_bubble.show_message(text_content)

func show_player_speech(text_content):
	if player_speech_bubble:
		player_speech_bubble.show_message(text_content)

func _start_random_enemy_attack_timer():
	# Only start a new timer if not already running
	if attack_timer.time_left <= 0:
		# Random time between 5-20 seconds for regular enemies
		# Shorter time (3-12 seconds) for boss battles
		var attack_delay
		if is_boss_battle:
			attack_delay = randf_range(3.0, 12.0)  # Boss attacks more frequently
		else:
			attack_delay = randf_range(5.0, 20.0)
			
		attack_timer.start(attack_delay)
		print("Enemy will attack in " + str(attack_delay) + " seconds")

func end_battle_with_transition():
	# Reset speed up counter
	speed_up_counter = 0
	if speed_up_label:
		speed_up_label.text = "Speed up the battle: 0/100 ¥ added"
	
	# Ensure GlobalUI remains visible before transition
	if global_ui_manager:
		global_ui_manager.ensure_global_ui_exists()
	
	# Hide any speech bubbles
	if enemy_speech_bubble:
		enemy_speech_bubble.hide_bubble()
	if player_speech_bubble:
		player_speech_bubble.hide_bubble()
	
	# Start the digital transition out
	_start_digital_transition_out()

# DIGITAL BLOCK TRANSITION EFFECT
# Creates a grid of colored blocks that fade in/out for a pixelated effect
func _start_digital_transition_in():
	print("Starting digital transition IN")
	
	# Start with black screen
	if transition_rect:
		transition_rect.visible = true
		transition_rect.material = null  # No shader
		transition_rect.color = Color(0, 0, 0, 1)
	
	# First fade to partially transparent
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.8, 0.4)
	await tween.finished
	
	# Get viewport size to position blocks across entire screen
	var viewport_size = get_viewport_rect().size
	
	# Create grid of digital blocks
	_create_digital_blocks(viewport_size, true)
	
	# Add a short delay
	await get_tree().create_timer(0.5).timeout
	
	# Final fade out to reveal battle scene
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.5)
	tween.finished.connect(func(): start_battle())

# Creates digital blocks for the transition effect
func _create_digital_blocks(viewport_size, is_intro):
	# Clear any existing blocks
	for block in transition_blocks:
		if is_instance_valid(block):
			block.queue_free()
	transition_blocks.clear()
	
	# Settings
	var block_count = 50  # Number of blocks to create
	var max_size = 60.0   # Maximum block size
	var min_size = 10.0   # Minimum block size
	
	# Create random blocks
	for i in range(block_count):
		var block = ColorRect.new()
		add_child(block)
		transition_blocks.append(block)
		
		# Random position and size
		var size = randf_range(min_size, max_size)
		block.size = Vector2(size, size)
		block.position = Vector2(
			randf_range(0, viewport_size.x - size),
			randf_range(0, viewport_size.y - size)
		)
		
		# Different colors for intro vs outro
		if is_intro:
			block.color = Color(
				randf_range(0.2, 0.9),
				randf_range(0.2, 0.9),
				randf_range(0.2, 0.9),
				0.0  # Start transparent
			)
		else:
			block.color = Color(
				randf_range(0.0, 0.5),
				randf_range(0.0, 0.5),
				randf_range(0.0, 0.5),
				0.0  # Start transparent
			)
		
		# Animate blocks
		var block_tween = create_tween()
		
		if is_intro:
			# For intro, fade in then out
			block_tween.tween_property(block, "color:a", randf_range(0.5, 0.9), randf_range(0.1, 0.5))
			block_tween.tween_property(block, "color:a", 0.0, randf_range(0.2, 0.7))
		else:
			# For outro, just fade in and stay
			block_tween.tween_property(block, "color:a", randf_range(0.5, 0.9), randf_range(0.1, 0.5))
		
		# Queue free at the end of animation if intro
		if is_intro:
			block_tween.tween_callback(func(): _remove_block(block))

# Helper to remove a block and clean up the array
func _remove_block(block):
	if is_instance_valid(block):
		block.queue_free()
		
	var index = transition_blocks.find(block)
	if index >= 0:
		transition_blocks.remove_at(index)

# Transition out of battle
func _start_digital_transition_out():
	print("Starting digital transition OUT")
	
	# Start with transparent overlay
	if transition_rect:
		transition_rect.visible = true
		transition_rect.material = null
		transition_rect.color = Color(0, 0, 0, 0)
	
	# First fade to partially visible
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.4, 0.3)
	await tween.finished
	
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
	# Create digital blocks for exit
	_create_digital_blocks(viewport_size, false)
	
	# Add a short delay
	await get_tree().create_timer(0.4).timeout
	
	# Final fade to black
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.7)
	
	# Switch to battle end when done
	tween.finished.connect(func(): 
		# Clean up any remaining blocks
		for block in transition_blocks:
			if is_instance_valid(block):
				block.queue_free()
		transition_blocks.clear()
		
		# End the battle
		_end_battle()
	)

func _end_battle():
	in_battle = false
	is_boss_battle = false
	current_boss = null
	
	# Reset battle UI state thoroughly
	attack_menu.visible = false
	direction_prompt.visible = false
	attack_menu_open = false
	attack_charging = false
	selected_attack_index = 0
	
	# Clear menu buttons
	for child in attack_menu.get_children():
		if child.name != "MenuLabel":
			child.queue_free()
	
	# Disable battle camera
	camera.enabled = false
	
	# Hide battle scene
	visible = false
	
	# Show all NPCs again
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = true
		
	# Reset boss battle flag in player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_boss_battle = false
	
	# Signal to the main game that battle is over
	emit_signal("battle_ended")
