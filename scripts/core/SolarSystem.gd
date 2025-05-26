extends Node2D
class_name SolarSystem

# --- Signals ---
signal probe_created_in_system(probe_instance: Probe)
signal probe_destroyed_in_system(probe_instance: Probe) # Probe ID might be better if instance is freed
signal resource_depleted_in_system(resource_node: ResourceNode) # Same, ID might be better
signal all_probes_dead()
signal simulation_step_completed(step_count: int)

# --- OnReady Node References for Containers ---
# These nodes will be children of SolarSystem in the scene tree
@onready var celestial_bodies_container: Node2D = $CelestialBodiesContainer
@onready var resources_container: Node2D = $ResourcesContainer
@onready var probes_container: Node2D = $ProbesContainer
# @onready var particle_effects_container: Node2D = $ParticleEffectsContainer # If a dedicated container is used

# --- Simulation State ---
var orbital_mechanics_instance: OrbitalMechanics # Instance, not class name
var sun_node: CelestialBody # Direct reference to the Sun
var planet_nodes: Array[CelestialBody] = [] # Array of planet CelestialBody nodes
var resource_nodes: Array[ResourceNode] = [] # Array of ResourceNode instances
var probe_instances: Dictionary = {} # probe_id (int) -> Probe instance

var messages_log: Array[Dictionary] = [] # For inter-probe communication or system events

var current_step_count: int = 0
var total_resources_mined_session: float = 0.0
var next_available_probe_id: int = 0

# --- Preloaded Scenes ---
var celestial_body_scene: PackedScene = preload("res://scenes/CelestialBody.tscn")
var resource_scene: PackedScene = preload("res://scenes/Resource.tscn")
var probe_scene: PackedScene = preload("res://scenes/Probe.tscn")


func _ready():
    orbital_mechanics_instance = OrbitalMechanics.new()
    
    # Ensure containers exist, or create them if this script can run standalone (less common for scenes)
    if not celestial_bodies_container:
        printerr("SolarSystem: CelestialBodiesContainer not found! Please add a Node2D named 'CelestialBodiesContainer'.")
        celestial_bodies_container = Node2D.new(); celestial_bodies_container.name = "CelestialBodiesContainer"; add_child(celestial_bodies_container) # Fallback
    if not resources_container:
        printerr("SolarSystem: ResourcesContainer not found! Please add a Node2D named 'ResourcesContainer'.")
        resources_container = Node2D.new(); resources_container.name = "ResourcesContainer"; add_child(resources_container) # Fallback
    if not probes_container:
        printerr("SolarSystem: ProbesContainer not found! Please add a Node2D named 'ProbesContainer'.")
        probes_container = Node2D.new(); probes_container.name = "ProbesContainer"; add_child(probes_container) # Fallback

    # Initial setup called by Main.gd or GameManager, or directly for testing
    # initialize_environment() is a better name for a full setup/reset


func initialize_environment():
    print("SolarSystem: Initializing environment...")
    current_step_count = 0
    total_resources_mined_session = 0.0
    next_available_probe_id = 0 # Reset probe ID counter
    messages_log.clear()

    # Clear existing entities
    clear_all_entities()

    create_all_celestial_bodies()
    generate_initial_resources()
    create_initial_probes_set()
    print("SolarSystem: Environment initialized.")

func clear_all_entities():
    for body_container in [celestial_bodies_container, resources_container, probes_container]:
        if is_instance_valid(body_container):
            for child in body_container.get_children():
                child.queue_free()
    
    sun_node = null
    planet_nodes.clear()
    resource_nodes.clear()
    probe_instances.clear()


