extends Node2D

# Q-Learning Demo scene path
const QLEARNING_DEMO_SCENE = "res://tests/QLearningDemo.tscn"

func _ready():
	# Initialize performance systems
	var pool_manager = null
	
	# Check if available as singleton
	if Engine.has_singleton("ObjectPoolManager"):
		print("Found ObjectPoolManager as Engine singleton")
		pool_manager = Engine.get_singleton("ObjectPoolManager")
	# Check if available as autoload
	elif has_node("/root/ObjectPoolManager"):
		print("Found ObjectPoolManager as autoload at /root")
		pool_manager = get_node("/root/ObjectPoolManager")
	# Try to find by class name
	else:
		var potential_managers = get_tree().get_nodes_in_group("object_pool_managers")
		if potential_managers.size() > 0:
			print("Found ObjectPoolManager in object_pool_managers group")
			pool_manager = potential_managers[0]
	
	# Initialize pools if manager was found
	if pool_manager != null:
		if pool_manager.has_method("initialize_common_pools"):
			pool_manager.initialize_common_pools()
			print("Successfully initialized object pools")
		else:
			push_error("ObjectPoolManager found but missing initialize_common_pools() method")
	else:
		push_error("ObjectPoolManager not found. Performance may be affected. Check project settings and autoloads.")
	
	# Add LOD manager to scene if needed (currently commented out as per original instruction's implication)
	# var lod_manager = LODManager.new() # Assuming LODManager is a class_name or has a .new()
	# add_child(lod_manager)
	# print("LODManager added to Main scene.")
	
	# Set up the Q-Learning Demo button in UI
	setup_demo_button()

# Setup the Q-Learning Demo button in the UI
func setup_demo_button():
	# Wait one frame to ensure UI is fully loaded
	await get_tree().process_frame
	
	if has_node("UI"):
		var ui = get_node("UI")
		var button = Button.new()
		button.text = "Q-Learning Demo"
		button.custom_minimum_size = Vector2(200, 50)
		
		# Style the button
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.2, 0.3, 0.8)
		normal_style.corner_radius_top_left = 5
		normal_style.corner_radius_top_right = 5
		normal_style.corner_radius_bottom_left = 5
		normal_style.corner_radius_bottom_right = 5
		button.add_theme_stylebox_override("normal", normal_style)
		
		# Position the button
		button.position = Vector2(20, 100)
		
		# Connect the button signal
		button.pressed.connect(launch_qlearning_demo)
		
		# Add to UI
		ui.add_child(button)
		print("Q-Learning Demo button added to UI")

# Launch the Q-Learning Demo scene
func launch_qlearning_demo():
	print("Launching Q-Learning Demo...")
	get_tree().change_scene_to_file(QLEARNING_DEMO_SCENE)
