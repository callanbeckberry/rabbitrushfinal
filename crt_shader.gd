extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready():
	# Set layer to ensure it's on top of everything
	layer = 100
	
	# Make sure the ColorRect covers the entire viewport on start
	_update_color_rect_size()
	
	# Connect to the window resize signal to adjust when viewport changes
	get_tree().root.size_changed.connect(_update_color_rect_size)
	
	# Update the shader screen_size parameter
	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("screen_size", get_viewport().size)

func _update_color_rect_size():
	# Get the current viewport size
	var viewport_size = get_viewport().size
	
	# Update ColorRect size to match viewport
	color_rect.size = viewport_size
	
	# Ensure anchors are set to cover the full rect
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.offset_right = 0
	color_rect.offset_bottom = 0
	
	# Update the shader's screen_size parameter
	if color_rect.material is ShaderMaterial:
		color_rect.material.set_shader_parameter("screen_size", viewport_size)
		
	print("CRT Effect updated to viewport size: ", viewport_size)

# Add this function to ensure the effect works with camera movement
func _process(_delta):
	# This ensures the effect stays at the correct layer as the game updates
	layer = 150
