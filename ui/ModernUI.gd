# ModernUI.gd
extends CanvasLayer
class_name ModernUI

# Panel references
@onready var probe_list_panel: Panel = $UIContainer/LeftColumn/ProbeListPanel
@onready var selected_probe_panel: Panel = $UIContainer/LeftColumn/SelectedProbePanel
@onready var system_stats_panel: Panel = $UIContainer/RightColumn/TopSection/SystemStatsPanel
@onready var debug_panel: Panel = $UIContainer/RightColumn/MiddleSection/DebugPanel
@onready var qlearning_monitor: Panel = $UIContainer/RightColumn/BottomSection/QLearningMonitor

# UI state variables
var selected_probe_id: int = -1
var probe_data_cache: Dictionary = {}
var animation_tween: Tween

# Theme constants
const THEME_BG_COLOR = Color(0.1, 0.15, 0.2, 0.9)
const THEME_BORDER_COLOR = Color(0.3, 0.5, 0.8, 0.8)
const THEME_HIGHLIGHT_COLOR = Color(0.4, 0.6, 0.9, 0.8)
const THEME_TEXT_COLOR = Color.WHITE
const THEME_LABEL_COLOR = Color.LIGHT_GRAY
const THEME_CORNER_RADIUS = 8
const THEME_BORDER_WIDTH = 2
const THEME_PANEL_MARGIN = 10

# Signals
signal probe_selected(probe_id: int)
signal simulation_speed_changed(new_speed: float)
signal ui_action_requested(action_type: String, data: Dictionary)

func _ready():
	setup_ui_panels()
	setup_animations()
	setup_input_handlers()

func setup_ui_panels():
	# Apply consistent styling to all panels
	var panels = [probe_list_panel, selected_probe_panel, system_stats_panel, debug_panel]
	if qlearning_monitor:
		panels.append(qlearning_monitor)
	
	for panel in panels:
		apply_panel_style(panel)
	
	# Configure individual panels
	setup_probe_list_panel()
	setup_selected_probe_panel()
	setup_system_stats_panel()
	setup_debug_panel()
	setup_qlearning_monitor()

func apply_panel_style(panel: Panel):
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = THEME_BG_COLOR
	style_box.border_width_left = THEME_BORDER_WIDTH
	style_box.border_width_right = THEME_BORDER_WIDTH
	style_box.border_width_top = THEME_BORDER_WIDTH
	style_box.border_width_bottom = THEME_BORDER_WIDTH
	style_box.border_color = THEME_BORDER_COLOR
	style_box.corner_radius_top_left = THEME_CORNER_RADIUS
	style_box.corner_radius_top_right = THEME_CORNER_RADIUS
	style_box.corner_radius_bottom_left = THEME_CORNER_RADIUS
	style_box.corner_radius_bottom_right = THEME_CORNER_RADIUS
	
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Add padding inside the panel
	if panel.get_child_count() == 0:
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", THEME_PANEL_MARGIN)
		margin_container.add_theme_constant_override("margin_right", THEME_PANEL_MARGIN)
		margin_container.add_theme_constant_override("margin_top", THEME_PANEL_MARGIN)
		margin_container.add_theme_constant_override("margin_bottom", THEME_PANEL_MARGIN)
		margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(margin_container)

func setup_probe_list_panel():
	var margin_container = probe_list_panel.get_child(0) as MarginContainer
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Title
	var title = Label.new()
	title.text = "Probe List"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	vbox.add_child(title)
	
	# Scroll container for probe list
	var scroll_container = ScrollContainer.new()
	scroll_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll_container.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	
	var list_container = VBoxContainer.new()
	list_container.name = "ProbeListContainer"
	list_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	scroll_container.add_child(list_container)
	vbox.add_child(scroll_container)
	
	margin_container.add_child(vbox)

func setup_selected_probe_panel():
	var margin_container = selected_probe_panel.get_child(0) as MarginContainer
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	title.text = "Selected Probe"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	vbox.add_child(title)
	
	# Probe info section
	var info_section = create_info_section("Probe Information")
	vbox.add_child(info_section)
	
	# Energy display
	var energy_section = create_energy_display()
	vbox.add_child(energy_section)
	
	# Action controls
	var control_section = create_probe_controls()
	vbox.add_child(control_section)
	
	margin_container.add_child(vbox)

