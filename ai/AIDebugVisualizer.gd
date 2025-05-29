# AIDebugVisualizer.gd
extends Node2D
class_name AIDebugVisualizer

# Configuration
@export var text_size: int = 24  # Increased from 12 to 24
@export var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # Pure white with full alpha
@export var good_reward_color: Color = Color(0.2, 1.0, 0.2, 1.0)  # Brighter green
@export var bad_reward_color: Color = Color(1.0, 0.2, 0.2, 1.0)  # Brighter red
@export var random_action_color: Color = Color(1.0, 0.8, 0.0, 1.0)  # Brighter yellow
@export var best_action_color: Color = Color(0.0, 1.0, 1.0, 1.0)  # Brighter cyan
@export var target_color: Color = Color(1.0, 0.0, 1.0, 1.0)  # Brighter magenta
@export var path_color: Color = Color(0.4, 0.6, 1.0, 1.0)  # Brighter blue
@export var highlight_color: Color = Color(1.0, 0.7, 0.0, 1.0)  # Orange highlight
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.7)  # Semi-transparent black
@export var max_path_points: int = 30  # Increased from 20 to 30
@export var log_frequency: int = 100  # Log to console every N steps
@export var enable_glow: bool = true  # Enable glow effect for better visibility

# Font for text display
var debug_font: Font
var enabled: bool = false
var visualizer_offset: Vector2 = Vector2(0, -100)  # Increased offset from probe
var metrics_position: Vector2 = Vector2(20, 20)  # Screen position for metrics
var hud_visible: bool = true  # Toggle for HUD visibility
var selected_probe: Probe = null  # Currently selected probe for camera focus
var glow_material: CanvasItemMaterial  # Material for glow effects

# References
var parent_agent: AIAgent
var parent_probe: Probe
var q_learning: SimpleQLearning

# Visualization components
var state_label: Label
var action_label: Label
var epsilon_label: Label
var reward_label: Label
var metrics_label: Label

# Visual indicators
var planned_path: Line2D
var reward_indicator: Node2D
var exploration_indicator: Sprite2D
var target_indicator: Sprite2D

# HUD elements
var hud_container: Control
var hud_panel: Panel
var epsilon_bar: ProgressBar
var qtable_chart: Control
var recent_rewards_chart: Control
var action_breakdown_chart: Control
var learning_phase_label: Label
var zoom_controls: Control
var focus_button: Button

# Debug data
var current_state_hash: String = ""
var current_action_index: int = 0
var current_action: Array = []
var is_random_action: bool = false
var last_reward: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var planned_path_points: Array[Vector2] = []
var metrics_data: Dictionary = {}
var log_step_counter: int = 0

# Tracking for advanced visualizations
var recent_rewards: Array[float] = []
var action_history: Dictionary = {}
var learning_phase: String = "Exploration"
var camera_target: Vector2 = Vector2.ZERO
var camera_zoom_level: float = 1.0

# Signals for logging events and camera control
signal ai_debug_log(message: String, level: String)
signal request_camera_focus(position: Vector2, zoom: float)
signal toggle_hud_visibility()

func _ready():
	# Initialize font
	debug_font = ThemeDB.fallback_font
	
	# Initialize glow material
	setup_glow_material()
	
	# Create visual components
	setup_visual_components()
	
	# Create HUD components
	setup_hud_components()
	
	# Initialize arrays
	for i in range(10):
		recent_rewards.append(0.0)
	
	# Check if debug visualization is enabled
	enabled = ConfigManager.config.ai_show_debug_visuals
	visible = enabled
	
	# Set process only if enabled
	set_process(enabled)
	set_physics_process(enabled)
	
	# Initialize input handling
	set_process_input(enabled)

func setup_glow_material():
	glow_material = CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	
