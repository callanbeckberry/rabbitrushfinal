extends Sprite2D
var player = null
var battle_scene = null

func _ready():
	# Find and connect to the player
	call_deferred("_find_and_connect_player")
	call_deferred("_find_and_connect_battle_scene")

func _find_and_connect_player():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Try to find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("UIBackground connected to player: ", player.name)
		
		# Connect to player's battle signals
		if not player.is_connected("battle_started", _on_battle_started):
			player.connect("battle_started", _on_battle_started)
		if not player.is_connected("battle_ended", _on_battle_ended):
			player.connect("battle_ended", _on_battle_ended)
	else:
		push_warning("UIBackground could not find a player node in the 'player' group.")
		# Try again in a moment
		await get_tree().create_timer(1.0).timeout
		_find_and_connect_player()

func _find_and_connect_battle_scene():
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Try to find the battle scene in the scene
	var battle_scenes = get_tree().get_nodes_in_group("battle_scene")
	if battle_scenes.size() > 0:
		battle_scene = battle_scenes[0]
		print("UIBackground connected to battle scene: ", battle_scene.name)
		
		# Connect directly to battle scene's signals
		if battle_scene.has_signal("battle_started") and not battle_scene.is_connected("battle_started", _on_battle_started):
			battle_scene.connect("battle_started", _on_battle_started)
		if battle_scene.has_signal("battle_ended") and not battle_scene.is_connected("battle_ended", _on_battle_ended):
			battle_scene.connect("battle_ended", _on_battle_ended)
	else:
		push_warning("UIBackground could not find a battle scene node in the 'battle_scene' group.")
		# Try again in a moment
		await get_tree().create_timer(1.0).timeout
		_find_and_connect_battle_scene()

func _on_battle_started():
	print("UIBackground explicitly hiding for ALL battles")
	visible = false

func _on_battle_ended():
	print("UIBackground showing after battle")
	visible = true