func create_info_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	
	# Title label
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	section.add_child(title_label)
	
	# Info container
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.add_theme_constant_override("separation", 2)
	section.add_child(info_container)
	
	return section

func create_energy_display() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	
	# Title
	var title = Label.new()
	title.text = "Energy"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	section.add_child(title)
	
	var container = HBoxContainer.new()
	container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Energy bar
	var energy_bar = ProgressBar.new()
	energy_bar.name = "EnergyBar"
	energy_bar.max_value = 100
	energy_bar.value = 90
	energy_bar.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Style the progress bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color.GREEN
	bar_style.corner_radius_top_left = 4
	bar_style.corner_radius_top_right = 4
	bar_style.corner_radius_bottom_left = 4
	bar_style.corner_radius_bottom_right = 4
	energy_bar.add_theme_stylebox_override("fill", bar_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	energy_bar.add_theme_stylebox_override("background", bg_style)
	
	# Energy label
	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "90000 / 100000"
	energy_label.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	energy_label.set_h_size_flags(Control.SIZE_SHRINK_END)
	energy_label.set_custom_minimum_size(Vector2(100, 0))
	
	container.add_child(energy_bar)
	container.add_child(energy_label)
	section.add_child(container)
	
	return section

func create_probe_controls() -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	section.add_child(title)
	
	# Manual control buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 5)
	button_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	var thrust_button = Button.new()
	thrust_button.text = "Thrust"
	thrust_button.name = "ThrustButton"
	thrust_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	thrust_button.pressed.connect(_on_manual_thrust_pressed)
	
	var rotate_left_button = Button.new()
	rotate_left_button.text = "◄"
	rotate_left_button.name = "RotateLeftButton"
	rotate_left_button.pressed.connect(_on_rotate_left_pressed)
	
	var rotate_right_button = Button.new()
	rotate_right_button.text = "►"
	rotate_right_button.name = "RotateRightButton"
	rotate_right_button.pressed.connect(_on_rotate_right_pressed)
	
	var replicate_button = Button.new()
	replicate_button.text = "Replicate"
	replicate_button.name = "ReplicateButton"
	replicate_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	replicate_button.pressed.connect(_on_replicate_pressed)
	
	button_container.add_child(thrust_button)
	button_container.add_child(rotate_left_button)
	button_container.add_child(rotate_right_button)
	button_container.add_child(replicate_button)
	
	section.add_child(button_container)
	
	# AI control toggle
	var ai_toggle = CheckBox.new()
	ai_toggle.text = "AI Control Enabled"
	ai_toggle.name = "AIToggle"
	ai_toggle.button_pressed = true
	ai_toggle.toggled.connect(_on_ai_toggle_changed)
	
	section.add_child(ai_toggle)
	
	return section

func setup_system_stats_panel():
	var margin_container = system_stats_panel.get_child(0) as MarginContainer
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	
	# Title
	var title = Label.new()
	title.text = "System Statistics"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	vbox.add_child(title)
	
	# Stats container
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.add_theme_constant_override("separation", 2)
	vbox.add_child(stats_container)
	
	margin_container.add_child(vbox)

func setup_debug_panel():
	if not is_instance_valid(debug_panel):
		return
		
	var margin_container = debug_panel.get_child(0) as MarginContainer
	
	if not ConfigManager.config.debug_mode:
		debug_panel.visible = false
		return
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	# Title
	var title = Label.new()
	title.text = "Debug Controls"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	vbox.add_child(title)
	
	# Debug controls
	var debug_controls = create_debug_controls()
	vbox.add_child(debug_controls)
	
	# Performance metrics
	var perf_metrics = create_performance_display()
	vbox.add_child(perf_metrics)
	
	margin_container.add_child(vbox)

func create_debug_controls() -> VBoxContainer:
	var controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	
	# Speed control
	var speed_container = HBoxContainer.new()
	var speed_label = Label.new()
	speed_label.text = "Simulation Speed:"
	speed_label.add_theme_color_override("font_color", THEME_LABEL_COLOR)
	
	var speed_slider = HSlider.new()
	speed_slider.name = "SpeedSlider"
	speed_slider.min_value = 0.1
	speed_slider.max_value = 5.0
	speed_slider.value = 1.0
	speed_slider.step = 0.1
	speed_slider.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	speed_slider.value_changed.connect(_on_speed_changed)
	
	speed_container.add_child(speed_label)
	speed_container.add_child(speed_slider)
	controls.add_child(speed_container)
	
	# Debug buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 5)
	
	var pause_button = Button.new()
	pause_button.text = "Pause/Resume"
	pause_button.pressed.connect(_on_pause_pressed)
	pause_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	var reset_button = Button.new()
	reset_button.text = "Reset Episode"
	reset_button.pressed.connect(_on_reset_pressed)
	reset_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	var save_button = Button.new()
	save_button.text = "Quick Save"
	save_button.pressed.connect(_on_save_pressed)
	save_button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	button_container.add_child(pause_button)
	button_container.add_child(reset_button)
	button_container.add_child(save_button)
	controls.add_child(button_container)
	
	return controls

func create_performance_display() -> VBoxContainer:
	var perf_display = VBoxContainer.new()
	perf_display.name = "PerformanceDisplay"
	perf_display.add_theme_constant_override("separation", 5)
	
	var title = Label.new()
	title.text = "Performance Metrics"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	perf_display.add_child(title)
	
	var metrics_container = VBoxContainer.new()
	metrics_container.name = "MetricsContainer"
	metrics_container.add_theme_constant_override("separation", 2)
	perf_display.add_child(metrics_container)
	
	return perf_display

func setup_animations():
	animation_tween = create_tween()
	animation_tween.set_loops()
	
	# Animate panel appearances
	animate_panel_glow()

func animate_panel_glow():
	# Add subtle glow animation to active panels
	var panels = [probe_list_panel, selected_probe_panel, system_stats_panel]
	if is_instance_valid(qlearning_monitor):
		panels.append(qlearning_monitor)
	
	for panel in panels:
		if not is_instance_valid(panel):
			continue
			
		var style_box = panel.get_theme_stylebox("panel")
		if style_box is StyleBoxFlat:
			var original_color = style_box.border_color
			animation_tween.parallel().tween_method(
				func(color): style_box.border_color = color,
				original_color,
				original_color * 1.3,
				2.0
			)
			animation_tween.parallel().tween_method(
				func(color): style_box.border_color = color,
				original_color * 1.3,
				original_color,
				2.0
			)

func setup_input_handlers():
	# Setup keyboard shortcuts
	set_process_input(true)

func _input(event):
	if event.is_action_pressed("toggle_ui"):
		toggle_ui_visibility()
	elif event.is_action_pressed("focus_next_probe"):
		focus_next_probe()
	elif event.is_action_pressed("toggle_debug_panel"):
		if is_instance_valid(debug_panel):
			debug_panel.visible = !debug_panel.visible

func update_ui_data(simulation_data: Dictionary):
	update_probe_list(simulation_data.get("probes", {}))
	update_selected_probe_info(simulation_data.get("selected_probe"))
	update_system_stats(simulation_data.get("stats", {}))
	update_debug_info(simulation_data.get("debug_info", {}))

func update_probe_list(probes_data: Dictionary):
	var container = probe_list_panel.get_node("MarginContainer/VBoxContainer/ScrollContainer/ProbeListContainer")
	if not is_instance_valid(container):
		return
	
	# Cache probe data
	probe_data_cache = probes_data
	
	# Clear existing items
	for child in container.get_children():
		child.queue_free()
	
	# Add probe items
	for probe_id in probes_data:
		var probe_data = probes_data[probe_id]
		var probe_item = create_probe_list_item(probe_id, probe_data)
		container.add_child(probe_item)

func create_probe_list_item(probe_id: int, probe_data: Dictionary) -> Control:
	var item_container = PanelContainer.new()
	item_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Style for the item
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.2, 0.25, 0.5)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	
	# Highlight selected probe
	if probe_id == selected_probe_id:
		style_box.bg_color = Color(0.3, 0.5, 0.8, 0.3)
		style_box.border_width_left = 1
		style_box.border_width_right = 1
		style_box.border_width_top = 1
		style_box.border_width_bottom = 1
		style_box.border_color = THEME_HIGHLIGHT_COLOR
	
	item_container.add_theme_stylebox_override("panel", style_box)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	
	var hbox = HBoxContainer.new()
	hbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Status indicator
	var status_indicator = ColorRect.new()
	status_indicator.size = Vector2(16, 16)
	status_indicator.set_custom_minimum_size(Vector2(16, 16))
	
	var energy_ratio = probe_data.get("energy", 0) / probe_data.get("max_energy", 1)
	if probe_data.get("is_alive", false):
		status_indicator.color = Color.GREEN if energy_ratio > 0.3 else Color.YELLOW
	else:
		status_indicator.color = Color.RED
	
	# Probe info
	var info_vbox = VBoxContainer.new()
	info_vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	var name_label = Label.new()
	name_label.text = "Probe " + str(probe_id)
	name_label.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	
	var status_label = Label.new()
	status_label.text = "Energy: " + str(int(energy_ratio * 100)) + "%"
	
	if energy_ratio > 0.7:
		status_label.add_theme_color_override("font_color", Color.GREEN)
	elif energy_ratio > 0.3:
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		status_label.add_theme_color_override("font_color", Color.RED)
	
	info_vbox.add_child(name_label)
	info_vbox.add_child(status_label)
	
	# Select button
	var select_button = Button.new()
	select_button.text = "Select"
	select_button.pressed.connect(_on_probe_selected.bind(probe_id))
	
	hbox.add_child(status_indicator)
	hbox.add_child(info_vbox)
	hbox.add_child(select_button)
	
	margin.add_child(hbox)
	item_container.add_child(margin)
	
	return item_container

