extends Control
class_name ModernUI

# --- UI Colors (from Config, but can be overridden or defined here for modularity) ---
var ui_colors: Dictionary = {
    "panel_bg": Color(0.05, 0.08, 0.12, 0.85), # Slightly darker, more opaque
    "panel_border": Color(0.15, 0.50, 0.90, 0.80),
    "text_primary": Color(0.90, 0.92, 0.95),
    "text_secondary": Color(0.65, 0.70, 0.80),
    "accent_blue": Color(0.25, 0.75, 1.0),
    "accent_green": Color(0.25, 0.90, 0.50),
    "accent_yellow": Color(1.0, 0.90, 0.40),
    "accent_red": Color(1.0, 0.50, 0.50),
    "list_item_selected_bg": Color(0.2, 0.35, 0.5, 0.7)
}

# --- Data References (updated by Main.gd) ---
var current_solar_system_data: Dictionary # Simplified data from SolarSystem.get_simulation_environment_data()
var selected_probe_id: int = -1
# var selected_probe_details_dict: Dictionary # Derived from current_solar_system_data.probes_details

var current_camera_zoom: float = 1.0
var current_fps: float = 0.0

# --- OnReady Node References for UI Panels and Elements ---
# These should be children of this ModernUI Control node in the scene.
@onready var stats_panel_node: PanelContainer = $InfoDisplay/StatsPanelContainer
@onready var probe_details_panel_node: PanelContainer = $InfoDisplay/ProbeDetailsPanelContainer
@onready var probe_list_panel_node: PanelContainer = $ProbeSelection/ProbeListPanelContainer

@onready var stats_label_node: RichTextLabel = $InfoDisplay/StatsPanelContainer/MarginContainer/StatsLabel
@onready var probe_details_label_node: RichTextLabel = $InfoDisplay/ProbeDetailsPanelContainer/MarginContainer/ProbeDetailsLabel
@onready var probe_list_node: ItemList = $ProbeSelection/ProbeListPanelContainer/MarginContainer/ProbeList

# For clickable elements, not used in this version as ItemList handles clicks.
# var clickable_ui_elements: Dictionary = {} 
var probe_list_scroll_value: float = 0.0 # For manual scroll if needed, ItemList handles it mostly.

# Signal emitted when a probe is selected from the list
signal probe_selection_changed(newly_selected_probe_id: int)


func _ready():
    # Apply initial styling to panels (can also be done via Theme resource)
    _apply_panel_styles()
    
    # Connect signals from UI elements
    if is_instance_valid(probe_list_node):
        probe_list_node.item_selected.connect(_on_probe_list_item_selected)
        # probe_list_node.gui_input.connect(_on_probe_list_gui_input) # For scroll wheel if not default
    else:
        printerr("ModernUI: ProbeList node not found!")

    # Initial UI update with placeholder or empty data
    update_ui_display_content()


func _apply_panel_styles():
    var default_theme = ThemeDB.get_default_theme()
    var default_font = default_theme.get_default_font() if default_theme else null
    var default_font_size = default_theme.get_default_font_size() if default_theme else 16 # Default fallback

    for panel_container_node in [stats_panel_node, probe_details_panel_node, probe_list_panel_node]:
        if is_instance_valid(panel_container_node):
            var stylebox = StyleBoxFlat.new()
            stylebox.bg_color = ui_colors.panel_bg
            stylebox.border_width_top = 1; stylebox.border_width_bottom = 1
            stylebox.border_width_left = 1; stylebox.border_width_right = 1
            stylebox.border_color = ui_colors.panel_border
            stylebox.corner_radius_top_left = 3; stylebox.corner_radius_top_right = 3
            stylebox.corner_radius_bottom_left = 3; stylebox.corner_radius_bottom_right = 3
            panel_container_node.add_theme_stylebox_override("panel", stylebox)

    if is_instance_valid(probe_list_node):
        var selected_style = StyleBoxFlat.new()
        selected_style.bg_color = ui_colors.list_item_selected_bg
        probe_list_node.add_theme_stylebox_override("selected", selected_style)
        probe_list_node.add_theme_color_override("font_color", ui_colors.text_secondary)
        probe_list_node.add_theme_color_override("font_selected_color", ui_colors.text_primary)
        if default_font: probe_list_node.add_theme_font_override("font", default_font)
        probe_list_node.add_theme_font_size_override("font_size", default_font_size -1) # Slightly smaller for list

    for label_node in [stats_label_node, probe_details_label_node]:
        if is_instance_valid(label_node):
            label_node.bbcode_enabled = true # For color tags
            label_node.add_theme_color_override("default_color", ui_colors.text_secondary)
            if default_font: label_node.add_theme_font_override("normal_font", default_font)
            label_node.add_theme_font_size_override("normal_font_size", default_font_size)


