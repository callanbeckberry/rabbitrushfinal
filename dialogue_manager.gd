extends CanvasLayer

class_name DialogueManager

# Node references - updated for HBoxContainer structure
@onready var dialogue_box = $DialogueBox
@onready var portrait = $DialogueBox/HBoxContainer/Portrait
@onready var name_label = $DialogueBox/NameLabel
@onready var dialogue_text = $DialogueBox/HBoxContainer/VBoxContainer/DialogueText
@onready var timer = $Timer
@onready var typing_timer = $TypingTimer

# Variables
var is_dialogue_active = false
var can_advance = false
var current_npc = null
var current_tween = null

# Typing effect variables
var full_text = ""
var displayed_text = ""
var text_animation_timer = 0.0
var text_animation_speed = 0.03  # Seconds per character
var is_text_animating = false
var current_char_index = 0

# Add signal for when dialogue is hidden
signal dialogue_hidden
signal dialogue_shown

# Called when the node enters the scene tree for the first time
func _ready():
	print("DialogueManager: Ready")
	
	# Check if nodes exist
	if not dialogue_box:
		push_error("DialogueManager: DialogueBox node not found!")
		print("ERROR: DialogueBox node not found!")
		return
	else:
		print("DialogueBox found successfully")
	
	# Check if dialogue_text exists with the new path
	if not dialogue_text:
		push_error("DialogueManager: DialogueText node not found at new path!")
		print("ERROR: DialogueText node not found at: $DialogueBox/HBoxContainer/VBoxContainer/DialogueText")
		print("Current scene tree structure:")
		print_scene_tree()
		return
	else:
		print("DialogueText found successfully at: " + str(dialogue_text.get_path()))
	
	# Position the dialogue box at the bottom of the screen
	reposition_dialogue_box()
		
	# Hide dialogue elements on start
	dialogue_box.visible = false
	dialogue_box.modulate = Color(1, 1, 1, 0)
	
	# Connect the timer for dialogue advancement
	if timer:
		timer.timeout.connect(_on_timer_timeout)
		print("Timer connected successfully")
	else:
		push_error("DialogueManager: Timer node not found!")
		print("ERROR: Timer node not found!")
	
	# Connect typing timer
	if typing_timer:
		typing_timer.timeout.connect(_on_typing_timer_timeout)
		print("Typing timer connected successfully")
	else:
		push_error("DialogueManager: TypingTimer node not found!")
		print("ERROR: TypingTimer node not found!")
	
	# Add to dialogue_manager group for easy finding
	add_to_group("dialogue_manager")
	print("Added to dialogue_manager group")

# Helper function to print the scene tree structure for debugging
func print_scene_tree(node = null, indent = 0):
	if node == null:
		node = self
		print("Scene tree structure:")
	
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		print_scene_tree(child, indent + 1)

func _process(delta):
	# Handle text animation for dialogue text
	if is_text_animating:
		text_animation_timer += delta
		
		if text_animation_timer >= text_animation_speed:
			text_animation_timer = 0
			
			if displayed_text.length() < full_text.length():
				# Add next character
				displayed_text += full_text[displayed_text.length()]
				
				# Update displayed text
				dialogue_text.text = displayed_text  # Changed from dialogue_text_label to dialogue_text
				
				# Play the speech sound for the current NPC
				if current_npc and current_npc.has_method("play_speech_sound"):
					current_npc.play_speech_sound()

# Position the dialogue box at the bottom of the screen
func reposition_dialogue_box():
	if dialogue_box:
		# Get viewport size
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Position at bottom of screen with some padding
		var padding = 20
		var dialogue_box_size = dialogue_box.size
		dialogue_box.position = Vector2(
			(viewport_size.x - dialogue_box_size.x) / 2,  # Center horizontally
			viewport_size.y - dialogue_box_size.y - padding  # Bottom with padding
		)
		
		print("Repositioned dialogue box to: " + str(dialogue_box.position))

# Show the dialogue box with NPC information
func show_dialogue(npc_name, dialogue_text_str, portrait_texture = null, npc_ref = null):
	# Set current NPC reference for speech sounds
	current_npc = npc_ref
	
	# Show the dialogue panel
	dialogue_box.visible = true
	
	# Fade in the dialogue box
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# Set the dialogue text and start animation
	full_text = dialogue_text_str
	displayed_text = ""
	dialogue_text.text = ""
	is_text_animating = true
	text_animation_timer = 0.0
	
	# Set NPC name
	name_label.text = npc_name
	
	# Set portrait if available
	if portrait_texture and portrait:
		portrait.texture = portrait_texture
		portrait.visible = true
	else:
		if portrait:
			portrait.visible = false
	
	# Stop player movement if needed
	var player = get_player_node()
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)
	
	# Set dialogue as active
	is_dialogue_active = true
	
	# Emit signal
	emit_signal("dialogue_shown")