func update_selected_probe_info(probe_data):
	if not probe_data:
		selected_probe_panel.visible = false
		return
	
	selected_probe_panel.visible = true
	
	# Update info section
	var info_container = selected_probe_panel.get_node("MarginContainer/VBoxContainer/InfoContainer")
	if is_instance_valid(info_container):
		update_probe_info_display(info_container, probe_data)
	
	# Update energy display
	var energy_bar = selected_probe_panel.get_node("MarginContainer/VBoxContainer/EnergyBar")
	var energy_label = selected_probe_panel.get_node("MarginContainer/VBoxContainer/EnergyLabel")
	
	if energy_bar and energy_label:
		var energy_ratio = probe_data.energy / probe_data.max_energy
		energy_bar.value = energy_ratio * 100
		energy_label.text = str(int(probe_data.energy)) + " / " + str(int(probe_data.max_energy))
		
		# Update energy bar color
		var bar_style = energy_bar.get_theme_stylebox("fill")
		if bar_style is StyleBoxFlat:
			if energy_ratio > 0.7:
				bar_style.bg_color = Color.GREEN
			elif energy_ratio > 0.3:
				bar_style.bg_color = Color.YELLOW
			else:
				bar_style.bg_color = Color.RED

func update_probe_info_display(container: Control, probe_data: Dictionary):
	# Clear existing info
	for child in container.get_children():
		child.queue_free()
	
	# Add probe information
	var info_items = [
		["ID", str(probe_data.get("id", "Unknown"))],
		["Generation", str(probe_data.get("generation", 0))],
		["Position", "(" + str(int(probe_data.get("position", Vector2.ZERO).x)) + ", " + str(int(probe_data.get("position", Vector2.ZERO).y)) + ")"],
		["Velocity", str(probe_data.get("velocity", Vector2.ZERO).length()).pad_decimals(1) + " u/s"],
		["Task", probe_data.get("current_task", "Idle")],
		["Target", str(probe_data.get("current_target_id", "None"))],
		["Status", "Alive" if probe_data.get("is_alive", false) else "Dead"]
	]
	
	for item in info_items:
		var info_line = HBoxContainer.new()
		
		var key_label = Label.new()
		key_label.text = item[0] + ":"
		key_label.set_custom_minimum_size(Vector2(80, 0))
		key_label.add_theme_color_override("font_color", THEME_LABEL_COLOR)
		
		var value_label = Label.new()
		value_label.text = item[1]
		value_label.add_theme_color_override("font_color", THEME_TEXT_COLOR)
		
		info_line.add_child(key_label)
		info_line.add_child(value_label)
		container.add_child(info_line)

