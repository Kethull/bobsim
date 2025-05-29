extends Node2D
class_name QLearningDemo

# Q-Learning Demo Scene Controller
# Demonstrates Q-learning for probes in different learning stages

# Demo parameters
@export var time_scale: float = 1.0
@export var initial_camera_zoom: float = 0.5

# Probe configurations for different learning stages
@export var probe_configs = [
	{"name": "Novice", "epsilon": 1.0, "epsilon_decay": 0.0005, "q_table_size": 0, "color": Color(1.0, 0.3, 0.3, 1.0)},
	{"name": "Learning", "epsilon": 0.5, "epsilon_decay": 0.0005, "q_table_size": 50, "color": Color(1.0, 0.8, 0.2, 1.0)},
	{"name": "Expert", "epsilon": 0.1, "epsilon_decay": 0.0001, "q_table_size": 200, "color": Color(0.3, 1.0, 0.3, 1.0)},
	{"name": "Master", "epsilon": 0.01, "epsilon_decay": 0.0, "q_table_size": 500, "color": Color(0.3, 0.5, 1.0, 1.0)}
]

# Reference to key nodes
@onready var camera = $Camera2D
@onready var ui_layer = $UILayer
@onready var info_panel = $UILayer/InfoPanel
@onready var time_control_panel = $UILayer/TimeControlPanel
@onready var probe_container = $ProbeContainer
@onready var resource_container = $ResourceContainer
@onready var star_background = $StarBackground

# Tracking variables
var current_time_scale: float = 1.0
var demo_time: float = 0.0
var demo_running: bool = true
var probes = []
var resources = []
var camera_target = null
var selected_probe_index = -1

# Called when the node enters the scene tree for the first time
func _ready():
	# Set up initial time scale
	current_time_scale = time_scale
	Engine.time_scale = current_time_scale
	
	# Setup UI connections
	setup_ui_controls()
	
	# Setup background
	generate_star_background()
	
	# Create initial environment
	setup_environment()
	
	# Set initial camera position and zoom
	camera.zoom = Vector2(initial_camera_zoom, initial_camera_zoom)
	camera.position = Vector2.ZERO
	
	# Update UI with initial info
	update_info_panel()

# Called every frame
func _process(delta):
	if demo_running:
		demo_time += delta
		
		# Update info panel periodically
		if int(demo_time * 10) % 10 == 0:
			update_info_panel()
		
		# Follow camera target if set
		if camera_target and is_instance_valid(camera_target):
			camera.global_position = lerp(camera.global_position, camera_target.global_position, 0.1)

# Setup UI controls and connections
func setup_ui_controls():
	# Connect time control buttons
	$UILayer/TimeControlPanel/VBoxContainer/HBoxContainer/PauseButton.pressed.connect(_on_pause_button_pressed)
	$UILayer/TimeControlPanel/VBoxContainer/HBoxContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$UILayer/TimeControlPanel/VBoxContainer/HBoxContainer/FastButton.pressed.connect(_on_fast_button_pressed)
	$UILayer/TimeControlPanel/VBoxContainer/HBoxContainer/ResetButton.pressed.connect(_on_reset_button_pressed)
	
	# Connect probe selector buttons
	for i in range(probe_configs.size()):
		var button = $UILayer/ProbeSelector/VBoxContainer/HBoxContainer.get_child(i)
		if button is Button:
			button.pressed.connect(_on_probe_selected.bind(i))

# Generate star background
func generate_star_background():
	var star_count = 200
	var viewport_size = get_viewport_rect().size * 4  # Extend beyond visible area
	
	for i in range(star_count):
		var star = Sprite2D.new()
		star.texture = create_star_texture(randf_range(1, 3), Color(1, 1, 1, randf_range(0.3, 1.0)))
		star.position = Vector2(
			randf_range(-viewport_size.x/2, viewport_size.x/2),
			randf_range(-viewport_size.y/2, viewport_size.y/2)
		)
		star_background.add_child(star)

