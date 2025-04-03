extends NPC
class_name FinalBossNPC

# Final boss specific properties
@export_multiline var pre_complete_dialogues: Array[String] = [
	"You are not yet ready to face me...",
	"Collect all 100 coins and return.",
	"Your journey is incomplete, mortal."
]
@export_multiline var post_complete_dialogues: Array[String] = [
	"So, you've collected all the coins...",
	"Very well. Prepare yourself for battle!",
	"Let us see if you are truly worthy!"
]

var is_final_boss = true  # This is correctly set
var player_ref = null
var dialogue_index = 0
var required_coins = 1

# Override _ready to add to boss group
func _ready():
	super._ready()  # Call parent _ready
	add_to_group("boss")
	print("Final Boss NPC initialized")

# Override show_dialogue to check coin count
func show_dialogue():
	# Update dialogues based on coin count
	update_dialogues_based_on_coins()
	
	# Continue with regular dialogue display from parent script
	super.show_dialogue()

# Check coins and update dialogues
func update_dialogues_based_on_coins():
	# Find player if we don't have a reference
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
	
	# Update dialogues based on coins
	if player_ref and player_ref.coins >= required_coins:
		# Player has collected all coins - use post-complete dialogues
		dialogues = post_complete_dialogues.duplicate()
		print("Final Boss: Using post-completion dialogues")
	else:
		# Player hasn't collected all coins - use pre-complete dialogues
		dialogues = pre_complete_dialogues.duplicate()
		print("Final Boss: Using pre-completion dialogues. Player has", 
			  player_ref.coins if player_ref else 0, "/", required_coins, "coins")

# Override dialogue hidden callback - FIXED FUNCTION NAME
func _on_dialogue_hidden():
	# Call parent method first
	super._on_dialogue_hidden()
	
	# Check if we should start boss battle
	if player_ref and player_ref.coins >= required_coins:
		# Start battle immediately after first dialogue
		print("Final Boss: Starting boss battle!")
		call_deferred("start_boss_battle")
		dialogue_index = 0  # Reset for next time
	else:
		# Reset dialogue index if conditions aren't met
		dialogue_index = 0

# Function to start boss battle
func start_boss_battle():
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("start_battle"):
		# Call start_battle with the boss parameter set to true
		player.start_battle(true)
	
	# Find battle scene
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	if battle_scene and battle_scene.has_method("start_boss_battle"):
		# Call special boss battle method with self as parameter
		battle_scene.start_boss_battle(self)
		print("Boss battle started with", battle_scene.name)
		
		# Call special boss battle method with self as parameter
		battle_scene.start_boss_battle(self)
		print("Boss battle started with", battle_scene.name)
	elif battle_scene:
		# Fall back to regular battle if no special method
		battle_scene.start_battle_with_transition()
		print("Regular battle started - boss battle method not found")
	else:
		print("ERROR: Couldn't find battle scene for boss battle!")
		
	# Disable dialogue for a while after starting battle
	dialogue_cooldown = true
	await get_tree().create_timer(5.0).timeout
	dialogue_cooldown = false
