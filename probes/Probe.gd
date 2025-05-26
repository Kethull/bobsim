extends RigidBody2D
class_name Probe


@export_group("Probe Properties")
@export var probe_id: int = 0
@export var generation: int = 0

@export_group("Energy System")
@export var max_energy: float = 100000.0
@export var current_energy: float = 90000.0
@export var energy_decay_rate: float = 0.001

@export_group("Movement")
@export var max_velocity: float = 10000.0
@export var max_angular_velocity: float = PI / 4
@export var moment_of_inertia: float = 5.0

@onready var visual_component: Node2D = $VisualComponent
@onready var thruster_system: Node2D = $ThrusterSystem
@onready var sensor_array: Area2D = $SensorArray
@onready var communication_range: Area2D = $CommunicationRange
@onready var movement_trail: Line2D = $MovementTrail
@onready var mining_laser: Line2D = $MiningLaser
@onready var ai_agent: Node = $AIAgent
@onready var energy_system: Node = $EnergySystem
@onready var audio_component: AudioStreamPlayer2D = $AudioComponent

# State variables
var is_alive: bool = true
var is_mining: bool = false
var is_thrusting: bool = false
var is_communicating: bool = false
var current_target_id: int = -1
var current_task: String = "idle"

# Action state for RL
var current_thrust_level: int = 0
var current_torque_level: int = 0
var thrust_ramp_ratio: float = 0.0
var rotation_ramp_ratio: float = 0.0
var steps_in_current_thrust: int = 0
var steps_in_current_rotation: int = 0
var last_action_timestamp: int = -1
var target_resource_idx: int = -1
var time_since_last_target_switch: int = 0
var last_thrust_application_step: int = -1

# External forces (from celestial bodies)
var external_forces: Dictionary = {}

# Trail points
var trail_points: Array[Vector2] = []

# Signals
signal probe_destroyed(probe: Probe)
signal resource_discovered(probe: Probe, resource_position: Vector2, amount: float)
signal communication_sent(from_probe: Probe, to_position: Vector2, message_type: String)
signal replication_requested(parent_probe: Probe)
signal energy_critical(probe: Probe, energy_level: float)

func _ready():
    # Configure physics
    gravity_scale = 0  # We handle our own gravity
    set_collision_layer_value(2, true)  # Probes layer
    set_collision_mask_value(1, true)   # Interact with celestial bodies
    set_collision_mask_value(3, true)   # Interact with resources
    mass = ConfigManager.config.probe_mass
    
    # Add to groups
    add_to_group("probes")
    
    # Initialize components
    setup_visual_appearance()
    setup_sensor_systems()
    setup_thruster_system()
    
    # Connect signals
    sensor_array.body_entered.connect(_on_sensor_body_entered)
    sensor_array.body_exited.connect(_on_sensor_body_exited)
    communication_range.area_entered.connect(_on_communication_range_entered)
    
    # Initialize AI agent
    ai_agent.initialize(self)

func setup_visual_appearance():
    # Configure probe visual based on generation and energy
    var base_color = Color.CYAN
    if generation > 0:
        base_color = base_color.lerp(Color.YELLOW, min(generation * 0.1, 0.5))
    
    var hull_sprite = visual_component.get_node("HullSprite")
    hull_sprite.modulate = base_color
    
    # Scale based on probe size config
    var scale_factor = ConfigManager.config.probe_size / 24.0  # Assuming base sprite is 24px
    visual_component.scale = Vector2.ONE * scale_factor

func setup_sensor_systems():
    # Configure sensor array range
    var sensor_shape = sensor_array.get_node("SensorShape") as CollisionShape2D
    var circle_shape = CircleShape2D.new()
    circle_shape.radius = ConfigManager.config.discovery_range
    sensor_shape.shape = circle_shape
    
    # Configure communication range
    var comm_shape = communication_range.get_node("CommShape") as CollisionShape2D
    var comm_circle = CircleShape2D.new()
    comm_circle.radius = ConfigManager.config.communication_range
    comm_shape.shape = comm_circle

func setup_thruster_system():
    # Configure all thruster particle systems
    var main_thruster = thruster_system.get_node("MainThruster") as GPUParticles2D
    configure_thruster_particles(main_thruster, Vector2(0, 1))  # Rear-facing
    
    # RCS thrusters
    configure_thruster_particles(thruster_system.get_node("RCSThrusterN"), Vector2(0, -1))
    configure_thruster_particles(thruster_system.get_node("RCSThrusterS"), Vector2(0, 1))
    configure_thruster_particles(thruster_system.get_node("RCSThrusterE"), Vector2(1, 0))
    configure_thruster_particles(thruster_system.get_node("RCSThrusterW"), Vector2(-1, 0))

