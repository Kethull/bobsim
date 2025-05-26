extends Node2D
class_name VisualEffectsManager # Renamed to avoid conflict

var starfield_node: StarField # To hold the instance of our StarField class

# Store active beam effects if they need to persist or be managed
# For now, these are drawn instantaneously when called.
# If beams need to animate over time independently, they'd need more state.

func _ready():
    starfield_node = StarField.new() # Create an instance of StarField
    # Configure starfield if needed, e.g., world size based on current game world
    # starfield_node.update_world_dimensions(Config.World.WIDTH_SIM, Config.World.HEIGHT_SIM)
    add_child(starfield_node)
    starfield_node.owner = self # Ensure it's saved with the scene if this VisualEffectsManager is part of a scene.
    
    # Move starfield to the back visually
    starfield_node.z_index = -100


# This node will use its own _draw() for beams, or beams can be separate Node2Ds.
# For simplicity, let's assume this node itself will draw the beams when requested.
# This means draw_mining_beam etc. should call queue_redraw() and store beam data if it persists.
# However, the original design implies they are immediate mode drawing calls.

# --- Beam Drawing Methods ---
# These methods are called by other systems (e.g., Probe or SolarSystem)
# They will add to a list of "active effects" that are then drawn in _draw().
# This is a more robust way than direct draw calls from other scripts.

var active_mining_beams: Array[Dictionary] = [] # {"start": Vector2, "end": Vector2, "intensity": float, "time": float}
var active_comm_beams: Array[Dictionary] = []   # {"start": Vector2, "end": Vector2, "intensity": float, "time": float}
var active_resource_glows: Array[Dictionary] = [] # {"pos": Vector2, "radius": float, "intensity": float, "time": float}

func _process(delta: float):
    # Update timers for effects or remove old ones
    var current_time = Time.get_ticks_msec() / 1000.0
    
    active_mining_beams = актив_effects_update(active_mining_beams, current_time, delta)
    active_comm_beams = актив_effects_update(active_comm_beams, current_time, delta)
    active_resource_glows = актив_effects_update(active_resource_glows, current_time, delta)
    
    if active_mining_beams.size() > 0 or active_comm_beams.size() > 0 or active_resource_glows.size() > 0:
        queue_redraw()

func актив_effects_update(effects_array: Array, current_time: float, delta: float) -> Array:
    var still_active = []
    for effect in effects_array:
        effect.time_elapsed = effect.get("time_elapsed", 0.0) + delta
        if effect.time_elapsed < effect.duration:
            still_active.append(effect)
    return still_active

# --- Public methods to request drawing effects ---

func request_mining_beam(start_pos: Vector2, end_pos: Vector2, intensity: float = 1.0, duration: float = 0.2):
    if start_pos.is_equal_approx(end_pos): return
    active_mining_beams.append({
        "start": start_pos, "end": end_pos, "intensity": intensity, 
        "start_time": Time.get_ticks_msec() / 1000.0, "duration": duration, "time_elapsed": 0.0
    })
    queue_redraw()

func request_communication_beam(start_pos: Vector2, end_pos: Vector2, intensity: float = 1.0, duration: float = 0.5):
    if start_pos.is_equal_approx(end_pos): return
    active_comm_beams.append({
        "start": start_pos, "end": end_pos, "intensity": intensity,
        "start_time": Time.get_ticks_msec() / 1000.0, "duration": duration, "time_elapsed": 0.0
    })
    queue_redraw()
    
func request_resource_glow(pos: Vector2, radius: float, intensity: float, duration: float = 0.3):
    if radius <= 1 or intensity < 0.05: return
    active_resource_glows.append({
        "pos": pos, "radius": radius, "intensity": intensity,
        "start_time": Time.get_ticks_msec() / 1000.0, "duration": duration, "time_elapsed": 0.0
    })
    queue_redraw()


