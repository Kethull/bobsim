extends Node2D
class_name OrganicShipRenderer

# Reference to the Probe node this renderer is attached to or represents.
# This should be set externally, e.g., in the Probe's _ready() function.
var probe_node: Node # Changed from 'probe: Probe' to 'probe_node: Node' to avoid cyclic dependency if Probe class is not yet defined.
                    # We'll cast to Probe type or access properties via get() when needed.

var ship_colors: Dictionary = {
    "hull_primary": Color(0.33, 0.37, 0.43),
    "hull_secondary": Color(0.41, 0.45, 0.51),
    "hull_accent": Color(0.49, 0.53, 0.59),
    "engine_core": Color(0.59, 0.71, 1.0), # Bluish for engine
    "engine_glow": Color(0.78, 0.86, 1.0, 0.7), # More transparent outer glow
    "energy_high": Color(0.47, 1.0, 0.78), # Greenish
    "energy_medium": Color(1.0, 0.78, 0.39), # Yellowish
    "energy_low": Color(1.0, 0.39, 0.39), # Reddish
    "dead_color": Color(0.2, 0.2, 0.2, 0.6) # Color when probe is not alive
}

var ship_base_length: float = Config.Visualization.PROBE_SIZE_PX * 1.2 # Adjusted for a more elongated look
var ship_base_width: float = Config.Visualization.PROBE_SIZE_PX * 0.7

var current_scale: float = 1.0 # Can be adjusted by camera zoom or other effects

func _ready():
    # The probe_node reference should be set by the parent Probe script.
    # Example: $OrganicShipRenderer.probe_node = self
    pass

func _draw():
    if not is_instance_valid(probe_node):
        # Optionally draw a placeholder or nothing if no probe data
        # draw_circle(Vector2.ZERO, Config.Visualization.PROBE_SIZE_PX * 0.5, Color.DARK_GRAY)
        return

    var is_alive = probe_node.get("alive") if probe_node.has_method("get") else true # Default to alive if property not found
    var energy = probe_node.get("energy") if probe_node.has_method("get") else Config.Probe.MAX_ENERGY
    var max_energy = Config.Probe.MAX_ENERGY # Assuming this is accessible

    if not is_alive:
        draw_dead_ship()
        return

    var energy_ratio = 0.0
    if max_energy > 0:
        energy_ratio = clamp(energy / max_energy, 0.0, 1.0)
    
    # The ship should be drawn relative to its own Node2D origin.
    # Rotation of this Node2D will rotate the entire drawn ship.
    # The probe's main script will set this Node2D's rotation based on probe_node.angle_rad.

    draw_organic_ship_shape(energy_ratio)


func draw_dead_ship():
    var length = ship_base_length * current_scale
    var width = ship_base_width * current_scale
    var dead_points = PackedVector2Array([
        Vector2(-length * 0.5, -width * 0.3), Vector2(length * 0.3, -width * 0.4),
        Vector2(length * 0.5, 0), Vector2(length * 0.3, width * 0.4),
        Vector2(-length * 0.5, width * 0.3), Vector2(-length * 0.4, 0) # Jagged look
    ])
    draw_colored_polygon(dead_points, ship_colors.dead_color)
    draw_polyline(dead_points, ship_colors.dead_color.darkened(0.3), 1.0 * current_scale, true)


func draw_organic_ship_shape(energy_ratio: float):
    # Draw components from back to front
    draw_engine_flair(energy_ratio)
    draw_main_body(energy_ratio)
    draw_cockpit_area(energy_ratio) # Forward section
    draw_hull_details(energy_ratio)
    draw_status_indicators(energy_ratio)

func draw_main_body(energy_ratio: float):
    var length = ship_base_length * current_scale
    var width = ship_base_width * current_scale
    
    var hull_color = ship_colors.hull_primary.lerp(ship_colors.hull_secondary, energy_ratio * 0.5)
    if energy_ratio < 0.2:
        hull_color = hull_color.lerp(ship_colors.dead_color, 0.5)

    # Main body shape - a bit more streamlined
    var body_points = PackedVector2Array()
    var num_segments = 10 # Segments per half
    
    # Nose (front = positive X)
    body_points.append(Vector2(length * 0.5, 0)) 
    # Top side
    for i in range(1, num_segments + 1):
        var t = float(i) / num_segments # 0 to 1
        var x = length * (0.5 - t) # From nose backwards
        var y_offset = width * 0.5 * pow(sin(t * PI * 0.8 + PI*0.1), 0.7) # Curved top
        if t > 0.7: # Taper towards engine
             y_offset *= (1.0 - (t-0.7)/0.3) * 0.8 + 0.2
        body_points.append(Vector2(x, -y_offset))
    # Bottom side (symmetric)
    for i in range(num_segments, 0, -1): # Iterate backwards for bottom
        var t = float(i) / num_segments
        var x = length * (0.5 - t)
        var y_offset = width * 0.5 * pow(sin(t * PI * 0.8 + PI*0.1), 0.7)
        if t > 0.7:
             y_offset *= (1.0 - (t-0.7)/0.3) * 0.8 + 0.2
        body_points.append(Vector2(x, y_offset))
    body_points.append(Vector2(length * 0.5, 0)) # Close shape at nose

    draw_colored_polygon(body_points, hull_color)
    draw_polyline(body_points, ship_colors.hull_accent.lerp(hull_color,0.5), 1.0 * current_scale, true)