func configure_thruster_particles(thruster: GPUParticles2D, direction: Vector2):
    var material = ParticleProcessMaterial.new()
    
    # Emission
    material.emission.amount = 50
    material.emission.rate = 50.0
    
    # Direction and velocity
    material.direction = Vector3(direction.x, direction.y, 0)
    material.initial_velocity_min = 50.0
    material.initial_velocity_max = 150.0
    material.angular_velocity_min = -180.0
    material.angular_velocity_max = 180.0
    
    # Scale and color
    material.scale_min = 0.3
    material.scale_max = 1.2
    material.color = Color.CYAN
    
    # Add color ramp for temperature effect
    var gradient = Gradient.new()
    gradient.add_point(0.0, Color.WHITE)
    gradient.add_point(0.3, Color.CYAN)
    gradient.add_point(0.7, Color.BLUE)
    gradient.add_point(1.0, Color.TRANSPARENT)
    
    var texture = GradientTexture1D.new()
    texture.gradient = gradient
    material.color_ramp = texture
    
    # Lifetime
    material.lifetime = 2.0
    
    thruster.process_material = material
    thruster.emitting = false

func _integrate_forces(state: PhysicsDirectBodyState2D):
    # Apply external forces (gravity from celestial bodies)
    var total_external_force = Vector2.ZERO
    for force_name in external_forces:
        total_external_force += external_forces[force_name]
    state.apply_central_force(total_external_force)
    
    # Apply thrust forces
    if is_thrusting and current_thrust_level > 0:
        var thrust_magnitude = ConfigManager.config.thrust_force_magnitudes[current_thrust_level]
        var thrust_force = Vector2(0, -thrust_magnitude).rotated(rotation)  # Forward direction
        thrust_force *= thrust_ramp_ratio
        state.apply_central_force(thrust_force)
        
        # Apply energy cost
        var energy_cost = thrust_magnitude * ConfigManager.config.thrust_energy_cost_factor
        consume_energy(energy_cost)
    
    # Apply torque for rotation
    if current_torque_level > 0:
        var torque_magnitude = ConfigManager.config.torque_magnitudes[current_torque_level]
        var applied_torque = torque_magnitude * rotation_ramp_ratio
        
        # Determine rotation direction based on AI action
        if ai_agent.current_rotation_direction > 0:
            applied_torque = -applied_torque  # Clockwise
        
        state.apply_torque(applied_torque)
        
        # Apply energy cost for rotation
        var energy_cost = torque_magnitude * 0.1  # Rotational energy cost factor
        consume_energy(energy_cost)
    
    # Limit velocities
    if state.linear_velocity.length() > max_velocity:
        state.linear_velocity = state.linear_velocity.normalized() * max_velocity
    
    if abs(state.angular_velocity) > max_angular_velocity:
        state.angular_velocity = sign(state.angular_velocity) * max_angular_velocity

func _physics_process(delta):
    # Update energy decay
    current_energy -= ConfigManager.config.energy_decay_rate * delta
    
    # Check for death
    if current_energy <= 0 and is_alive:
        die()
    
    # Update visual effects based on energy
    update_visual_effects()
    
    # Update movement trail
    update_movement_trail()
    
    # Update AI agent
    if is_alive:
        ai_agent.update_step(delta)
    
    # Update action smoothing
    update_action_smoothing(delta)
    
    # Check for low energy warning
    if current_energy < max_energy * 0.25 and is_alive:
        energy_critical.emit(self, current_energy)

func update_visual_effects():
    # Update status lights based on energy level
    var status_lights = visual_component.get_node("StatusLights")
    var energy_ratio = current_energy / max_energy
    
    for light in status_lights.get_children():
        var light_sprite = light as Sprite2D
        if energy_ratio < 0.1:
            light_sprite.modulate = Color.RED
        elif energy_ratio < 0.3:
            light_sprite.modulate = Color.YELLOW
        else:
            light_sprite.modulate = Color.GREEN
        
        # Pulsing effect for low energy
        if energy_ratio < 0.3:
            var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
            light_sprite.modulate.a = 0.5 + pulse * 0.5

func update_movement_trail():
    trail_points.append(global_position)
    
    # Limit trail length
    while trail_points.size() > ConfigManager.config.max_trail_points:
        trail_points.pop_front()
    
    # Update Line2D
    movement_trail.clear_points()
    for point in trail_points:
        movement_trail.add_point(point)