func create_all_celestial_bodies():
    # Create Sun
    var sun_config_data = Config.PLANET_DATA.get("Sun")
    if sun_config_data:
        sun_node = _create_single_celestial_body("Sun", sun_config_data, celestial_bodies_container)
        if is_instance_valid(sun_node):
            sun_node.global_position = Config.World.CENTER_SIM # Sun at the center
            # Sun doesn't orbit, so velocity and initial state vector are not set here.
    else:
        printerr("SolarSystem: Sun configuration data not found in Config.PLANET_DATA!")
        return # Critical error, cannot proceed without Sun for mass calculations

    # Create Planets
    # Order might matter if there are inter-dependencies not handled by central_body_name alone
    var planet_names_ordered = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"] # Example order
    for planet_name_key in planet_names_ordered:
        var planet_config_data = Config.PLANET_DATA.get(planet_name_key)
        if planet_config_data:
            var central_body_for_orbit_calc = sun_node # Default to Sun
            # More complex scenarios could involve moons orbiting planets, requiring finding the named central body.
            # For now, assume all planets orbit the 'Sun' node directly.
            if not is_instance_valid(central_body_for_orbit_calc):
                printerr("SolarSystem: Central body for %s not found for orbit calculation." % planet_name_key)
                continue

            var planet_node_instance = _create_single_celestial_body(planet_name_key, planet_config_data, celestial_bodies_container)
            if is_instance_valid(planet_node_instance):
                var initial_state = orbital_mechanics_instance.calculate_initial_state_vector(planet_config_data, central_body_for_orbit_calc.mass_kg)
                planet_node_instance.global_position = central_body_for_orbit_calc.global_position + initial_state.position
                planet_node_instance.velocity = initial_state.velocity # CelestialBody script should use this
                planet_nodes.append(planet_node_instance)
        # else:
            # print("SolarSystem: Config data for planet '%s' not found. Skipping." % planet_name_key)


func _create_single_celestial_body(body_id_name: String, config_data: Dictionary, parent_container: Node) -> CelestialBody:
    if not celestial_body_scene:
        printerr("SolarSystem: celestial_body_scene is not loaded!")
        return null
        
    var body_instance: CelestialBody = celestial_body_scene.instantiate() as CelestialBody
    if not body_instance:
        printerr("SolarSystem: Failed to instantiate CelestialBody scene for %s." % body_id_name)
        return null

    body_instance.name = body_id_name # Set node name for easier debugging/finding
    body_instance.body_name = body_id_name # Property within CelestialBody script
    body_instance.mass_kg = config_data.mass_kg
    body_instance.radius_km = config_data.radius_km
    body_instance.display_radius_sim = config_data.display_radius_sim
    body_instance.color = config_data.color
    
    # Orbital elements from config (used by OrbitalMechanics, stored in CelestialBody for reference)
    body_instance.semi_major_axis_au = config_data.get("semi_major_axis_au", 0.0)
    body_instance.eccentricity = config_data.get("eccentricity", 0.0)
    body_instance.inclination_deg = config_data.get("inclination_deg", 0.0)
    body_instance.longitude_of_ascending_node_deg = config_data.get("longitude_of_ascending_node_deg", 0.0)
    body_instance.argument_of_perihelion_deg = config_data.get("argument_of_perihelion_deg", 0.0)
    body_instance.mean_anomaly_at_epoch_deg = config_data.get("mean_anomaly_at_epoch_deg", 0.0)
    body_instance.central_body_name = config_data.get("central_body", "") # Name of the body it orbits

    parent_container.add_child(body_instance)
    return body_instance


func generate_initial_resources():
    if not resource_scene:
        printerr("SolarSystem: resource_scene is not loaded!")
        return

    for i in range(Config.Resource.COUNT):
        var resource_instance: ResourceNode = resource_scene.instantiate() as ResourceNode
        if not resource_instance:
            printerr("SolarSystem: Failed to instantiate ResourceNode scene. Skipping resource %d." % i)
            continue
            
        resource_instance.name = "Resource_" + str(i)
        # Position resources randomly within world bounds (or asteroid belt)
        var pos_x = randf_range(0, Config.World.WIDTH_SIM)
        var pos_y = randf_range(0, Config.World.HEIGHT_SIM)
        # TODO: Implement asteroid belt placement if needed from Config
        resource_instance.global_position = Vector2(pos_x, pos_y)
        
        var initial_amount = randf_range(Config.Resource.MIN_AMOUNT, Config.Resource.MAX_AMOUNT)
        resource_instance.amount = initial_amount
        resource_instance.max_amount = initial_amount # Or a different max if they can grow beyond initial
        resource_instance.resource_type = "generic_mineral" # Example type
        
        # Connect signals if ResourceNode emits them and SolarSystem needs to react
        # resource_instance.resource_depleted.connect(_on_resource_depleted_internal.bind(resource_instance))

        resources_container.add_child(resource_instance)
        resource_nodes.append(resource_instance)