# Called by Main.gd to push new data to the UI
func update_simulation_data(
    solar_system_info: Dictionary, # From SolarSystem.get_simulation_environment_data()
    current_selected_probe_id: int,
    # selected_probe_info: Dictionary, # This can be derived from solar_system_info
    cam_zoom: float, 
    fps_value: float
    ):
    current_solar_system_data = solar_system_info
    selected_probe_id = current_selected_probe_id # Main might control this based on clicks or AI focus
    current_camera_zoom = cam_zoom
    current_fps = fps_value
    
    update_ui_display_content()

func update_ui_display_content():
    _update_stats_panel_display()
    _update_probe_list_panel_display() # Update list first, as selection might change
    _update_probe_details_panel_display() # Then update details based on current selection

func _update_stats_panel_display():
    if not is_instance_valid(stats_label_node) or not current_solar_system_data:
        if is_instance_valid(stats_label_node): stats_label_node.text = "Stats: No data"
        return

    var text_color_html = ui_colors.text_primary.to_html(false)
    var value_color_html = ui_colors.accent_blue.to_html(false) # For dynamic values

    var stats_bbcode = "[color=#%s]System Status[/color]\n" % text_color_html
    stats_bbcode += "  Step: [color=#%s]%d[/color]\n" % [value_color_html, current_solar_system_data.get("current_step_count", 0)]
    stats_bbcode += "  FPS: [color=#%s]%.1f[/color]\n" % [value_color_html, current_fps]
    stats_bbcode += "  Zoom: [color=#%s]x%.1f[/color]\n" % [value_color_html, current_camera_zoom]
    stats_bbcode += "  Probes: [color=#%s]%d[/color] / %d\n" % [value_color_html, current_solar_system_data.get("active_probes_count", 0), current_solar_system_data.get("total_probes_created",0)]
    stats_bbcode += "  Resources: [color=#%s]%d[/color]\n" % [value_color_html, current_solar_system_data.get("active_resources_count", 0)]
    stats_bbcode += "  Mined: [color=#%s]%.1f[/color]\n" % [value_color_html, current_solar_system_data.get("total_resources_mined_session", 0.0)]
    stats_bbcode += "  Messages: [color=#%s]%d[/color]" % [value_color_html, current_solar_system_data.get("messages_log_count", 0)]
    
    stats_label_node.text = stats_bbcode

func _update_probe_list_panel_display():
    if not is_instance_valid(probe_list_node) or not current_solar_system_data:
        if is_instance_valid(probe_list_node): probe_list_node.clear()
        return

    probe_list_node.clear()
    var probes_dict: Dictionary = current_solar_system_data.get("probes_details", {})
    if probes_dict.is_empty():
        probe_list_node.add_item("No probes active.")
        probe_list_node.set_item_disabled(0, true)
        return

    var sorted_probe_ids = probes_dict.keys()
    sorted_probe_ids.sort() # Sort by ID

    var selected_item_idx = -1
    for p_id_variant in sorted_probe_ids:
        var p_id = int(p_id_variant) # Ensure it's an int
        var p_data: Dictionary = probes_dict[p_id]
        
        var p_energy = p_data.get("energy", 0.0)
        var p_alive = p_data.get("alive", false)
        var p_gen = p_data.get("generation", 0)
        
        var status_text = "ALIVE" if p_alive else "DEAD"
        var item_text = "ID:%d Gen:%d E:%.0f [%s]" % [p_id, p_gen, p_energy, status_text]
        probe_list_node.add_item(item_text)
        
        var current_item_idx = probe_list_node.get_item_count() - 1
        probe_list_node.set_item_metadata(current_item_idx, p_id) # Store probe_id in metadata

        # Color coding
        var item_color = ui_colors.text_secondary
        if not p_alive:
            item_color = ui_colors.accent_red.darkened(0.3)
        elif p_energy < Config.Probe.MAX_ENERGY * Config.RL.PENALTY_LOW_ENERGY_THRESHOLD_1: # Assuming this threshold exists
            item_color = ui_colors.accent_yellow
        else:
            item_color = ui_colors.accent_green
        probe_list_node.set_item_custom_fg_color(current_item_idx, item_color)
        
        if p_id == selected_probe_id:
            selected_item_idx = current_item_idx
            
    if selected_item_idx != -1:
        probe_list_node.select(selected_item_idx)
        # probe_list_node.ensure_current_is_visible() # Scroll to selected