func _draw():
    var current_time_msec = Time.get_ticks_msec()

    for beam_data in active_mining_beams:
        draw_actual_mining_beam(beam_data.start, beam_data.end, beam_data.intensity, current_time_msec, beam_data.time_elapsed / beam_data.duration)
        
    for beam_data in active_comm_beams:
        draw_actual_communication_beam(beam_data.start, beam_data.end, beam_data.intensity, current_time_msec, beam_data.time_elapsed / beam_data.duration)

    for glow_data in active_resource_glows:
        draw_actual_resource_glow(glow_data.pos, glow_data.radius, glow_data.intensity, current_time_msec, glow_data.time_elapsed / glow_data.duration)


func draw_actual_mining_beam(start_pos: Vector2, end_pos: Vector2, intensity: float, time_msec: float, effect_progress: float):
    var pulse = (sin(time_msec * 0.02) + 1.0) / 2.0 # 0 to 1, faster pulse
    var current_intensity = intensity * (0.6 + 0.4 * pulse) * (1.0 - effect_progress) # Fade out
    if current_intensity < 0.05: return

    var core_color = Color(0.1, 1.0, 0.3, current_intensity * 0.8)
    var glow_color = Color(0.3, 1.0, 0.5, current_intensity * 0.4)
    
    draw_line(start_pos, end_pos, core_color, 2.0 * current_intensity + 1.0, true)
    draw_line(start_pos, end_pos, glow_color, 4.0 * current_intensity + 2.0, true)
    
    var impact_radius = (3.0 + 5.0 * pulse) * current_intensity
    draw_circle(end_pos, impact_radius, glow_color)
    draw_circle(end_pos, impact_radius * 0.5, core_color.lightened(0.2))


func draw_actual_communication_beam(start_pos: Vector2, end_pos: Vector2, intensity: float, time_msec: float, effect_progress: float):
    var base_alpha = intensity * (1.0 - effect_progress)
    if base_alpha < 0.05: return
    
    var direction = (end_pos - start_pos).normalized()
    var distance = start_pos.distance_to(end_pos)

    # Base static line (faint)
    draw_line(start_pos, end_pos, Color(0.7, 0.9, 1.0, base_alpha * 0.2), 1.0, true)

    # Animated data packets
    var num_packets = 3
    for i in range(num_packets):
        var packet_phase = fmod((time_msec * 0.003 + float(i) / num_packets + effect_progress * 0.5), 1.0)
        var packet_pos = start_pos.lerp(end_pos, packet_phase)
        
        var packet_size = (2.0 + intensity) * (1.0 - abs(packet_phase - 0.5)*1.5) # Smaller at ends
        packet_size = max(1.0, packet_size)

        var packet_color = Color(0.8, 0.95, 1.0, base_alpha * 0.9)
        var packet_glow = Color(0.6, 0.8, 1.0, base_alpha * 0.5)
        
        draw_circle(packet_pos, packet_size * 1.5, packet_glow)
        draw_circle(packet_pos, packet_size, packet_color)


func draw_actual_resource_glow(pos: Vector2, radius: float, intensity: float, time_msec: float, effect_progress: float):
    var base_alpha = intensity * (1.0 - effect_progress)
    if base_alpha < 0.05: return

    var pulse = (sin(time_msec * 0.003 + pos.x * 0.01) + 1.0) / 2.0 # Add spatial variation to pulse
    var current_radius_factor = 0.8 + 0.4 * pulse
    
    var base_color = Color(0.1, 0.9, 0.2) # Greener
    
    var outer_glow_alpha = base_alpha * (0.2 + 0.2 * pulse)
    var inner_glow_alpha = base_alpha * (0.4 + 0.3 * pulse)

    draw_circle(pos, radius * current_radius_factor * 1.2, Color(base_color.r, base_color.g, base_color.b, outer_glow_alpha))
    draw_circle(pos, radius * current_radius_factor * 0.7, Color(base_color.r, base_color.g, base_color.b, inner_glow_alpha))
    draw_circle(pos, radius * current_radius_factor * 0.4, Color(base_color.r, base_color.g, base_color.b, inner_glow_alpha * 1.2).lightened(0.2))


# Method to link the StarField to a camera, usually called from Main.gd
func set_starfield_camera(camera: Camera2D):
    if is_instance_valid(starfield_node):
        starfield_node.set_target_camera(camera)