func update_action_smoothing(delta):
    # Update thrust ramping
    if is_thrusting and current_thrust_level > 0:
        thrust_ramp_ratio = min(1.0, thrust_ramp_ratio + delta * 2.0)  # Ramp up
        steps_in_current_thrust += 1
    else:
        thrust_ramp_ratio = max(0.0, thrust_ramp_ratio - delta * 3.0)  # Ramp down faster
    
    # Update rotation ramping
    if current_torque_level > 0:
        rotation_ramp_ratio = min(1.0, rotation_ramp_ratio + delta * 3.0)
        steps_in_current_rotation += 1
    else:
        rotation_ramp_ratio = max(0.0, rotation_ramp_ratio - delta * 4.0)
    
    # Update thruster particle effects
    update_thruster_effects()

func update_thruster_effects():
    var main_thruster = thruster_system.get_node("MainThruster") as GPUParticles2D
    
    if is_thrusting and thrust_ramp_ratio > 0.1:
        main_thruster.emitting = true
        main_thruster.amount_ratio = thrust_ramp_ratio
        
        # Update particle color based on thrust level
        var material = main_thruster.process_material as ParticleProcessMaterial
        var intensity = thrust_ramp_ratio * current_thrust_level / float(ConfigManager.config.thrust_force_magnitudes.size() - 1)
        material.color = Color.CYAN.lerp(Color.WHITE, intensity)
        
        # Play thruster audio
        if not audio_component.playing:
            audio_component.play()
    else:
        main_thruster.emitting = false
        audio_component.stop()

func apply_external_force(force: Vector2, force_name: String):
    external_forces[force_name] = force

func remove_external_force(force_name: String):
    external_forces.erase(force_name)

func consume_energy(amount: float):
    current_energy = max(0.0, current_energy - amount)

func die():
    if not is_alive:
        return
    
    is_alive = false
    set_collision_layer_value(2, false)  # Remove from probe layer
    
    # Visual death effect
    var tween = create_tween()
    tween.parallel().tween_property(visual_component, "modulate", Color.RED, 1.0)
    tween.parallel().tween_property(visual_component, "scale", Vector2.ZERO, 1.0)
    tween.tween_callback(queue_free)
    
    probe_destroyed.emit(self)

func attempt_replication():
    if current_energy >= ConfigManager.config.replication_cost and is_alive:
        current_energy -= ConfigManager.config.replication_cost
        replication_requested.emit(self)

func start_mining(target_resource):
    if not is_alive:
        return
    
    is_mining = true
    current_task = "mining"
    
    # Show mining laser
    mining_laser.clear_points()
    mining_laser.add_point(global_position)
    mining_laser.add_point(target_resource.global_position)
    mining_laser.default_color = Color.GREEN
    mining_laser.width = 3.0
    mining_laser.visible = true
    
    # Start mining particles
    var mining_particles = thruster_system.get_node("MiningParticles") as GPUParticles2D
    mining_particles.emitting = true
    mining_particles.global_position = target_resource.global_position

func stop_mining():
    is_mining = false
    current_task = "idle"
    mining_laser.visible = false
    
    var mining_particles = thruster_system.get_node("MiningParticles") as GPUParticles2D
    mining_particles.emitting = false

func send_communication(target_position: Vector2, message_type: String):
    if not is_alive:
        return
    
    is_communicating = true
    communication_sent.emit(self, target_position, message_type)
    
    # Create communication beam effect
    # TODO: Create CommunicationBeam.tscn and uncomment the following lines
    # var beam_effect = preload("res://effects/CommunicationBeam.tscn").instantiate()
    # get_tree().current_scene.add_child(beam_effect)
    # beam_effect.setup_beam(global_position, target_position)

func get_observation_data() -> Dictionary:
    # Generate comprehensive observation data for AI
    var observation = {
        "position": global_position,
        "velocity": linear_velocity,
        "rotation": rotation,
        "angular_velocity": angular_velocity,
        "energy": current_energy,
        "energy_ratio": current_energy / max_energy,
        "is_mining": is_mining,
        "is_thrusting": is_thrusting,
        "current_target_id": current_target_id,
        "nearby_resources": get_nearby_resources(),
        "nearby_probes": get_nearby_probes(),
        "nearby_celestial_bodies": get_nearby_celestial_bodies(),
        "sensor_data": get_sensor_readings()
    }
    return observation