# Create star texture
func create_star_texture(radius: float, color: Color) -> Texture2D:
	var image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	
	return ImageTexture.create_from_image(image)

# Setup the demonstration environment with probes and resources
func setup_environment():
	# Clear existing entities
	for child in probe_container.get_children():
		child.queue_free()
	
	for child in resource_container.get_children():
		child.queue_free()
	
	probes.clear()
	resources.clear()
	
	# Create resources at strategic positions
	create_resources()
	
	# Create probes with different learning stages
	create_probes()

# Create probes with different learning configurations
func create_probes():
	var probe_scene = load("res://probes/Probe.tscn")
	var spacing = 150.0
	
	for i in range(probe_configs.size()):
		var config = probe_configs[i]
		var probe = probe_scene.instantiate()
		
		# Position probes in a horizontal line
		probe.position = Vector2(i * spacing - (probe_configs.size() - 1) * spacing / 2, 0)
		
		# Set probe name and color
		probe.name = "Probe_" + config.name
		probe.get_node("VisualComponent/HullSprite").modulate = config.color
		
		# Configure Q-learning parameters
		var ai_agent = probe.get_node("AIAgent")
		ai_agent.q_learning.epsilon = config.epsilon
		ai_agent.q_learning.epsilon_decay = config.epsilon_decay
		
		# Populate Q-table with some entries for more experienced probes
		if config.q_table_size > 0:
			populate_qtable(ai_agent.q_learning, config.q_table_size)
		
		# Enable debug visualization
		var visualizer = ai_agent.get_node("AIDebugVisualizer")
		visualizer.enabled = true
		
		# Add label to identify the probe
		var label = Label.new()
		label.text = config.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-50, -40)
		label.custom_minimum_size = Vector2(100, 20)
		label.add_theme_color_override("font_color", config.color)
		probe.add_child(label)
		
		probe_container.add_child(probe)
		probes.append(probe)
		
		# Initialize AI agent
		ai_agent.initialize(probe)

# Create strategic resources placement
func create_resources():
	var resource_scene = load("res://resources/Resource.tscn")
	
	# Create resource clusters at different distances
	var resource_configs = [
		# Close resources - easy to find
		{"position": Vector2(-300, -200), "amount": 15000, "color": Color(0.2, 0.8, 0.2)},
		{"position": Vector2(300, -200), "amount": 15000, "color": Color(0.2, 0.8, 0.2)},
		
		# Medium distance resources
		{"position": Vector2(-500, 200), "amount": 25000, "color": Color(0.2, 0.8, 0.8)},
		{"position": Vector2(500, 200), "amount": 25000, "color": Color(0.2, 0.8, 0.8)},
		
		# Far resources - harder to find but more valuable
		{"position": Vector2(-800, -400), "amount": 40000, "color": Color(0.8, 0.2, 0.8)},
		{"position": Vector2(800, 400), "amount": 40000, "color": Color(0.8, 0.2, 0.8)},
	]
	
	for config in resource_configs:
		var resource = resource_scene.instantiate()
		resource.position = config.position
		resource.resource_amount = config.amount
		resource.get_node("ResourceSprite").modulate = config.color
		resource_container.add_child(resource)
		resources.append(resource)

# Populate Q-table with some initial values for non-novice probes
func populate_qtable(q_learning: SimpleQLearning, size: int):
	# Create some basic state representations
	var states = []
	for i in range(size):
		var pos_x = int(randf_range(-10, 10)) * 100
		var pos_y = int(randf_range(-10, 10)) * 100
		var energy = int(randf_range(0, 10))
		var mining = "M" if randf() > 0.7 else "N"
		var resource = str(int(randf_range(0, 10))) + "_" + str(int(randf_range(0, 10)))
		
		var state = str(pos_x) + "," + str(pos_y) + "_" + str(energy) + "_" + mining + "_" + resource
		states.append(state)
	
	# Initialize Q-table for these states
	for state in states:
		if not q_learning.q_table.has(state):
			q_learning.initialize_state(state)
			
			# For more experienced probes, add some "learned" values
			if q_learning.epsilon < 0.5:
				# Assign better values to actions that move toward resources
				var action_count = q_learning.action_space_size
				for i in range(action_count):
					# Add some reasonable values that favor resource-seeking behavior
					q_learning.q_table[state][i] = randf_range(0, 0.5)
					
					# Thrust actions get slightly better values
					if i % 4 < 2:  # Basic thrust actions
						q_learning.q_table[state][i] += randf_range(0, 0.3)

