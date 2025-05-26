extends Node2D
class_name CelestialBody

@export var body_name: String = "UnnamedBody"
@export var mass_kg: float = 1.0e20
@export var radius_km: float = 1000.0
@export var display_radius_sim: float = 50.0 # Visual radius in simulation units
@export var color: Color = Color.GRAY

# Orbital elements (relevant if this body orbits another)
@export var semi_major_axis_au: float = 0.0
@export var eccentricity: float = 0.0
@export var inclination_deg: float = 0.0
@export var longitude_of_ascending_node_deg: float = 0.0
@export var argument_of_perihelion_deg: float = 0.0
@export var mean_anomaly_at_epoch_deg: float = 0.0
@export var central_body_name: String = "" # Name of the body it orbits, if any

# Physics state variables
var velocity: Vector2 = Vector2.ZERO  # In simulation units per second
var previous_acceleration: Vector2 = Vector2.ZERO # In simulation units per second^2
var orbit_path: Array[Vector2] = []
var max_orbit_points: int = Config.Visualization.MAX_ORBIT_PATH_POINTS

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_renderer: TrailRenderer = $TrailRenderer # Ensure this node exists in CelestialBody.tscn

func _ready():
    # Set mass_kg as metadata for easy access by OrbitalMechanics
    set_meta("mass_kg", mass_kg)
    
    setup_visual()
    setup_physics_properties() # Renamed from setup_physics to avoid conflict with Node._physics_process
    
    if trail_renderer:
        trail_renderer.set_trail_properties(color.lightened(0.3), 1.0, max_orbit_points)


func setup_visual():
    if not sprite:
        printerr("CelestialBody '%s': Sprite2D node not found!" % body_name)
        return

    var texture = create_circle_texture(display_radius_sim, color)
    sprite.texture = texture
    # The sprite itself should be centered. Its scale can be 1 if texture is right size.
    sprite.scale = Vector2.ONE 
    # To make the display_radius_sim effective, the texture itself is created with that radius.
    # The CollisionShape2D for Area2D should also match this display_radius_sim.


func create_circle_texture(radius: float, body_color: Color) -> ImageTexture:
    var diameter = int(max(1.0, radius * 2.0)) # Ensure diameter is at least 1
    var image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
    
    var center = Vector2(float(diameter) / 2.0, float(diameter) / 2.0)
    
    for y in range(diameter):
        for x in range(diameter):
            var current_pos = Vector2(float(x) + 0.5, float(y) + 0.5) # Use pixel center
            var dist_from_center = current_pos.distance_to(center)
            
            if dist_from_center <= radius:
                # Simple alpha, could be smoother (e.g., quadratic falloff)
                var alpha = 1.0 - clamp( (dist_from_center / radius) * 0.3, 0.0, 1.0) # Slight fade at edges
                image.set_pixel(x, y, Color(body_color.r, body_color.g, body_color.b, alpha))
            else:
                image.set_pixel(x, y, Color(0,0,0,0)) # Transparent outside circle
                
    var texture = ImageTexture.create_from_image(image)
    return texture

func setup_physics_properties():
    previous_acceleration = Vector2.ZERO
    # Velocity will be set by SolarSystem or initial conditions

func add_to_orbit_path(pos: Vector2):
    orbit_path.append(pos)
    if orbit_path.size() > max_orbit_points:
        orbit_path.pop_front()
    
    if trail_renderer and is_instance_valid(trail_renderer):
        trail_renderer.update_trail(orbit_path)

func get_data_dict() -> Dictionary:
    return {
        "name": body_name,
        "mass_kg": mass_kg,
        "radius_km": radius_km,
        "display_radius_sim": display_radius_sim,
        "color": color,
        "semi_major_axis_au": semi_major_axis_au,
        "eccentricity": eccentricity,
        "inclination_deg": inclination_deg,
        "longitude_of_ascending_node_deg": longitude_of_ascending_node_deg,
        "argument_of_perihelion_deg": argument_of_perihelion_deg,
        "mean_anomaly_at_epoch_deg": mean_anomaly_at_epoch_deg,
        "central_body": central_body_name,
        "position_sim": global_position, # Current sim position
        "velocity_sim_s": velocity # Current sim velocity (units/sec)
    }

# Call this if parameters like display_radius_sim or color change dynamically
func update_visuals():
    setup_visual()
    if trail_renderer:
        trail_renderer.set_trail_properties(color.lightened(0.3), 1.0, max_orbit_points)

# Example for Area2D setup (to be done in editor, but shape needs to be configured)
# func _enter_tree():
#   var collision_shape = $Area2D/CollisionShape2D
#   if collision_shape:
#       var shape = CircleShape2D.new()
#       shape.radius = display_radius_sim
#       collision_shape.shape = shape