func _update_probe_details_panel_display():
    if not is_instance_valid(probe_details_label_node) or not current_solar_system_data:
        if is_instance_valid(probe_details_label_node): probe_details_label_node.text = "Details: No data"
        return

    var text_color_html = ui_colors.text_primary.to_html(false)
    var value_color_html = ui_colors.accent_blue.to_html(false)
    var secondary_color_html = ui_colors.text_secondary.to_html(false)

    if selected_probe_id == -1:
        probe_details_label_node.text = "[center][color=#%s]No Probe Selected[/color][/center]" % secondary_color_html
        return

    var probes_dict: Dictionary = current_solar_system_data.get("probes_details", {})
    var p_details: Dictionary = probes_dict.get(selected_probe_id)

    if not p_details:
        probe_details_label_node.text = "[center][color=#%s]Probe ID %d not found.[/color][/center]" % [secondary_color_html, selected_probe_id]
        return

    var details_bbcode = "[color=#%s]Probe Details (ID: %d)[/color]\n" % [text_color_html, selected_probe_id]
    
    var energy_val = p_details.get("energy", 0.0)
    var energy_color = ui_colors.accent_green
    if energy_val < Config.Probe.MAX_ENERGY * Config.RL.PENALTY_LOW_ENERGY_THRESHOLD_1:
        energy_color = ui_colors.accent_yellow
    if energy_val < Config.Probe.MAX_ENERGY * Config.RL.PENALTY_LOW_ENERGY_THRESHOLD_2:
        energy_color = ui_colors.accent_red
        
    details_bbcode += "  Energy: [color=#%s]%.1f[/color] / %.0f\n" % [energy_color.to_html(false), energy_val, Config.Probe.MAX_ENERGY]
    
    var pos: Vector2 = p_details.get("position", Vector2.ZERO)
    details_bbcode += "  Position: ([color=#%s]%.0f[/color], [color=#%s]%.0f[/color])\n" % [value_color_html, pos.x, value_color_html, pos.y]
    
    var vel: Vector2 = p_details.get("velocity", Vector2.ZERO)
    details_bbcode += "  Velocity: ([color=#%s]%.1f[/color], [color=#%s]%.1f[/color]) Mag: %.1f\n" % [value_color_html, vel.x, value_color_html, vel.y, vel.length()]
    
    var angle_deg = rad_to_deg(p_details.get("angle_rad", 0.0))
    details_bbcode += "  Angle: [color=#%s]%.1f[/color]°\n" % [value_color_html, angle_deg]
    
    details_bbcode += "  Generation: [color=#%s]%d[/color]\n" % [value_color_html, p_details.get("generation", 0)]
    
    var target_id = p_details.get("target_resource_id", -1)
    var target_text = "None"
    if target_id != -1 : target_text = "ResourceID %d" % target_id
    details_bbcode += "  Target: [color=#%s]%s[/color]\n" % [value_color_html, target_text]
    
    var mining_status = "No"
    if p_details.get("is_mining", false): mining_status = "[color=#%s]Yes[/color]" % ui_colors.accent_green.to_html(false)
    details_bbcode += "  Mining: %s\n" % mining_status
    
    var alive_status = "[color=#%s]ALIVE[/color]" % ui_colors.accent_green.to_html(false)
    if not p_details.get("alive", true): alive_status = "[color=#%s]DESTROYED[/color]" % ui_colors.accent_red.to_html(false)
    details_bbcode += "  Status: %s" % alive_status
    
    probe_details_label_node.text = details_bbcode

# --- UI Event Handlers ---
func _on_probe_list_item_selected(index: int):
    if index >= 0 and index < probe_list_node.get_item_count():
        var new_id = probe_list_node.get_item_metadata(index)
        if new_id is int and new_id != selected_probe_id:
            selected_probe_id = new_id
            probe_selection_changed.emit(selected_probe_id) # Inform Main.gd
            _update_probe_details_panel_display() # Update details immediately


func _input(event: InputEvent): # General input handling for the UI control itself
    # This UI component primarily reacts to data updates.
    # Click handling for specific elements like buttons would be connected via signals.
    # Mouse wheel scrolling for ItemList is usually handled by default if it has focus.
    
    # Example: if a panel was scrollable and not an ItemList
    # if event is InputEventMouseButton:
        # if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            # if probe_list_panel_node.get_global_rect().has_point(event.global_position):
                # probe_list_node.scroll_vertical -= 20 # Example manual scroll
                # get_viewport().set_input_as_handled()
        # elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            # if probe_list_panel_node.get_global_rect().has_point(event.global_position):
                # probe_list_node.scroll_vertical += 20
                # get_viewport().set_input_as_handled()
    pass

# Public method for Main.gd to set the selected probe externally (e.g. clicking in game view)
func set_selected_probe_externally(probe_id_to_select: int):
    if selected_probe_id == probe_id_to_select:
        return

    selected_probe_id = probe_id_to_select
    # Find the item in the list and select it visually
    for i in range(probe_list_node.get_item_count()):
        if probe_list_node.get_item_metadata(i) == selected_probe_id:
            probe_list_node.select(i)
            probe_list_node.ensure_current_is_visible()
            break
    _update_probe_details_panel_display() # Update details panel