func get_nearby_resources() -> Array:
    var resources = []
    var bodies = sensor_array.get_overlapping_bodies()
    
    for body in bodies:
        if body is Resource:
            var resource = body as Resource
            var distance = global_position.distance_to(resource.global_position)
            resources.append({
                "position": resource.global_position,
                "amount": resource.current_amount,
                "distance": distance,
                "type": resource.resource_type
            })
    
    # Sort by distance
    resources.sort_custom(func(a, b): return a.distance < b.distance)
    
    # Return only closest N resources
    return resources.slice(0, ConfigManager.config.num_observed_resources)

func get_nearby_probes() -> Array:
    var probes = []
    var areas = communication_range.get_overlapping_areas()
    
    for area in areas:
        var probe = area.get_parent() as Probe
        if probe and probe != self and probe.is_alive:
            var distance = global_position.distance_to(probe.global_position)
            probes.append({
                "position": probe.global_position,
                "velocity": probe.linear_velocity,
                "energy": probe.current_energy,
                "distance": distance,
                "generation": probe.generation,
                "id": probe.probe_id
            })
    
    probes.sort_custom(func(a, b): return a.distance < b.distance)
    return probes.slice(0, 5)  # Return closest 5 probes

func get_nearby_celestial_bodies() -> Array:
    var bodies = []
    
    for body in get_tree().get_nodes_in_group("celestial_bodies"):
        var celestial_body = body as CelestialBody
        if celestial_body:
            var distance = global_position.distance_to(celestial_body.global_position)
            if distance < 5000:  # Only include bodies within reasonable range
                bodies.append({
                    "name": celestial_body.body_name,
                    "position": celestial_body.global_position,
                    "mass": celestial_body.mass_kg,
                    "distance": distance,
                    "gravity_influence": calculate_gravity_influence(celestial_body)
                })
    
    bodies.sort_custom(func(a, b): return a.distance < b.distance)
    return bodies.slice(0, 3)

func calculate_gravity_influence(celestial_body: CelestialBody) -> float:
    var distance = global_position.distance_to(celestial_body.global_position)
    if distance < 1e-6:
        return 0.0
    
    return ConfigManager.config.gravitational_constant * celestial_body.mass_kg / (distance * distance)

func get_sensor_readings() -> Dictionary:
    return {
        "energy_sensors": {
            "solar_input": calculate_solar_energy_input(),
            "heat_signature": current_energy / max_energy
        },
        "proximity_sensors": {
            "collision_risk": calculate_collision_risk(),
            "gravity_gradient": calculate_gravity_gradient()
        },
        "navigation_sensors": {
            "velocity_magnitude": linear_velocity.length(),
            "angular_velocity_magnitude": abs(angular_velocity),
            "heading": rotation
        }
    }

func calculate_solar_energy_input() -> float:
    # Calculate solar energy based on distance from Sun
    var sun = get_tree().get_first_node_in_group("sun")
    if not sun:
        return 0.0
    
    var distance_to_sun = global_position.distance_to(sun.global_position)
    var solar_constant = 1361.0  # W/m² at 1 AU
    var au_distance = distance_to_sun / ConfigManager.config.au_scale
    
    return solar_constant / (au_distance * au_distance)

func calculate_collision_risk() -> float:
    # Simple collision risk assessment
    var risk = 0.0
    var bodies = sensor_array.get_overlapping_bodies()
    
    for body in bodies:
        if body == self:
            continue
        
        var distance = global_position.distance_to(body.global_position)
        var relative_velocity = (linear_velocity - body.linear_velocity).length()
        
        if distance > 0 and relative_velocity > 0:
            var time_to_collision = distance / relative_velocity
            if time_to_collision < 10.0:  # 10 seconds
                risk += 1.0 / time_to_collision
    
    return min(risk, 1.0)

func calculate_gravity_gradient() -> float:
    # Measure change in gravitational field
    var current_gravity = Vector2.ZERO
    for force_name in external_forces:
        if force_name.begins_with("gravity_"):
            current_gravity += external_forces[force_name]
    
    return current_gravity.length()

func _on_sensor_body_entered(body):
    if body is Resource:
        var resource = body as Resource
        resource_discovered.emit(self, resource.global_position, resource.current_amount)

func _on_sensor_body_exited(body):
    # Handle sensor exit events if needed
    pass

func _on_communication_range_entered(area):
    # Handle probe entering communication range
    var other_probe = area.get_parent() as Probe
    if other_probe and other_probe != self:
        # Could trigger automatic information exchange
        pass