func setup_visual_components():
	# Create labels for state information with background panels
	state_label = create_label("State: ", Vector2(0, -120))
	action_label = create_label("Action: ", Vector2(0, -90))
	epsilon_label = create_label("Epsilon: ", Vector2(0, -60))
	reward_label = create_label("Reward: ", Vector2(0, -30))
	
	# Add background panels to labels
	add_background_to_label(state_label)
	add_background_to_label(action_label)
	add_background_to_label(epsilon_label)
	add_background_to_label(reward_label)
	
	# Create metrics label (fixed to screen position) with background
	metrics_label = Label.new()
	metrics_label.add_theme_font_override("font", debug_font)
	metrics_label.add_theme_font_size_override("font_size", text_size)
	metrics_label.modulate = text_color
	metrics_label.text = "Q-Learning Metrics:"
	add_child(metrics_label)
	add_background_to_label(metrics_label)
	
	# Create path visualization with increased width
	planned_path = Line2D.new()
	planned_path.width = 4.0  # Increased from 2.0
	planned_path.default_color = path_color
	if enable_glow:
		planned_path.material = glow_material
	add_child(planned_path)
	
	# Create exploration/exploitation indicator (larger)
	exploration_indicator = Sprite2D.new()
	exploration_indicator.texture = create_circle_texture(16, Color.WHITE)  # Increased from 8
	exploration_indicator.position = Vector2(60, -90)  # Adjusted position
	if enable_glow:
		exploration_indicator.material = glow_material
	add_child(exploration_indicator)
	
	# Create reward indicator
	reward_indicator = Node2D.new()
	add_child(reward_indicator)
	
	# Create target indicator (larger with glow)
	target_indicator = Sprite2D.new()
	target_indicator.texture = create_circle_texture(20, target_color)  # Increased from 10
	target_indicator.visible = false
	if enable_glow:
		target_indicator.material = glow_material
	add_child(target_indicator)

func add_background_to_label(label: Label):
	# Create a panel as background for better visibility
	var panel = Panel.new()
	panel.show_behind_parent = true
	panel.size = Vector2(label.size.x + 20, label.size.y + 10)
	panel.position = Vector2(-10, -5)
	panel.modulate = background_color
	label.add_child(panel)
	
	# Ensure label is on top
	label.z_index = 1
	
func setup_hud_components():
	# Create main HUD container (fixed to screen)
	hud_container = Control.new()
	hud_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hud_container)
	
	# Create HUD panel
	hud_panel = Panel.new()
	hud_panel.size = Vector2(300, 500)
	hud_panel.position = Vector2(20, 120) # Position below metrics
	hud_panel.modulate = Color(0.1, 0.1, 0.2, 0.8) # Semi-transparent dark blue
	hud_container.add_child(hud_panel)
	
	# Add title
	var title = Label.new()
	title.text = "Q-LEARNING MONITOR"
	title.add_theme_font_override("font", debug_font)
	title.add_theme_font_size_override("font_size", text_size)
	title.modulate = highlight_color
	title.position = Vector2(10, 10)
	hud_panel.add_child(title)
	
	# Add epsilon progress bar
	var epsilon_label = Label.new()
	epsilon_label.text = "Exploration (ε):"
	epsilon_label.add_theme_font_override("font", debug_font)
	epsilon_label.add_theme_font_size_override("font_size", text_size * 0.75)
	epsilon_label.position = Vector2(10, 50)
	hud_panel.add_child(epsilon_label)
	
	epsilon_bar = ProgressBar.new()
	epsilon_bar.min_value = 0
	epsilon_bar.max_value = 100
	epsilon_bar.position = Vector2(10, 80)
	epsilon_bar.size = Vector2(280, 30)
	hud_panel.add_child(epsilon_bar)
	
	# Add learning phase indicator
	learning_phase_label = Label.new()
	learning_phase_label.text = "Phase: Exploration"
	learning_phase_label.add_theme_font_override("font", debug_font)
	learning_phase_label.add_theme_font_size_override("font_size", text_size * 0.75)
	learning_phase_label.position = Vector2(10, 120)
	learning_phase_label.modulate = random_action_color
	hud_panel.add_child(learning_phase_label)
	
	# Add Q-table growth indicator
	var qtable_label = Label.new()
	qtable_label.text = "Q-Table Size:"
	qtable_label.add_theme_font_override("font", debug_font)
	qtable_label.add_theme_font_size_override("font_size", text_size * 0.75)
	qtable_label.position = Vector2(10, 160)
	hud_panel.add_child(qtable_label)
	
	qtable_chart = create_chart(Vector2(10, 190), Vector2(280, 60))
	hud_panel.add_child(qtable_chart)
	
	# Add recent rewards chart
	var rewards_label = Label.new()
	rewards_label.text = "Recent Rewards:"
	rewards_label.add_theme_font_override("font", debug_font)
	rewards_label.add_theme_font_size_override("font_size", text_size * 0.75)
	rewards_label.position = Vector2(10, 260)
	hud_panel.add_child(rewards_label)
	
	recent_rewards_chart = create_chart(Vector2(10, 290), Vector2(280, 60))
	hud_panel.add_child(recent_rewards_chart)
	
	# Add zoom controls
	zoom_controls = Control.new()
	zoom_controls.position = Vector2(10, 370)
	hud_panel.add_child(zoom_controls)
	
	var zoom_label = Label.new()
	zoom_label.text = "Camera Controls:"
	zoom_label.add_theme_font_override("font", debug_font)
	zoom_label.add_theme_font_size_override("font_size", text_size * 0.75)
	zoom_controls.add_child(zoom_label)
	
	focus_button = Button.new()
	focus_button.text = "Focus Camera"
	focus_button.position = Vector2(0, 30)
	focus_button.size = Vector2(280, 40)
	focus_button.pressed.connect(_on_focus_button_pressed)
	zoom_controls.add_child(focus_button)
	
	var help_label = Label.new()
	help_label.text = "Shortcuts: +/- to zoom, H to toggle HUD"
	help_label.add_theme_font_override("font", debug_font)
	help_label.add_theme_font_size_override("font_size", text_size * 0.6)
	help_label.position = Vector2(0, 80)
	zoom_controls.add_child(help_label)