func update_system_stats(stats_data: Dictionary):
	var stats_container = system_stats_panel.get_node("MarginContainer/VBoxContainer/StatsContainer")
	if not is_instance_valid(stats_container):
		return
	
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Add statistics
	var stat_items = [
		["Episode", str(stats_data.get("episode", 0))],
		["Step", str(stats_data.get("step", 0))],
		["FPS", str(stats_data.get("fps", 60)).pad_decimals(1)],
		["Active Probes", str(stats_data.get("probe_count", 0))],
		["Resources Mined", str(stats_data.get("resources_mined", 0)).pad_decimals(1)],
		["Active Resources", str(stats_data.get("active_resources", 0))],
		["Simulation Speed", str(stats_data.get("sim_speed", 1.0)) + "x"]
	]
	
	for item in stat_items:
		var stat_line = create_stat_line(item[0], item[1])
		stats_container.add_child(stat_line)

func create_stat_line(key: String, value: String) -> Control:
	var line = HBoxContainer.new()
	
	var key_label = Label.new()
	key_label.text = key + ":"
	key_label.set_custom_minimum_size(Vector2(120, 0))
	key_label.add_theme_color_override("font_color", THEME_LABEL_COLOR)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	
	line.add_child(key_label)
	line.add_child(value_label)
	
	return line