func create_initial_probes_set():
    for i in range(Config.Probe.INITIAL_PROBES):
        var spawn_offset = Vector2(randf_range(-200, 200), randf_range(-200, 200)) # Small random offset from center
        var spawn_pos = Config.World.CENTER_SIM + spawn_offset
        var new_probe_id = _get_next_probe_id()
        var new_probe_instance = _create_new_probe_instance(new_probe_id, spawn_pos, 0) # Generation 0
        # GameManager will assign AI model

func _create_new_probe_instance(id: int, pos: Vector2, gen: int, initial_energy: float = -1.0) -> Probe:
    if not probe_scene:
        printerr("SolarSystem: probe_scene is not loaded!")
        return null
        
    if probe_instances.has(id):
        printerr("SolarSystem: Probe with ID %d already exists!" % id)
        return probe_instances[id] # Or handle error differently

    var probe_instance: Probe = probe_scene.instantiate() as Probe
    if not probe_instance:
        printerr("SolarSystem: Failed to instantiate Probe scene for ID %d." % id)
        return null

    probe_instance.probe_id = id
    probe_instance.name = "Probe_" + str(id) # Node name
    probe_instance.global_position = pos
    probe_instance.generation = gen
    probe_instance.energy = Config.Probe.INITIAL_ENERGY if initial_energy < 0 else initial_energy
    
    # Connect probe's signals to SolarSystem handlers
    probe_instance.destroyed.connect(_on_probe_destroyed_internal.bind(probe_instance))
    probe_instance.replication_attempted.connect(_on_probe_replication_attempted)
    # Other signals like mining_started, energy_depleted can be connected if SolarSystem needs to globally react

    probes_container.add_child(probe_instance)
    probe_instances[id] = probe_instance
    
    probe_created_in_system.emit(probe_instance) # Signal for GameManager to assign AI etc.
    return probe_instance

func _get_next_probe_id() -> int:
    next_available_probe_id += 1
    return next_available_probe_id


func _physics_process(delta: float): # Or a custom step_simulation(delta) called by Main
    # 1. Update Celestial Bodies
    var all_orbiting_bodies: Array[CelestialBody] = []
    if is_instance_valid(sun_node): all_orbiting_bodies.append(sun_node) # Sun itself doesn't orbit but might be part of calculations
    all_orbiting_bodies.append_array(planet_nodes)
    
    if not all_orbiting_bodies.is_empty() and is_instance_valid(orbital_mechanics_instance):
        orbital_mechanics_instance.propagate_orbits_verlet(all_orbiting_bodies, Config.Physics.TIMESTEP_SECONDS) # Using fixed timestep from Config

    # 2. Update Probes (Probes have their own _physics_process for AI and movement)
    # No direct call needed here if probes handle their own updates.
    # SolarSystem might iterate probes for global checks or interactions if any.

    # 3. Update Resources (Resources have their own _physics_process for regeneration)
    # No direct call needed here if resources handle their own updates.

    # 4. Global checks / cleanup (handled by signals or dedicated methods)
    # cleanup_destroyed_probes() # This is now handled by _on_probe_destroyed_internal

    current_step_count += 1
    simulation_step_completed.emit(current_step_count)

    if probe_instances.is_empty() and Config.Probe.INITIAL_PROBES > 0: # Check if all probes died
        var any_probe_ever_created = next_available_probe_id > 0
        if any_probe_ever_created: # Avoid emitting if no probes were ever made
            all_probes_dead.emit()


# --- Signal Handlers ---
func _on_probe_destroyed_internal(probe_instance: Probe):
    if not is_instance_valid(probe_instance): return

    var id_to_remove = probe_instance.probe_id
    if probe_instances.has(id_to_remove):
        probe_instances.erase(id_to_remove)
        probe_destroyed_in_system.emit(probe_instance) # Emit before queue_free
        print("SolarSystem: Probe %d marked as destroyed and removed from active list." % id_to_remove)
    # The probe node itself will be queue_free'd by its own die() or by GameManager
    # If SolarSystem is responsible for freeing, it would be: probe_instance.queue_free()

