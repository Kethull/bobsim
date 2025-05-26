extends RefCounted # Using RefCounted for manual memory management if pooled, or just for data structure
class_name Particle

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var life: float = 0.0 # Current remaining lifetime
var max_life: float = 1.0 # Initial lifetime
var size: float = 1.0
var color: Color = Color.WHITE
var particle_type: String = "generic" # e.g., "exhaust", "mining", "energy"
var rotation: float = 0.0 # Optional rotation for sprite-based particles
var angular_velocity: float = 0.0 # Optional

# Type-specific properties, can be expanded
var temperature: float = 3000.0 # Example for exhaust
var gravity_affected: bool = false
var friction: float = 0.01 # General friction/drag factor (e.g., 0.01 means 1% velocity reduction per update)

func _init(p_pos: Vector2 = Vector2.ZERO, p_vel: Vector2 = Vector2.ZERO, p_life: float = 1.0, p_size: float = 1.0, p_color: Color = Color.WHITE, p_type: String = "generic"):
    position = p_pos
    velocity = p_vel
    life = p_life
    max_life = p_life
    size = p_size
    color = p_color
    particle_type = p_type

func update(delta: float):
    if not is_alive():
        return

    life -= delta
    if life <= 0:
        return

    position += velocity * delta
    rotation += angular_velocity * delta

    # Apply friction/drag
    if friction > 0:
        velocity *= (1.0 - friction * delta) # Scale friction by delta

    # Type-specific updates
    match particle_type:
        "exhaust":
            # Example: exhaust particles might cool down and shrink
            temperature = max(300.0, temperature * (1.0 - 0.8 * delta)) # Cools down
            size = max(0.1, size * (1.0 - 0.5 * delta)) # Shrinks
            # Velocity might also be affected by expansion or specific drag
            velocity *= (1.0 - 0.1 * delta) # Slight specific drag for exhaust
        "mining":
            size = max(0.1, size * (1.0 - 0.7 * delta)) # Mining sparks fade quickly
            velocity *= (1.0 - 0.2 * delta)
        "energy":
            size = max(0.1, size * (1.0 - 0.3 * delta))
        _: # Default case
            pass 
            
    if gravity_affected:
        velocity.y += 98.0 * delta # Simple downward gravity (adjust value as needed for sim scale)


func is_alive() -> bool:
    return life > 0 and size > 0.05 # Consider size as well, very small particles might be considered dead

func reset():
    position = Vector2.ZERO
    velocity = Vector2.ZERO
    life = 0.0
    max_life = 0.0
    size = 0.0
    color = Color.WHITE
    particle_type = "generic"
    rotation = 0.0
    angular_velocity = 0.0
    temperature = 3000.0
    gravity_affected = false
    friction = 0.01