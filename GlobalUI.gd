extends CanvasLayer

# UI elements
@onready var time_label = $PersistentUI/TimeLabel
@onready var yen_label = $PersistentUI/YenLabel
@onready var timer = $Timer

# State tracking
var time_saved_seconds = 0
var yen_spent = 0
var x_press_count = 0
var debug_counter = 0  # For debugging timer functionality

func _ready():
	print("GlobalUI: _ready() called")
	
	# Initialize time saved tracking
	print("GlobalUI: Time saved initialized to 0")
	
	# Check if UI elements exist
	if time_label:
		print("GlobalUI: TimeLabel found")
		time_label.text = "Time Saved: 00:00:00"
	else:
		print("ERROR: TimeLabel not found!")
		
	if yen_label:
		print("GlobalUI: YenLabel found")
		yen_label.text = "¥ 0 spent"
	else:
		print("ERROR: YenLabel not found!")
	
	# Ensure this UI stays on top
	layer = 100
	
	# Timer is no longer needed for time tracking, but keep it for debugging if needed
	if timer:
		print("GlobalUI: Timer found")
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
			print("GlobalUI: Timer timeout signal connected manually")
		timer.wait_time = 5.0  # Just for occasional debugging updates
		timer.start()
	else:
		print("ERROR: Timer node not found!")

func _process(delta):
	# Check for X key press
	if Input.is_action_just_pressed("add_move"):
		add_yen(25)
		add_time_saved()
		print("GlobalUI: X pressed, yen added and time saved")
	
	# Force time update every 5 seconds for debugging (less frequent now)
	debug_counter += delta
	if debug_counter >= 5.0:
		debug_counter = 0
		print("GlobalUI: 5 second debug update")
		print("GlobalUI: Current time saved: ", time_label.text)

func _on_timer_timeout():
	print("GlobalUI: Timer timeout called")
	print("GlobalUI: Current time saved: ", time_label.text)

# Add this new function to retrieve the current yen amount
func get_yen_spent():
	print("GlobalUI: get_yen_spent called, returning: ", yen_spent)
	return yen_spent

func add_time_saved():
	# Add a random amount of time between 5 and 35 seconds
	var random_seconds = randi_range(5, 35)
	time_saved_seconds += random_seconds
	update_time_display()
	
	print("GlobalUI: Added %d seconds to time saved (total: %d)" % [random_seconds, time_saved_seconds])
	
	# Add a small animation effect to the time label
	# This will start 0.05 seconds after the yen label animation
	var tween = create_tween()
	# Add a small delay before starting the animation
	tween.tween_interval(0.05)
	tween.tween_property(time_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(time_label, "scale", Vector2(1.0, 1.0), 0.1)

func update_time_display():
	# Format time as HH:MM:SS
	var total_seconds = time_saved_seconds
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var seconds = total_seconds % 60
	
	# Format time components
	var time_string = "%02d:%02d:%02d" % [hours, minutes, seconds]
	time_label.text = "Time Saved: " + time_string
	
	print("GlobalUI: Updated time saved display to: ", time_label.text)

func add_yen(amount: int):
	yen_spent += amount
	x_press_count += 1
	yen_label.text = "¥ %d spent" % yen_spent
	print("GlobalUI: Yen updated to ", yen_spent)
	
	# Add a small animation effect
	var tween = create_tween()
	tween.tween_property(yen_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(yen_label, "scale", Vector2(1.0, 1.0), 0.1)