func create_chart(position: Vector2, size: Vector2) -> Control:
	var chart = Control.new()
	chart.position = position
	chart.size = size
	
	# Add background
	var bg = ColorRect.new()
	bg.size = size
	bg.color = Color(0.1, 0.1, 0.1, 0.5)
	chart.add_child(bg)
	
	return chart

func create_label(initial_text: String, offset: Vector2) -> Label:
	var label = Label.new()
	label.add_theme_font_override("font", debug_font)
	label.add_theme_font_size_override("font_size", text_size)
	label.modulate = text_color
	label.text = initial_text
	label.position = offset
	
	# Make label outline for better visibility
	if enable_glow:
		var shadow = Label.new()
		shadow.add_theme_font_override("font", debug_font)
		shadow.add_theme_font_size_override("font_size", text_size)
		shadow.modulate = Color(0, 0, 0, 0.7)
		shadow.text = initial_text
		shadow.position = Vector2(2, 2)
		shadow.z_index = -1
		label.add_child(shadow)
	
	add_child(label)
	return label

func create_circle_texture(radius: int, color: Color) -> Texture2D:
	var image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	# Draw a circle with outline
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				image.set_pixel(x, y, color)
			elif dist <= radius + 2 and dist > radius:  # 2-pixel outline
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.5))
	
	return ImageTexture.create_from_image(image)

func initialize(agent: AIAgent, probe: Probe):
	parent_agent = agent
	parent_probe = probe
	q_learning = agent.q_learning
	
	# Connect to agent signals
	parent_agent.action_received.connect(_on_action_received)
	parent_agent.reward_calculated.connect(_on_reward_calculated)
	
	log_debug("AIDebugVisualizer initialized", "info")

func _input(event):
	if not enabled:
		return
		
	# Keyboard shortcuts for camera control
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:  # + key
				camera_zoom_level = max(0.2, camera_zoom_level - 0.1)
				request_camera_focus.emit(camera_target, camera_zoom_level)
			elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:  # - key
				camera_zoom_level = min(2.0, camera_zoom_level + 0.1)
				request_camera_focus.emit(camera_target, camera_zoom_level)
			elif event.keycode == KEY_H:  # H key to toggle HUD
				hud_visible = !hud_visible
				if hud_container:
					hud_container.visible = hud_visible
				toggle_hud_visibility.emit()

func _process(delta):
	if not enabled:
		return
		
	if not parent_probe or not parent_probe.is_alive:
		# If probe is not available or is dead, only update HUD
		if hud_container and hud_container.visible:
			update_hud_components()
		return
	
	# Update label positions to follow probe with offset
	update_label_positions()
	
	# Update metrics label position (fixed to screen)
	metrics_label.global_position = metrics_position
	
	# Update visualization components
	update_exploration_indicator()
	update_reward_indicator()
	update_target_indicator()
	
	# Update HUD components
	if hud_container and hud_container.visible:
		update_hud_components()
	
	# Update metrics text periodically
	log_step_counter += 1
	if log_step_counter % 5 == 0:  # Update visuals more frequently (5 frames)
		update_metrics_display()
		
	# Store camera target position (probe position)
	camera_target = parent_probe.global_position

func _physics_process(delta):
	if not enabled or not parent_probe or not parent_probe.is_alive:
		return
	
	# Update planned path visualization
	update_planned_path()