# Start the typing effect
func start_typing_effect():
	print("Starting typing effect")
	current_char_index = 0
	
	if typing_timer:
		typing_timer.wait_time = text_animation_speed
		typing_timer.start()
	else:
		print("WARNING: typing_timer is null, skipping typing effect")
		# Fall back to showing full text immediately
		if dialogue_text:
			dialogue_text.text = full_text
		timer.start(0.5)

# Skip to the end of typing
func skip_typing():
	print("Skipping typing effect")
	if typing_timer:
		typing_timer.stop()
	
	if dialogue_text:
		dialogue_text.text = full_text
	
	current_char_index = full_text.length()
	
	# Allow advancing dialogue
	if timer:
		timer.start(0.5)

func _input(event):
	# Skip if dialogue not active
	if not is_dialogue_active:
		return
	
	# When dialogue is showing and user presses space/interact
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
			if is_text_animating and displayed_text.length() < full_text.length():
				# Skip to the end of the text animation
				displayed_text = full_text
				dialogue_text.text = full_text
				is_text_animating = false
			else:
				# Close dialogue
				hide_dialogue()

# Called when typing timer times out
func _on_typing_timer_timeout():
	# Add one character at a time
	if current_char_index < full_text.length():
		current_char_index += 1
		
		if dialogue_text:
			dialogue_text.text = full_text.substr(0, current_char_index)
		
		# Play typing sound here if needed (via NPC)
		if current_npc and current_npc.has_method("play_speech_sound"):
			current_npc.play_speech_sound()
	else:
		# Typing is complete, stop timer
		typing_timer.stop()
		
		# Start timer to enable advancing dialogue
		if timer:
			timer.start(0.5)

# Hide the dialogue box
func hide_dialogue():
	# Fade out the dialogue box
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func(): dialogue_box.visible = false)
	
	is_text_animating = false
	is_dialogue_active = false
	current_npc = null  # Clear NPC reference
	
	# Enable player movement again
	var player = get_player_node()
	if player and player.has_method("set_can_move"):
		player.set_can_move(true)
	
	# Emit signal
	emit_signal("dialogue_hidden")

# Helper to get player node
func get_player_node():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

# Timer callback to enable dialogue advancement
func _on_timer_timeout():
	can_advance = true
	print("Timer timeout - dialogue can now be advanced")

# Function to customize the dialogue box appearance
func set_custom_appearance(background_texture: Texture2D = null, 
						   box_color: Color = Color(0.1, 0.1, 0.1, 0.9),
						   text_color: Color = Color.WHITE,
						   name_color: Color = Color(1, 0.9, 0.3)):
	# If a background texture is provided
	if background_texture and dialogue_box:
		# Convert Panel to NinePatchRect if needed
		if dialogue_box is Panel:
			print("Converting Panel to NinePatchRect for custom texture")
			# Get dialogue box position and size
			var panel_pos = dialogue_box.position
			var panel_size = dialogue_box.size
			
			# Create new NinePatchRect
			var nine_patch = NinePatchRect.new()
			nine_patch.name = "DialogueBox"
			nine_patch.position = panel_pos
			nine_patch.size = panel_size
			nine_patch.texture = background_texture
			
			# Set up margins for nine-patch
			nine_patch.patch_margin_left = 20
			nine_patch.patch_margin_top = 20
			nine_patch.patch_margin_right = 20
			nine_patch.patch_margin_bottom = 20
			
			# Transfer children from old dialogue_box to new one
			var children = dialogue_box.get_children()
			for child in children:
				dialogue_box.remove_child(child)
				nine_patch.add_child(child)
			
			# Replace the old dialogue_box
			var parent = dialogue_box.get_parent()
			parent.remove_child(dialogue_box)
			parent.add_child(nine_patch)
			
			# Update reference
			dialogue_box = nine_patch
			
			# Re-add to group
			add_to_group("dialogue_manager")
		else:
			# Already a TextureRect or NinePatchRect
			dialogue_box.texture = background_texture
	elif dialogue_box is Panel:
		# Just update color for Panel
		var style = StyleBoxFlat.new()
		style.bg_color = box_color
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		dialogue_box.add_theme_stylebox_override("panel", style)
	
	# Update text colors
	if dialogue_text:
		dialogue_text.add_theme_color_override("font_color", text_color)
	
	if name_label:
		name_label.add_theme_color_override("font_color", name_color)