func draw_engine_flair(energy_ratio: float):
    var length = ship_base_length * current_scale
    var width = ship_base_width * current_scale
    var engine_pos_x = -length * 0.5 # Back of the ship

    # Engine housing
    var housing_width = width * 0.7
    var housing_color = ship_colors.hull_secondary.darkened(0.1)
    if energy_ratio < 0.2: housing_color = housing_color.lerp(ship_colors.dead_color, 0.6)
    
    var housing_points = PackedVector2Array([
        Vector2(engine_pos_x + length*0.05, -housing_width * 0.5), Vector2(engine_pos_x - length*0.1, -housing_width * 0.3),
        Vector2(engine_pos_x - length*0.1,  housing_width * 0.3), Vector2(engine_pos_x + length*0.05,  housing_width * 0.5)
    ])
    draw_colored_polygon(housing_points, housing_color)

    # Engine glow - more pronounced
    if energy_ratio > 0.05: # Only glow if some energy
        var glow_base_radius = width * 0.25 * current_scale
        var core_color = ship_colors.engine_core.lerp(Color.WHITE, energy_ratio * 0.5)
        core_color.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.005) # Pulsing alpha
        
        var outer_glow_color = ship_colors.engine_glow
        outer_glow_color.a = (0.4 + 0.2 * sin(Time.get_ticks_msec() * 0.005 + 1.0)) * energy_ratio

        # Draw multiple circles for a softer glow
        draw_circle(Vector2(engine_pos_x - length*0.08, 0), glow_base_radius * (0.5 + energy_ratio*0.5) * 1.5, outer_glow_color)
        draw_circle(Vector2(engine_pos_x - length*0.07, 0), glow_base_radius * (0.5 + energy_ratio*0.5), core_color)
        draw_circle(Vector2(engine_pos_x - length*0.06, 0), glow_base_radius * (0.5 + energy_ratio*0.5) * 0.5, core_color.lightened(0.3))


func draw_cockpit_area(energy_ratio: float):
    var length = ship_base_length * current_scale
    var width = ship_base_width * current_scale
    var cockpit_pos_x = length * 0.3 # Towards the front

    var cockpit_color = ship_colors.hull_accent.lightened(0.1)
    if energy_ratio < 0.3: cockpit_color = cockpit_color.darkened(0.3)
    if energy_ratio < 0.1: cockpit_color = ship_colors.dead_color.lightened(0.1)

    var cockpit_radius = width * 0.15 * current_scale
    draw_circle(Vector2(cockpit_pos_x, 0), cockpit_radius, cockpit_color)
    # A small highlight
    draw_circle(Vector2(cockpit_pos_x + cockpit_radius*0.2, -cockpit_radius*0.2), cockpit_radius * 0.3, cockpit_color.lightened(0.3))


func draw_hull_details(energy_ratio: float):
    var length = ship_base_length * current_scale
    # var width = ship_base_width * current_scale # Not used here directly

    var detail_color = ship_colors.hull_primary.darkened(0.2)
    if energy_ratio < 0.2: detail_color = ship_colors.dead_color.lightened(0.2)

    # Example panel lines (subtle)
    draw_line(Vector2(length * 0.1, -ship_base_width*0.1*current_scale), Vector2(-length*0.2, -ship_base_width*0.15*current_scale), detail_color, 0.5 * current_scale, true)
    draw_line(Vector2(length * 0.1,  ship_base_width*0.1*current_scale), Vector2(-length*0.2,  ship_base_width*0.15*current_scale), detail_color, 0.5 * current_scale, true)


func draw_status_indicators(energy_ratio: float):
    var length = ship_base_length * current_scale
    var width = ship_base_width * current_scale
    
    var indicator_size = Config.Visualization.PROBE_SIZE_PX * 0.15 * current_scale
    indicator_size = max(1.0, indicator_size) # Ensure minimum visible size

    var indicator_color: Color
    if energy_ratio > 0.7:
        indicator_color = ship_colors.energy_high
    elif energy_ratio > 0.3:
        indicator_color = ship_colors.energy_medium
    else:
        indicator_color = ship_colors.energy_low

    # Pulsing effect for alive probes
    var pulse = (sin(Time.get_ticks_msec() * 0.006) + 1.0) / 2.0 # 0 to 1
    indicator_color.a = 0.5 + 0.5 * pulse

    # Positions for indicators (example: on the sides)
    var indicator_positions = [
        Vector2(length * 0.0, -width * 0.25),
        Vector2(length * 0.0,  width * 0.25),
        Vector2(-length * 0.3, 0) # Rear indicator
    ]
    for pos in indicator_positions:
        draw_circle(pos, indicator_size, indicator_color)
        draw_circle(pos, indicator_size*0.5, indicator_color.lightened(0.4)) # Inner highlight


# Helper to set the probe node this renderer should draw
func set_target_probe(p_probe_node: Node):
    probe_node = p_probe_node
    queue_redraw()

func update_render_scale(new_scale: float):
    current_scale = new_scale
    queue_redraw()