func update_label_positions():
	# Position labels relative to probe
	if parent_probe:
		var base_pos = parent_probe.global_position + visualizer_offset
		state_label.global_position = base_pos
		action_label.global_position = base_pos + Vector2(0, 30)
		epsilon_label.global_position = base_pos + Vector2(0, 60)
		reward_label.global_position = base_pos + Vector2(0, 90)

func update_hud_components():
	if not hud_container:
		return
		
	# Update epsilon bar
	if epsilon_bar and metrics_data.has("epsilon"):
		epsilon_bar.value = (1.0 - metrics_data.epsilon) * 100
		
		# Update color based on phase
		if metrics_data.epsilon > 0.7:
			epsilon_bar.modulate = random_action_color  # Exploration phase
			learning_phase = "Exploration"
		elif metrics_data.epsilon > 0.2:
			epsilon_bar.modulate = highlight_color  # Transition phase
			learning_phase = "Transition"
		else:
			epsilon_bar.modulate = best_action_color  # Exploitation phase
			learning_phase = "Exploitation"
	
	# Update learning phase label
	if learning_phase_label:
		learning_phase_label.text = "Phase: " + learning_phase
		if learning_phase == "Exploration":
			learning_phase_label.modulate = random_action_color
		elif learning_phase == "Transition":
			learning_phase_label.modulate = highlight_color
		else:
			learning_phase_label.modulate = best_action_color
	
	# Update Q-table chart
	if qtable_chart and metrics_data.has("q_table_size"):
		qtable_chart.queue_redraw()
		qtable_chart.draw.connect(func(): draw_qtable_chart())
	
	# Update rewards chart
	if recent_rewards_chart:
		recent_rewards_chart.queue_redraw()
		recent_rewards_chart.draw.connect(func(): draw_rewards_chart())

func draw_qtable_chart():
	if not qtable_chart or not metrics_data.has("q_table_size"):
		return
		
	# Draw background
	var size = qtable_chart.size
	var max_states = max(1000, metrics_data.q_table_size * 1.2)  # Scale based on current size
	var height = size.y - 10
	var width = size.x - 10
	
	# Draw value
	var bar_height = min(height, (metrics_data.q_table_size / max_states) * height)
	var bar_rect = Rect2(5, height - bar_height + 5, width, bar_height)
	var color = highlight_color
	qtable_chart.draw_rect(bar_rect, color)
	
	# Draw text
	var font = ThemeDB.fallback_font
	qtable_chart.draw_string(font, Vector2(10, 20),
		str(metrics_data.q_table_size) + " states", HORIZONTAL_ALIGNMENT_LEFT)

func draw_rewards_chart():
	if not recent_rewards_chart:
		return
		
	# Draw background
	var size = recent_rewards_chart.size
	var height = size.y - 10
	var width = size.x - 10
	var bar_width = width / recent_rewards.size()
	
	# Draw zero line
	var zero_y = height / 2 + 5
	recent_rewards_chart.draw_line(Vector2(5, zero_y), Vector2(width + 5, zero_y), Color.WHITE, 1)
	
	# Draw bars
	for i in range(recent_rewards.size()):
		var reward = recent_rewards[i]
		var bar_height = clamp(reward * 20, -height/2, height/2)  # Scale for visibility
		var x = 5 + i * bar_width
		
		var color = good_reward_color if reward >= 0 else bad_reward_color
		if reward >= 0:
			recent_rewards_chart.draw_rect(Rect2(x, zero_y - bar_height, bar_width - 2, bar_height), color)
		else:
			recent_rewards_chart.draw_rect(Rect2(x, zero_y, bar_width - 2, -bar_height), color)

func update_state_display(state_hash: String):
	current_state_hash = state_hash
	state_label.text = "State: " + format_state_hash(state_hash)

func update_action_display(action_idx: int, action: Array, is_random: bool):
	current_action_index = action_idx
	current_action = action
	is_random_action = is_random
	
	# Format action as text
	var action_str = "A" + str(action_idx) + ": ["
	for i in range(action.size()):
		action_str += str(action[i])
		if i < action.size() - 1:
			action_str += ","
	action_str += "]"
	
	# Add exploration/exploitation indicator with bold formatting
	action_str += "\n(" + ("RANDOM" if is_random else "BEST") + ")"
	action_label.text = action_str

func update_epsilon_display(epsilon: float):
	epsilon_label.text = "ε: " + "%.3f" % epsilon + " (E: " + str(metrics_data.get("explorations", 0)) + " / B: " + str(metrics_data.get("exploitations", 0)) + ")"