func _on_probe_replication_attempted(replicating_probe: Probe, cost: float):
    if not is_instance_valid(replicating_probe) or not replicating_probe.alive:
        return

    if replicating_probe.energy >= cost and probe_instances.size() < Config.Probe.MAX_PROBES:
        var spawn_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20)) # Spawn near parent
        var spawn_pos = replicating_probe.global_position + spawn_offset
        var new_id = _get_next_probe_id()
        var new_gen = replicating_probe.generation + 1
        
        var new_probe = _create_new_probe_instance(new_id, spawn_pos, new_gen, Config.Probe.ENERGY_AFTER_REPLICATION) # Give some starting energy
        
        if is_instance_valid(new_probe):
            replicating_probe.confirm_replication_energy_deduction() # Tell original probe to pay
            print("SolarSystem: Probe %d successfully replicated into Probe %d (Gen %d)." % [replicating_probe.probe_id, new_id, new_gen])
        else:
            print("SolarSystem: Probe %d replication failed (could not create new instance)." % replicating_probe.probe_id)
    # else:
        # print("SolarSystem: Probe %d replication failed (not enough energy or max probes reached)." % replicating_probe.probe_id)


func _on_resource_depleted_internal(resource_instance: ResourceNode):
    if not is_instance_valid(resource_instance): return
    
    if resource_nodes.has(resource_instance):
        resource_nodes.erase(resource_instance) # Remove from active list
        resource_depleted_in_system.emit(resource_instance)
        print("SolarSystem: Resource %s depleted and removed." % resource_instance.name)
        # Resource node might queue_free itself or be handled by a manager.
        # For now, assume it handles its own lifecycle after depletion.


# --- Public Accessors for Game State (used by UI, GameManager) ---
func get_simulation_environment_data() -> Dictionary:
    var probe_data_for_ui = {}
    for p_id in probe_instances:
        var p_inst: Probe = probe_instances[p_id]
        if is_instance_valid(p_inst):
            probe_data_for_ui[p_id] = {
                "probe_id": p_inst.probe_id,
                "position": p_inst.global_position,
                "velocity": p_inst.velocity, # CharacterBody2D velocity
                "angle_rad": p_inst.rotation, # Node2D rotation
                "energy": p_inst.energy,
                "alive": p_inst.alive,
                "generation": p_inst.generation,
                "is_mining": p_inst.is_mining_active,
                "target_resource_id": p_inst.target_resource_node.resource_id if is_instance_valid(p_inst.target_resource_node) and p_inst.target_resource_node.has_method("get_resource_id") else -1
            }
            
    var resource_data_for_ui = []
    for res_node in resource_nodes:
        if is_instance_valid(res_node):
            resource_data_for_ui.append({
                "resource_id": res_node.resource_id if res_node.has_method("get_resource_id") else -1, # Assuming ResourceNode has get_resource_id
                "position": res_node.global_position,
                "amount": res_node.amount,
                "max_amount": res_node.max_amount,
                "type": res_node.resource_type
            })

    return {
        "current_step_count": current_step_count,
        "active_probes_count": probe_instances.size(),
        "total_probes_created": next_available_probe_id, # Max ID used so far
        "active_resources_count": resource_nodes.size(),
        "total_resources_mined_session": total_resources_mined_session,
        "sun_data": sun_node.get_data_dict() if is_instance_valid(sun_node) and sun_node.has_method("get_data_dict") else {},
        "planet_data_array": _get_planet_data_array(),
        "probes_details": probe_data_for_ui, # More detailed list for UI
        "resources_details": resource_data_for_ui, # More detailed list for UI
        "messages_log_count": messages_log.size()
    }

func _get_planet_data_array() -> Array:
    var planet_data = []
    for p in planet_nodes:
        if is_instance_valid(p) and p.has_method("get_data_dict"):
            planet_data.append(p.get_data_dict())
    return planet_data

func get_probe_instance_by_id(id: int) -> Probe:
    return probe_instances.get(id, null)

func get_all_probe_instances() -> Array[Probe]:
    return probe_instances.values()
    
func get_all_celestial_bodies() -> Array[CelestialBody]:
    var bodies = []
    if is_instance_valid(sun_node): bodies.append(sun_node)
    bodies.append_array(planet_nodes)
    return bodies

func record_mined_resource(amount: float):
    total_resources_mined_session += amount