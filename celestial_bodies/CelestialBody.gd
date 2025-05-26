# CelestialBody.gd
extends RigidBody2D
class_name CelestialBody

# ConfigManager is an AutoLoad, no need for direct node reference.

@export_group("Physical Properties")
@export var body_name: String = ""
@export var mass_kg: float = 0.0
@export var radius_km: float = 0.0
@export var display_radius: float = 50.0
@export var body_color: Color = Color.WHITE

@export_group("Orbital Elements (J2000.0)")
@export var semi_major_axis_au: float = 0.0
@export var eccentricity: float = 0.0
@export var inclination_deg: float = 0.0
@export var longitude_ascending_node_deg: float = 0.0
@export var argument_perihelion_deg: float = 0.0
@export var mean_anomaly_epoch_deg: float = 0.0
@export var central_body_name: String = ""

@onready var visual_component: Node2D = $VisualComponent
@onready var orbit_trail: Line2D = $OrbitTrail
@onready var gravity_field: Area2D = $GravityField
@onready var atmosphere_glow: Sprite2D = $VisualComponent/AtmosphereGlow

var orbit_points: Array[Vector2] = []
var previous_acceleration: Vector2 = Vector2.ZERO
var central_body: CelestialBody = null

signal body_clicked(body: CelestialBody)

func _ready():
    # Configure physics
    gravity_scale = 0  # We handle our own gravity
    set_collision_layer_value(1, true)  # Celestial bodies layer
    set_collision_mask_value(2, true)   # Interact with probes
    
    # Setup visual appearance
    setup_visual_appearance()
    
    # Initialize orbital mechanics
    calculate_initial_state()
    
    # Connect signals
    input_event.connect(_on_input_event)

func setup_visual_appearance():
    var sprite = $VisualComponent/BodySprite
    sprite.modulate = body_color
    
    # Scale sprite to match display radius
    var texture_size = sprite.texture.get_size()
    var scale_factor = (display_radius * 2) / max(texture_size.x, texture_size.y)
    sprite.scale = Vector2.ONE * scale_factor
    
    # Setup atmosphere glow if applicable
    if body_name in ["Earth", "Venus", "Jupiter", "Saturn"]:
        atmosphere_glow.modulate = body_color * 0.3
        atmosphere_glow.modulate.a = 0.5
        atmosphere_glow.scale = sprite.scale * 1.5

func calculate_initial_state():
    if central_body_name.is_empty() or body_name == "Sun":
        return  # Sun or bodies without central body
    
    # Find central body
    central_body = find_central_body()
    if not central_body:
        push_error("Central body not found: " + central_body_name)
        return
    
    # Calculate initial position and velocity using orbital elements
    var state = calculate_state_from_orbital_elements()
    global_position = central_body.global_position + state.position
    linear_velocity = state.velocity

func calculate_state_from_orbital_elements() -> Dictionary:
    # Convert AU to simulation units
    var a_sim = semi_major_axis_au * ConfigManager.config.au_scale
    var mu = ConfigManager.config.gravitational_constant * central_body.mass_kg
    
    # Solve Kepler's equation
    var M_rad = deg_to_rad(mean_anomaly_epoch_deg)
    var E_rad = solve_kepler_equation(M_rad, eccentricity)
    
    # Calculate true anomaly
    var nu_rad = 2.0 * atan2(
        sqrt(1.0 + eccentricity) * sin(E_rad / 2.0),
        sqrt(1.0 - eccentricity) * cos(E_rad / 2.0)
    )
    
    # Calculate distance
    var r = a_sim * (1.0 - eccentricity * cos(E_rad))
    
    # Position in orbital plane
    var x_orb = r * cos(nu_rad)
    var y_orb = r * sin(nu_rad)
    
    # Velocity in orbital plane
    var sqrt_mu_a = sqrt(mu * a_sim)
    var vx_orb = -sqrt_mu_a * sin(E_rad) / r
    var vy_orb = sqrt_mu_a * sqrt(1.0 - eccentricity * eccentricity) * cos(E_rad) / r
    
    # Transform from orbital plane to simulation plane (simplified 2D)
    var angle_sum = deg_to_rad(argument_perihelion_deg + longitude_ascending_node_deg)
    var cos_angle = cos(angle_sum)
    var sin_angle = sin(angle_sum)
    
    var position = Vector2(
        cos_angle * x_orb - sin_angle * y_orb,
        sin_angle * x_orb + cos_angle * y_orb
    )
    
    var velocity = Vector2(
        cos_angle * vx_orb - sin_angle * vy_orb,
        sin_angle * vx_orb + cos_angle * vy_orb
    )
    
    return {"position": position, "velocity": velocity}

func solve_kepler_equation(M: float, e: float, tolerance: float = 1e-10) -> float:
    var E = M + e * sin(M)  # Initial guess
    
    for i in range(100):  # Max iterations
        var f = E - e * sin(E) - M
        var f_prime = 1.0 - e * cos(E)
        
        if abs(f) < tolerance:
            break
            
        if abs(f_prime) < 1e-12:
            break  # Avoid division by zero
            
        E = E - f / f_prime
    
    return E

func _integrate_forces(state: PhysicsDirectBodyState2D):
    # Calculate gravitational forces from all other celestial bodies
    var total_force = Vector2.ZERO
    
    for body in get_tree().get_nodes_in_group("celestial_bodies"):
        if body == self:
            continue
            
        var celestial_body = body as CelestialBody
        if not celestial_body:
            continue
            
        var distance_vector = celestial_body.global_position - global_position
        var distance_sq = distance_vector.length_squared()
        
        if distance_sq < 1e-6:  # Avoid division by zero
            continue
            
        var force_magnitude = ConfigManager.config.gravitational_constant * mass_kg * celestial_body.mass_kg / distance_sq
        var force_direction = distance_vector.normalized()
        total_force += force_direction * force_magnitude
    
    # Apply gravitational force
    state.apply_central_force(total_force)
    
    # Store acceleration for Verlet integration
    previous_acceleration = total_force / mass_kg

func _physics_process(_delta):
    # Update orbit trail
    update_orbit_trail()
    
    # Check for probe interactions in gravity field
    check_gravity_field_interactions()

func update_orbit_trail():
    orbit_points.append(global_position)
    
    # Limit trail length
    while orbit_points.size() > ConfigManager.config.max_orbit_points:
        orbit_points.pop_front()
    
    # Update Line2D points
    orbit_trail.clear_points()
    for point in orbit_points:
        orbit_trail.add_point(point)

func check_gravity_field_interactions():
    # Apply gravitational influence to probes in range
    var bodies = gravity_field.get_overlapping_bodies()
    for body in bodies:
        if body is Probe:
            var probe: Probe = body as Probe
            var distance_vector = global_position - probe.global_position
            var distance = distance_vector.length()
            
            if distance > 0:
                var force_magnitude = ConfigManager.config.gravitational_constant * mass_kg * probe.mass / (distance * distance)
                var force = distance_vector.normalized() * force_magnitude
                probe.apply_external_force(force, "gravity_" + body_name)

func find_central_body() -> CelestialBody:
    for body in get_tree().get_nodes_in_group("celestial_bodies"):
        var celestial_body = body as CelestialBody
        if celestial_body and celestial_body.body_name == central_body_name:
            return celestial_body
    return null

func _on_input_event(_viewport, event, _shape_idx):
    if event is InputEventMouseButton and event.pressed:
        body_clicked.emit(self)