func update_reward_display(reward: float):
	last_reward = reward
	reward_label.text = "R: " + "%.3f" % reward + " (Total: " + "%.1f" % metrics_data.get("episode_rewards", 0.0) + ")"
	
	# Store reward in history
	if recent_rewards.size() > 10:
		recent_rewards.pop_front()
	recent_rewards.append(reward)
	
	# Update color based on reward
	if reward > 0:
		reward_label.modulate = good_reward_color
	elif reward < 0:
		reward_label.modulate = bad_reward_color
	else:
		reward_label.modulate = text_color

func update_exploration_indicator():
	if is_random_action:
		exploration_indicator.modulate = random_action_color
	else:
		exploration_indicator.modulate = best_action_color
	
	# Enhanced pulsing effect
	var pulse_scale = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
	exploration_indicator.scale = Vector2.ONE * pulse_scale

func update_reward_indicator():
	# Clear previous visualization
	for child in reward_indicator.get_children():
		child.queue_free()
	
	# Only visualize significant rewards
	if abs(last_reward) < 0.01:
		return
	
	# Create reward visualization
	var reward_sprite = Sprite2D.new()
	var size = int(clamp(abs(last_reward) * 40, 10, 60))  # Increased size multiplier from 20 to 40
	var color = good_reward_color if last_reward > 0 else bad_reward_color
	reward_sprite.texture = create_circle_texture(size, color)
	
	# Apply glow effect
	if enable_glow:
		reward_sprite.material = glow_material
	
	# Add plus or minus symbol
	var label = Label.new()
	label.add_theme_font_override("font", debug_font)
	label.add_theme_font_size_override("font_size", text_size * 1.5)
	label.text = "+" if last_reward > 0 else "-"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position at the probe
	if parent_probe:
		reward_indicator.global_position = parent_probe.global_position
		
		# Add enhanced fade-out animation
		var tween = create_tween()
		tween.tween_property(reward_sprite, "modulate:a", 0.0, 1.5)  # Longer duration
		tween.parallel().tween_property(reward_sprite, "position:y", -80, 1.5)  # More movement
		tween.parallel().tween_property(reward_sprite, "scale", Vector2(2.0, 2.0), 1.5)  # Scale up as it fades
		tween.tween_callback(reward_sprite.queue_free)
		
		reward_indicator.add_child(reward_sprite)
		reward_sprite.add_child(label)

func update_target_indicator():
	if not parent_probe:
		target_indicator.visible = false
		return
	
	# Get current target if any
	var has_target = false
	var target_pos = Vector2.ZERO
	
	if parent_probe.target_resource_idx >= 0:
		var resources = parent_probe.get_observation_data().get("nearby_resources", [])
		if parent_probe.target_resource_idx < resources.size():
			var target = resources[parent_probe.target_resource_idx]
			target_pos = target.position
			has_target = true
	
	target_indicator.visible = has_target
	if has_target:
		target_indicator.global_position = target_pos
		
		# Add enhanced pulsing effect
		var pulse_scale = 1.0 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
		target_indicator.scale = Vector2.ONE * pulse_scale
		
		# Add target label for better visibility
		if not target_indicator.has_node("Label"):
			var label = Label.new()
			label.text = "TARGET"
			label.add_theme_font_override("font", debug_font)
			label.add_theme_font_size_override("font_size", text_size * 0.75)
			label.position = Vector2(-30, 25)
			label.modulate = target_color
			target_indicator.add_child(label)

func update_planned_path():
	if not parent_probe:
		planned_path.clear_points()
		return
	
	# Enhanced path projection based on current velocity and action
	if parent_probe.is_thrusting and parent_probe.current_thrust_level > 0:
		# Store current position
		planned_path_points.append(parent_probe.global_position)
		
		# Trim to max length
		while planned_path_points.size() > max_path_points:
			planned_path_points.pop_front()
		
		# Calculate projected path based on current velocity and thrust
		var projected_points = []
		var pos = parent_probe.global_position
		var vel = parent_probe.linear_velocity
		var rot = parent_probe.rotation
		var thrust_dir = Vector2(0, -1).rotated(rot)
		var thrust_magnitude = ConfigManager.config.thrust_force_magnitudes[parent_probe.current_thrust_level]
		
		# Project several steps ahead
		for i in range(10):
			vel += thrust_dir * (thrust_magnitude / parent_probe.mass) * 0.1
			if vel.length() > parent_probe.max_velocity:
				vel = vel.normalized() * parent_probe.max_velocity
			pos += vel * 0.5  # Half-second steps
			projected_points.append(pos)
		
		# Update line renderer with actual path and projection
		planned_path.clear_points()
		
		# Add historical points
		for point in planned_path_points:
			planned_path.add_point(point)
		
		# Add projected points
		for point in projected_points:
			planned_path.add_point(point)
	else:
		# If not thrusting, just show historical path
		planned_path.clear_points()
		for point in planned_path_points:
			planned_path.add_point(point)