# Update the information panel with current stats
func update_info_panel():
	if info_panel:
		var info_text = "Q-Learning Demonstration\n\n"
		info_text += "Demo Time: %.1f seconds\n" % demo_time
		info_text += "Time Scale: %.1fx\n\n" % current_time_scale
		
		info_text += "PROBE STATISTICS:\n"
		for i in range(probes.size()):
			if is_instance_valid(probes[i]) and probes[i].is_alive:
				var probe = probes[i]
				var ai = probe.get_node("AIAgent")
				var stats = ai.q_learning.get_debug_stats()
				
				info_text += "\n[" + probe_configs[i].name + "]\n"
				info_text += "ε: %.3f | " % stats.epsilon
				info_text += "Q-States: %d\n" % stats.q_table_size
				info_text += "Explore/Exploit: %d/%d\n" % [stats.explorations, stats.exploitations]
				info_text += "Reward: %.1f\n" % stats.episode_rewards
		
		$UILayer/InfoPanel/VBoxContainer/InfoLabel.text = info_text

# Button event handlers
func _on_pause_button_pressed():
	current_time_scale = 0.0
	Engine.time_scale = current_time_scale
	demo_running = false
	update_info_panel()

func _on_play_button_pressed():
	current_time_scale = 1.0
	Engine.time_scale = current_time_scale
	demo_running = true
	update_info_panel()

func _on_fast_button_pressed():
	current_time_scale = 3.0
	Engine.time_scale = current_time_scale
	demo_running = true
	update_info_panel()

func _on_reset_button_pressed():
	# Reset to initial state
	demo_time = 0.0
	demo_running = true
	current_time_scale = 1.0
	Engine.time_scale = current_time_scale
	
	# Recreate environment
	setup_environment()
	
	# Reset camera
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(initial_camera_zoom, initial_camera_zoom)
	camera_target = null
	selected_probe_index = -1
	
	update_info_panel()

func _on_probe_selected(index: int):
	if index >= 0 and index < probes.size() and is_instance_valid(probes[index]):
		camera_target = probes[index]
		selected_probe_index = index
		
		# Show visual indicator of selection
		for i in range(probes.size()):
			if is_instance_valid(probes[i]):
				var outline = probes[i].get_node_or_null("SelectionOutline")
				if outline:
					outline.visible = (i == index)
				elif i == index:
					# Create outline if it doesn't exist
					var new_outline = Sprite2D.new()
					new_outline.name = "SelectionOutline"
					new_outline.texture = probes[i].get_node("VisualComponent/HullSprite").texture
					new_outline.scale = Vector2(0.6, 0.6)  # Slightly larger than the hull
					new_outline.modulate = Color(1, 1, 1, 0.5)
					probes[i].add_child(new_outline)

# Input handling for camera control
func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_SPACE:
					# Toggle pause/play
					if demo_running:
						_on_pause_button_pressed()
					else:
						_on_play_button_pressed()
				KEY_R:
					# Reset demo
					_on_reset_button_pressed()
				KEY_1, KEY_2, KEY_3, KEY_4:
					# Select probe 1-4
					var index = event.keycode - KEY_1
					if index < probes.size():
						_on_probe_selected(index)
				KEY_ESCAPE:
					# Deselect probe
					camera_target = null
					selected_probe_index = -1
	
	elif event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					# Zoom in
					camera.zoom *= 1.1
				MOUSE_BUTTON_WHEEL_DOWN:
					# Zoom out
					camera.zoom /= 1.1