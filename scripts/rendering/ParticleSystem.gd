extends Node2D
class_name ParticleSystemManager # Renamed to avoid conflict if "ParticleSystem" is a Godot built-in or common name

# Preload the Particle script if it's a resource, or ensure it's globally available
# const ParticleEffect = preload("res://scripts/rendering/Particle.gd") # If Particle.gd is a Resource

var particle_pools: Dictionary = {
    "exhaust": [],
    "mining": [],
    "communication": [], # Example, not fully detailed in original doc
    "energy": []        # Example, not fully detailed in original doc
}
var active_particles: Array[Particle] = [] # Specify type for clarity
var max_particles_total: int = Config.Visualization.MAX_PARTICLES_PER_SYSTEM # Overall limit

func _ready():
    # Optionally pre-populate pools, though get_particle_from_pool handles creation
    pass

func _process(delta: float):
    # Update active particles
    var still_alive_particles: Array[Particle] = []
    for p_idx in range(active_particles.size() -1, -1, -1): # Iterate backwards for safe removal
        var particle: Particle = active_particles[p_idx]
        if particle and is_instance_valid(particle): # Check if particle object is valid
            particle.update(delta)
            if particle.is_alive():
                still_alive_particles.append(particle)
            else:
                return_particle_to_pool(particle)
        else:
            # This case should ideally not happen if list management is correct
            active_particles.remove_at(p_idx)


    active_particles = still_alive_particles
    active_particles.reverse() # Reverse back to original order if needed, though order might not matter for drawing

    queue_redraw() # Request a redraw to show updated particle positions

func get_particle_from_pool(type: String) -> Particle:
    if type in particle_pools and not particle_pools[type].is_empty():
        var p: Particle = particle_pools[type].pop_back()
        p.reset() # Ensure it's in a clean state
        return p
    else:
        # Create a new particle if pool is empty
        var new_p = Particle.new() # Assumes Particle.gd is a class_name Particle
        new_p.particle_type = type # Set type early
        return new_p

func return_particle_to_pool(particle: Particle):
    if particle and is_instance_valid(particle):
        particle.reset()
        if particle.particle_type in particle_pools:
            particle_pools[particle.particle_type].append(particle)
        # else: # Optionally, handle unknown particle types or just let them be freed

# --- Emitter Functions ---

func emit_thruster_exhaust(pos: Vector2, angle_rad: float, intensity_factor: float):
    if active_particles.size() >= max_particles_total:
        return

    # Intensity factor could be thrust_level / max_thrust_level
    var count = clamp(int(intensity_factor * 15.0) + 2, 1, 20) # Number of particles based on intensity

    for _i in range(count):
        if active_particles.size() >= max_particles_total: break
        
        var p = get_particle_from_pool("exhaust")
        
        var spread = randf_range(-PI / 12.0, PI / 12.0) # +/- 15 degrees spread
        var particle_angle = angle_rad + PI + spread # Exhaust goes opposite to ship's angle
        var speed = randf_range(80.0, 200.0) * (0.5 + intensity_factor * 0.5) # Speed also affected by intensity
        
        p.position = pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)) # Slight random offset from emitter
        p.velocity = Vector2(cos(particle_angle), sin(particle_angle)) * speed
        p.life = randf_range(0.3, 1.2) * (0.7 + intensity_factor * 0.3)
        p.max_life = p.life
        p.size = randf_range(1.5, 4.0) * (0.6 + intensity_factor * 0.4)
        p.color = Color(1.0, randf_range(0.5, 0.8), 0.2, randf_range(0.6, 0.9)) # Fiery orange/yellow
        p.friction = 0.05 # Exhaust particles might slow down
        
        active_particles.append(p)

func emit_mining_sparks(pos: Vector2, intensity_factor: float = 1.0):
    if active_particles.size() >= max_particles_total:
        return
        
    var count = clamp(int(intensity_factor * 10.0) + 3, 2, 15)
    for _i in range(count):
        if active_particles.size() >= max_particles_total: break
        
        var p = get_particle_from_pool("mining")
        
        var angle = randf() * TAU # Sparks fly in all directions
        var speed = randf_range(40.0, 120.0) * intensity_factor
        
        p.position = pos + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
        p.velocity = Vector2(cos(angle), sin(angle)) * speed
        p.life = randf_range(0.2, 0.8)
        p.max_life = p.life
        p.size = randf_range(1.0, 3.0)
        p.color = Color(randf_range(0.8,1.0), randf_range(0.8,1.0), randf_range(0.4,0.7), 1.0) # Bright yellow/white sparks
        p.friction = 0.1
        
        active_particles.append(p)

# --- Drawing ---
func _draw():
    for particle in active_particles:
        if particle and particle.is_alive(): # Redundant check if list management is perfect, but safe
            draw_single_particle(particle)

func draw_single_particle(p: Particle):
    var alpha_ratio = clamp(p.life / p.max_life, 0.0, 1.0) # Fade out as life diminishes
    var current_color = Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha_ratio * alpha_ratio) # Sharper alpha falloff
    var current_size = p.size * alpha_ratio # Particles might also shrink as they fade

    if current_size < 0.1: return

    # Simple circle drawing, can be replaced with draw_texture for sprites
    if p.particle_type == "exhaust":
        # Exhaust might have a more complex look, e.g., a brighter core
        var core_color = Color(current_color.r, current_color.g, current_color.b, current_color.a * 0.5)
        core_color = core_color.lerp(Color.WHITE, 0.3)
        draw_circle(p.position, current_size * 0.5, core_color.lightened(0.2))
        draw_circle(p.position, current_size, current_color)
    elif p.particle_type == "mining":
        draw_circle(p.position, current_size, current_color)
        # Could add a smaller, brighter dot for a "spark" look
        draw_circle(p.position, current_size * 0.3, current_color.lightened(0.5))
    else: # Default particle drawing
        draw_circle(p.position, current_size, current_color)