func update_metrics_display():
	if not q_learning:
		return
	
	# Get latest metrics from Q-learning
	metrics_data = q_learning.get_debug_stats()
	
	# Format metrics text with improved readability
	var metrics_text = "Q-LEARNING METRICS:\n"
	metrics_text += "States: " + str(metrics_data.q_table_size) + " | "
	metrics_text += "Updates: " + str(metrics_data.updates) + "\n"
	metrics_text += "Epsilon: " + "%.3f" % metrics_data.epsilon + " | "
	metrics_text += "Explore/Exploit: " + str(metrics_data.explorations) + "/" + str(metrics_data.exploitations) + "\n"
	metrics_text += "Episode: " + str(metrics_data.episodes) + " | "
	metrics_text += "Steps: " + str(metrics_data.episode_steps) + " | "
	metrics_text += "Rewards: " + "%.2f" % metrics_data.episode_rewards
	
	metrics_label.text = metrics_text
	
	# Log to console at specified frequency
	if log_step_counter % log_frequency == 0:
		log_debug("Q-Learning Metrics - States: " + str(metrics_data.q_table_size) + 
				  ", Epsilon: " + "%.3f" % metrics_data.epsilon + 
				  ", Rewards: " + "%.2f" % metrics_data.episode_rewards, 
				  "info")

func _on_action_received(action: Array):
	if not enabled:
		return
	
	# Update action display with information from agent
	var is_random = parent_agent.q_learning.total_explorations > 0 and parent_agent.q_learning.total_explorations > parent_agent.q_learning.total_exploitations * 0.8
	
	# Get the current action index from the agent
	var action_index = 0
	
	# This is a simplified approximation - in a real system we'd need to access the actual action index
	if parent_agent.last_state_hash.length() > 0:
		action_index = parent_agent.q_learning.get_best_action(parent_agent.last_state_hash)
	
	update_action_display(action_index, action, is_random)
	update_state_display(parent_agent.last_state_hash)
	update_epsilon_display(parent_agent.q_learning.epsilon)

func _on_reward_calculated(reward: float):
	if not enabled:
		return
	
	update_reward_display(reward)
	
	# Log significant rewards
	if abs(reward) > 0.5:
		log_debug("Significant reward: " + "%.2f" % reward, "reward")

# Handle focus button press
func _on_focus_button_pressed():
	if parent_probe:
		camera_target = parent_probe.global_position
		camera_zoom_level = 0.5  # Closer zoom for focus
		request_camera_focus.emit(camera_target, camera_zoom_level)

# Helper to format state hash for display
func format_state_hash(hash: String) -> String:
	# Truncate or format state hash for display
	if hash.length() > 20:
		return hash.substr(0, 10) + "..." + hash.substr(hash.length() - 10)
	return hash

# Logging with different levels
func log_debug(message: String, level: String = "debug"):
	if not ConfigManager.config.ai_debug_logging:
		return
	
	# Format the message based on level
	var formatted_message = ""
	match level:
		"info":
			formatted_message = "[INFO] AIDebug: " + message
		"reward":
			formatted_message = "[REWARD] AIDebug: " + message
		"error":
			formatted_message = "[ERROR] AIDebug: " + message
		"state":
			formatted_message = "[STATE] AIDebug: " + message
		_:
			formatted_message = "[DEBUG] AIDebug: " + message
	
	print(formatted_message)
	ai_debug_log.emit(formatted_message, level)

# Toggle visibility
func set_debug_visibility(visible_state: bool):
	enabled = visible_state
	visible = enabled
	set_process(enabled)
	set_physics_process(enabled)
	set_process_input(enabled)
	
	if hud_container:
		hud_container.visible = visible_state and hud_visible
	
	if enabled:
		log_debug("Debug visualization enabled", "info")
	else:
		log_debug("Debug visualization disabled", "info")