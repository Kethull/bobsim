extends Node2D
class_name ParticleEffect

signal effect_finished

# Duration and active state tracking
var duration: float = 2.0
var is_active_effect: bool = false
var auto_queue_free: bool = false

# Call this when the particle effect should start
func play():
    is_active_effect = true
    
    # Handle GPU particles
    if has_node("GPUParticles2D"):
        var particles = get_node("GPUParticles2D")
        particles.emitting = true
        
        # Connect to finished signal if available, otherwise use timer
        if particles.has_signal("finished"):
            if not particles.is_connected("finished", _on_particles_finished):
                particles.finished.connect(_on_particles_finished)
        else:
            var timer = get_tree().create_timer(duration)
            timer.timeout.connect(_on_particles_finished)
    
    # Handle CPU particles
    elif has_node("CPUParticles2D"):
        var particles = get_node("CPUParticles2D")
        particles.emitting = true
        
        # Connect to finished signal if available, otherwise use timer
        if particles.has_signal("finished"):
            if not particles.is_connected("finished", _on_particles_finished):
                particles.finished.connect(_on_particles_finished)
        else:
            var timer = get_tree().create_timer(duration)
            timer.timeout.connect(_on_particles_finished)
    
    # Make effect visible
    visible = true

func is_active() -> bool:
    # Check if the effect is marked as active
    if not is_active_effect:
        return false
    
    # Also check if particles are still emitting
    if has_node("GPUParticles2D"):
        var particles = get_node("GPUParticles2D")
        return is_active_effect and (particles.emitting or particles.get_child_count() > 0)
    elif has_node("CPUParticles2D"):
        var particles = get_node("CPUParticles2D")
        return is_active_effect and (particles.emitting or particles.get_child_count() > 0)
    
    return is_active_effect

func _on_particles_finished():
    # Mark effect as inactive
    is_active_effect = false
    
    # Hide the effect
    visible = false
    
    # Emit signal for manager to handle
    effect_finished.emit()
    
    # Queue for deletion if configured
    if auto_queue_free:
        queue_free()

# Setup methods for different effect types
func setup_thruster_effect(position: Vector2, direction: Vector2, intensity: float):
    global_position = position
    rotation = direction.angle() + PI/2
    
    # Configure particles based on intensity
    if has_node("GPUParticles2D"):
        var particles = get_node("GPUParticles2D")
        var material = particles.process_material
        if material:
            material.initial_velocity_min = 50.0 * intensity
            material.initial_velocity_max = 150.0 * intensity
        particles.amount_ratio = intensity
    elif has_node("CPUParticles2D"):
        var particles = get_node("CPUParticles2D")
        particles.initial_velocity_min = 50.0 * intensity
        particles.initial_velocity_max = 150.0 * intensity
        particles.amount_ratio = intensity
    
    is_active_effect = true
    play()

func setup_mining_effect(start_pos: Vector2, target_pos: Vector2, intensity: float):
    global_position = target_pos
    
    # Configure mining particles
    if has_node("GPUParticles2D"):
        var particles = get_node("GPUParticles2D")
        var material = particles.process_material
        if material:
            material.emission_sphere_radius = 5.0 * intensity
            
            # Set color based on intensity
            var color = Color.GREEN.lerp(Color.YELLOW, intensity)
            material.color = color
            
        particles.amount_ratio = intensity
    elif has_node("CPUParticles2D"):
        var particles = get_node("CPUParticles2D")
        particles.emission_sphere_radius = 5.0 * intensity
        
        # Set color based on intensity
        var color = Color.GREEN.lerp(Color.YELLOW, intensity)
        particles.color = color
        
        particles.amount_ratio = intensity
    
    # Create a line from start to target
    if has_node("Line2D"):
        var line = get_node("Line2D")
        line.clear_points()
        line.add_point(to_local(start_pos))
        line.add_point(to_local(target_pos))
        line.default_color = Color.GREEN
        line.width = 2.0 * intensity
        line.visible = true
    
    is_active_effect = true
    play()

func setup_communication_effect(start_pos: Vector2, end_pos: Vector2):
    global_position = start_pos
    
    # Calculate direction and distance
    var direction = end_pos - start_pos
    var distance = direction.length()
    
    # Configure beam effect
    if has_node("Line2D"):
        var line = get_node("Line2D")
        line.clear_points()
        line.add_point(Vector2.ZERO)
        line.add_point(direction)
        line.default_color = Color.BLUE
        line.width = 2.0
        line.visible = true
    
    # Configure particles to follow the beam
    if has_node("GPUParticles2D"):
        var particles = get_node("GPUParticles2D")
        var material = particles.process_material
        if material:
            material.emission_box_extents = Vector3(distance/2, 5, 1)
            material.direction = Vector3(direction.normalized().x, direction.normalized().y, 0)
            material.initial_velocity_min = distance / 2.0
            material.initial_velocity_max = distance
    elif has_node("CPUParticles2D"):
        var particles = get_node("CPUParticles2D")
        particles.emission_rect_extents = Vector2(distance/2, 5)
        particles.direction = direction.normalized()
        particles.initial_velocity_min = distance / 2.0
        particles.initial_velocity_max = distance
    
    is_active_effect = true
    play()