func update_debug_info(debug_data: Dictionary):
	if not is_instance_valid(debug_panel) or not debug_panel.visible:
		return
	
	var metrics_container = debug_panel.get_node("MarginContainer/VBoxContainer/PerformanceDisplay/MetricsContainer")
	if not is_instance_valid(metrics_container):
		return
	
	# Clear existing metrics
	for child in metrics_container.get_children():
		child.queue_free()
	
	# Add performance metrics
	var metrics = [
		["Memory Usage", str(debug_data.get("memory_mb", 0)) + " MB"],
		["Physics Time", str(debug_data.get("physics_time_ms", 0)) + " ms"],
		["Render Time", str(debug_data.get("render_time_ms", 0)) + " ms"],
		["AI Update Time", str(debug_data.get("ai_time_ms", 0)) + " ms"],
		["Particle Count", str(debug_data.get("particle_count", 0))],
		["Node Count", str(debug_data.get("node_count", 0))]
	]
	
	for metric in metrics:
		var metric_line = create_stat_line(metric[0], metric[1])
		metrics_container.add_child(metric_line)

func toggle_ui_visibility():
	var panels = [probe_list_panel, selected_probe_panel, system_stats_panel]
	var target_alpha = 0.0 if panels[0].modulate.a > 0.5 else 1.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	for panel in panels:
		tween.tween_property(panel, "modulate:a", target_alpha, 0.3)

func focus_next_probe():
	# Cycle through available probes
	var probe_ids = probe_data_cache.keys()
	if probe_ids.is_empty():
		return
	
	probe_ids.sort()
	var current_index = probe_ids.find(selected_probe_id)
	var next_index = (current_index + 1) % probe_ids.size()
	
	selected_probe_id = probe_ids[next_index]
	probe_selected.emit(selected_probe_id)

# Signal handlers
func _on_probe_selected(probe_id: int):
	selected_probe_id = probe_id
	probe_selected.emit(probe_id)

func _on_manual_thrust_pressed():
	if selected_probe_id >= 0:
		ui_action_requested.emit("manual_thrust", {"probe_id": selected_probe_id})

func _on_rotate_left_pressed():
	if selected_probe_id >= 0:
		ui_action_requested.emit("manual_rotate", {"probe_id": selected_probe_id, "direction": "left"})

func _on_rotate_right_pressed():
	if selected_probe_id >= 0:
		ui_action_requested.emit("manual_rotate", {"probe_id": selected_probe_id, "direction": "right"})

func _on_replicate_pressed():
	if selected_probe_id >= 0:
		ui_action_requested.emit("manual_replicate", {"probe_id": selected_probe_id})

func _on_ai_toggle_changed(enabled: bool):
	if selected_probe_id >= 0:
		ui_action_requested.emit("toggle_ai", {"probe_id": selected_probe_id, "enabled": enabled})

func _on_speed_changed(new_speed: float):
	simulation_speed_changed.emit(new_speed)

func _on_pause_pressed():
	ui_action_requested.emit("toggle_pause", {})

func _on_reset_pressed():
	ui_action_requested.emit("reset_episode", {})

func _on_save_pressed():
	ui_action_requested.emit("quick_save", {})

func setup_qlearning_monitor():
	if not is_instance_valid(qlearning_monitor):
		return
		
	var margin_container = qlearning_monitor.get_child(0) as MarginContainer
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Title
	var title = Label.new()
	title.text = "Q-Learning Monitor"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", THEME_TEXT_COLOR)
	vbox.add_child(title)
	
	# Placeholder for Q-learning visualization
	var placeholder = Label.new()
	placeholder.text = "Q-Learning visualization will appear here"
	placeholder.add_theme_color_override("font_color", THEME_LABEL_COLOR)
	placeholder.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	placeholder.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(placeholder)
	
	margin_container.add_child(vbox)
