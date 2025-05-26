# SimulationManager.gd
extends Node
class_name SimulationManager

@export var max_simulation_steps: int = 50000
@export var simulation_speed: float = 1.0
@export var auto_pause_on_events: bool = true
@export var auto_restart_episodes: bool = true

@onready var solar_system: Node2D = $"../SolarSystem"
@onready var probe_manager: Node2D = $"../ProbeManager"
@onready var resource_manager: Node2D = $"../ResourceManager"
@onready var ui_system: Control = $"../UI"
@onready var camera: Camera2D = $"../Camera2D"

var current_step: int = 0
var simulation_running: bool = false
var episode_count: int = 0
var total_resources_mined: float = 0.0
var simulation_start_time: float = 0.0

# Performance monitoring
var frame_time_accumulator: float = 0.0
var frame_count: int = 0
var average_fps: float = 60.0

# Save/Load
var autosave_interval: float = 300.0  # 5 minutes
var last_autosave: float = 0.0

signal simulation_started()
signal simulation_paused()
signal simulation_ended()
signal episode_completed(episode_num: int, total_steps: int)
signal probe_count_changed(new_count: int)

func _ready():
    # Initialize simulation
    initialize_simulation()
    
    # Connect signals
    connect_system_signals()
    
    # Start first episode
    start_new_episode()

func initialize_simulation():
    # Validate configuration
    if not ConfigManager.validate_configuration():
        push_error("Invalid configuration detected")
        return
    
    # Initialize solar system
    initialize_solar_system()
    
    # Initialize resources
    initialize_resources()
    
    # Setup camera
    setup_camera()
    
    # Initialize UI
    setup_ui()
    
    print("Simulation initialized successfully")

func initialize_solar_system():
    # Create celestial bodies based on configuration
    var sun_scene = preload("res://celestial_bodies/CelestialBody.tscn")
    var sun_instance = sun_scene.instantiate()
    
    # Configure Sun
    sun_instance.body_name = "Sun"
    sun_instance.mass_kg = 1.9885e30
    sun_instance.radius_km = 695700.0
    sun_instance.display_radius = 500.0
    sun_instance.body_color = Color.YELLOW
    sun_instance.global_position = Vector2(ConfigManager.config.world_size_au * ConfigManager.config.au_scale / 2, 
                                           ConfigManager.config.world_size_au * ConfigManager.config.au_scale / 2)
    
    solar_system.add_child(sun_instance)
    sun_instance.add_to_group("celestial_bodies")
    sun_instance.add_to_group("sun")
    
    # Create planets and moons
    create_planets()

func create_planets():
    var planet_data = {
        "Mercury": {"mass": 0.33011e24, "radius": 2439.7, "color": Color.GRAY, "sma": 0.387098, "ecc": 0.205630},
        "Venus": {"mass": 4.8675e24, "radius": 6051.8, "color": Color(1.0, 0.8, 0.3), "sma": 0.723332, "ecc": 0.006772},
        "Earth": {"mass": 5.97237e24, "radius": 6371.0, "color": Color.BLUE, "sma": 1.00000261, "ecc": 0.01671123},
        "Mars": {"mass": 0.64171e24, "radius": 3389.5, "color": Color.RED, "sma": 1.523679, "ecc": 0.09340},
        "Jupiter": {"mass": 1898.19e24, "radius": 69911.0, "color": Color.ORANGE, "sma": 5.2044, "ecc": 0.0489},
        "Saturn": {"mass": 568.34e24, "radius": 58232.0, "color": Color(0.9, 0.8, 0.6), "sma": 9.5826, "ecc": 0.0565},
        "Uranus": {"mass": 86.813e24, "radius": 25362.0, "color": Color.CYAN, "sma": 19.2184, "ecc": 0.0457},
        "Neptune": {"mass": 102.413e24, "radius": 24622.0, "color": Color.BLUE, "sma": 30.110, "ecc": 0.0113}
    }
    
    var planet_scene = preload("res://celestial_bodies/CelestialBody.tscn")
    
    for planet_name in planet_data:
        var data = planet_data[planet_name]
        var planet = planet_scene.instantiate()
        
        planet.body_name = planet_name
        planet.mass_kg = data.mass
        planet.radius_km = data.radius
        planet.body_color = data.color
        planet.semi_major_axis_au = data.sma
        planet.eccentricity = data.ecc
        planet.central_body_name = "Sun"
        planet.display_radius = max(20, data.radius / 1000)  # Scale for visibility
        
        solar_system.add_child(planet)
        planet.add_to_group("celestial_bodies")
        
        # Create major moons for gas giants
        if planet_name == "Jupiter":
            create_jupiter_moons(planet)
        elif planet_name == "Earth":
            create_earth_moon(planet)
        elif planet_name == "Saturn":
            create_saturn_moons(planet)

func create_jupiter_moons(jupiter: CelestialBody):
    var moon_data = {
        "Io": {"mass": 0.089319e24, "radius": 1821.6, "sma": 0.002819, "color": Color.YELLOW},
        "Europa": {"mass": 0.04800e24, "radius": 1560.8, "sma": 0.004486, "color": Color(0.8, 0.8, 1.0)},
        "Ganymede": {"mass": 0.14819e24, "radius": 2634.1, "sma": 0.007155, "color": Color.GRAY},
        "Callisto": {"mass": 0.10759e24, "radius": 2410.3, "sma": 0.012585, "color": Color(0.4, 0.3, 0.2)}
    }
    
    create_moons(jupiter, moon_data)

func create_earth_moon(earth: CelestialBody):
    var moon_data = {
        "Moon": {"mass": 0.07346e24, "radius": 1737.4, "sma": 0.00257, "color": Color.LIGHT_GRAY}
    }
    
    create_moons(earth, moon_data)

func create_saturn_moons(saturn: CelestialBody):
    var moon_data = {
        "Titan": {"mass": 0.13452e24, "radius": 2574.7, "sma": 0.008168, "color": Color(0.9, 0.7, 0.4)}
    }
    
    create_moons(saturn, moon_data)

func create_moons(parent_planet: CelestialBody, moon_data: Dictionary):
    var moon_scene = preload("res://celestial_bodies/CelestialBody.tscn")
    
    for moon_name in moon_data:
        var data = moon_data[moon_name]
        var moon = moon_scene.instantiate()
        
        moon.body_name = moon_name
        moon.mass_kg = data.mass
        moon.radius_km = data.radius
        moon.body_color = data.color
        moon.semi_major_axis_au = data.sma
        moon.central_body_name = parent_planet.body_name
        moon.display_radius = max(10, data.radius / 200)
        
        solar_system.add_child(moon)
        moon.add_to_group("celestial_bodies")

func initialize_resources():
    var resource_scene = preload("res://resources/Resource.tscn")
    
    for i in range(ConfigManager.config.resource_count):
        var resource = resource_scene.instantiate()
        
        # Random position within world bounds
        var world_size = ConfigManager.config.world_size_au * ConfigManager.config.au_scale
        resource.global_position = Vector2(
            randf() * world_size,
            randf() * world_size
        )
        
        # Random resource properties
        resource.current_amount = randf_range(
            ConfigManager.config.resource_amount_range.x,
            ConfigManager.config.resource_amount_range.y
        )
        resource.max_amount = resource.current_amount
        resource.regeneration_rate = ConfigManager.config.resource_regen_rate
        
        # Random resource type
        var types = ["mineral", "energy", "rare_earth", "water"]
        resource.resource_type = types[randi() % types.size()]
        
        resource_manager.add_child(resource)
        resource.add_to_group("resources")
        
        # Connect signals
        resource.resource_depleted.connect(_on_resource_depleted)
        resource.resource_harvested.connect(_on_resource_harvested)

func setup_camera():
    camera.enabled = true
    camera.zoom = Vector2.ONE * 0.1  # Start zoomed out
    
    # Setup smooth camera following
    var camera_controller = preload("res://systems/CameraController.gd").new()
    camera.add_child(camera_controller)

func setup_ui():
    # Initialize UI panels with simulation data
    var hud = ui_system.get_node("HUD")
    var probe_list = ui_system.get_node("ProbeListPanel")
    var selected_probe = ui_system.get_node("SelectedProbePanel")
    var stats_panel = ui_system.get_node("SystemStatsPanel")
    
    # Connect UI signals
    if probe_list.has_signal("probe_selected"):
        probe_list.probe_selected.connect(_on_probe_selected)

func connect_system_signals():
    # Connect to various system signals for coordinated behavior
    pass

func start_new_episode():
    episode_count += 1
    current_step = 0
    total_resources_mined = 0.0
    simulation_start_time = Time.get_time_dict_from_system()["unix"]
    
    # Clear existing probes
    clear_all_probes()
    
    # Create initial probes
    create_initial_probes()
    
    # Reset simulation state
    simulation_running = true
    
    simulation_started.emit()
    print("Started episode ", episode_count)

func create_initial_probes():
    var probe_scene = preload("res://probes/Probe.tscn")
    
    for i in range(ConfigManager.config.initial_probes):
        var probe = probe_scene.instantiate()
        
        # Assign unique ID
        probe.probe_id = i + 1
        probe.generation = 0
        
        # Random starting position near world center
        var world_size = ConfigManager.config.world_size_au * ConfigManager.config.au_scale
        var center = Vector2(world_size / 2, world_size / 2)
        var offset = Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000))
        probe.global_position = center + offset
        
        # Initialize with full energy
        probe.current_energy = ConfigManager.config.initial_energy
        probe.max_energy = ConfigManager.config.max_energy
        
        probe_manager.add_child(probe)
        probe.add_to_group("probes")
        
        # Connect probe signals
        connect_probe_signals(probe)
        
        print("Created probe ", probe.probe_id, " at ", probe.global_position)

func connect_probe_signals(probe: Probe):
    probe.probe_destroyed.connect(_on_probe_destroyed)
    probe.replication_requested.connect(_on_replication_requested)
    probe.resource_discovered.connect(_on_resource_discovered_by_probe)
    probe.communication_sent.connect(_on_communication_sent)

func clear_all_probes():
    for probe in get_tree().get_nodes_in_group("probes"):
        probe.queue_free()

func _physics_process(delta):
    if not simulation_running:
        return
    
    # Update simulation step
    current_step += 1
    
    # Check for episode end conditions
    check_episode_end_conditions()
    
    # Update performance metrics
    update_performance_metrics(delta)
    
    # Autosave periodically
    handle_autosave(delta)
    
    # Update UI with current state
    update_ui_data()

func check_episode_end_conditions():
    # Check maximum steps
    if current_step >= max_simulation_steps:
        end_episode("max_steps_reached")
        return
    
    # Check if all probes are dead
    var living_probes = get_tree().get_nodes_in_group("probes").filter(func(p): return p.is_alive)
    if living_probes.size() == 0:
        end_episode("all_probes_dead")
        return
    
    # Check for other termination conditions
    # (e.g., all resources depleted, specific objectives met)

func end_episode(reason: String):
    simulation_running = false
    
    var episode_stats = {
        "episode": episode_count,
        "steps": current_step,
        "reason": reason,
        "resources_mined": total_resources_mined,
        "final_probe_count": get_tree().get_nodes_in_group("probes").size(),
        "duration_seconds": Time.get_time_dict_from_system()["unix"] - simulation_start_time
    }
    
    print("Episode ", episode_count, " ended: ", reason)
    print("Stats: ", episode_stats)
    
    episode_completed.emit(episode_count, current_step)
    simulation_ended.emit()
    
    # Optionally start new episode automatically
    if auto_restart_episodes:
        call_deferred("start_new_episode")

func update_performance_metrics(delta):
    frame_time_accumulator += delta
    frame_count += 1
    
    if frame_time_accumulator >= 1.0:  # Update every second
        average_fps = frame_count / frame_time_accumulator
        frame_time_accumulator = 0.0
        frame_count = 0
        
        # Check for performance issues
        if average_fps < 30:
            print("Warning: Low FPS detected: ", average_fps)

func handle_autosave(delta):
    last_autosave += delta
    if last_autosave >= autosave_interval:
        last_autosave = 0.0
        autosave_simulation()

func autosave_simulation():
    var save_data = create_save_data()
    var save_path = "user://autosave_episode_" + str(episode_count) + ".tres"
    ResourceSaver.save(save_data, save_path)
    print("Autosaved to: ", save_path)

func create_save_data() -> SimulationSaveData:
    var save_data = SimulationSaveData.new()
    
    save_data.episode_count = episode_count
    save_data.current_step = current_step
    save_data.total_resources_mined = total_resources_mined
    save_data.simulation_running = simulation_running
    
    # Save probe data
    for probe in get_tree().get_nodes_in_group("probes"):
        var probe_data = ProbeData.new()
        probe_data.id = probe.probe_id
        probe_data.position = probe.global_position
        probe_data.velocity = probe.linear_velocity
        probe_data.energy = probe.current_energy
        probe_data.generation = probe.generation
        probe_data.is_alive = probe.is_alive
        save_data.probes.append(probe_data)
    
    # Save resource data
    for resource in get_tree().get_nodes_in_group("resources"):
        var resource_data = ResourceData.new()
        resource_data.position = resource.global_position
        resource_data.current_amount = resource.current_amount
        resource_data.max_amount = resource.max_amount
        resource_data.resource_type = resource.resource_type
        save_data.resources.append(resource_data)
    
    return save_data

func load_simulation(save_data: SimulationSaveData):
    # Clear current simulation
    clear_all_probes()
    
    # Restore simulation state
    episode_count = save_data.episode_count
    current_step = save_data.current_step
    total_resources_mined = save_data.total_resources_mined
    simulation_running = save_data.simulation_running
    
    # Restore probes
    var probe_scene = preload("res://probes/Probe.tscn")
    for probe_data in save_data.probes:
        var probe = probe_scene.instantiate()
        probe.probe_id = probe_data.id
        probe.global_position = probe_data.position
        probe.linear_velocity = probe_data.velocity
        probe.current_energy = probe_data.energy
        probe.generation = probe_data.generation
        probe.is_alive = probe_data.is_alive
        
        probe_manager.add_child(probe)
        probe.add_to_group("probes")
        connect_probe_signals(probe)
    
    # Update resources
    var resources = get_tree().get_nodes_in_group("resources")
    for i in range(min(resources.size(), save_data.resources.size())):
        var resource = resources[i]
        var resource_data = save_data.resources[i]
        resource.global_position = resource_data.position
        resource.current_amount = resource_data.current_amount
        resource.max_amount = resource_data.max_amount
        resource.resource_type = resource_data.resource_type
        resource.update_visual_state()

func update_ui_data():
    # Update UI elements with current simulation data
    var stats_panel = ui_system.get_node("SystemStatsPanel")
    if stats_panel.has_method("update_stats"):
        var stats = {
            "episode": episode_count,
            "step": current_step,
            "fps": average_fps,
            "probe_count": get_tree().get_nodes_in_group("probes").size(),
            "resources_mined": total_resources_mined,
            "active_resources": get_tree().get_nodes_in_group("resources").filter(func(r): return r.current_amount > 0).size()
        }
        stats_panel.update_stats(stats)

# Signal handlers
func _on_probe_destroyed(probe: Probe):
    print("Probe ", probe.probe_id, " destroyed")
    probe_count_changed.emit(get_tree().get_nodes_in_group("probes").size() - 1)

func _on_replication_requested(parent_probe: Probe):
    create_child_probe(parent_probe)

func create_child_probe(parent: Probe):
    var probe_scene = preload("res://probes/Probe.tscn")
    var child_probe = probe_scene.instantiate()
    
    # Generate new unique ID
    var existing_ids = []
    for probe in get_tree().get_nodes_in_group("probes"):
        existing_ids.append(probe.probe_id)
    
    var new_id = 1
    while new_id in existing_ids:
        new_id += 1
    
    # Configure child probe
    child_probe.probe_id = new_id
    child_probe.generation = parent.generation + 1
    child_probe.current_energy = ConfigManager.config.initial_energy
    child_probe.max_energy = ConfigManager.config.max_energy
    
    # Position near parent
    var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
    child_probe.global_position = parent.global_position + offset
    
    probe_manager.add_child(child_probe)
    child_probe.add_to_group("probes")
    connect_probe_signals(child_probe)
    
    print("Probe ", parent.probe_id, " replicated. Created probe ", new_id, " (generation ", child_probe.generation, ")")
    probe_count_changed.emit(get_tree().get_nodes_in_group("probes").size())

func _on_resource_discovered_by_probe(probe: Probe, resource_position: Vector2, amount: float):
    print("Probe ", probe.probe_id, " discovered resource at ", resource_position, " with amount ", amount)

func _on_communication_sent(from_probe: Probe, to_position: Vector2, message_type: String):
    print("Probe ", from_probe.probe_id, " sent ", message_type, " to ", to_position)

func _on_resource_depleted(resource: Resource):
    print("Resource depleted at ", resource.global_position)

func _on_resource_harvested(resource: Resource, harvesting_probe: Probe, amount: float):
    total_resources_mined += amount
    print("Probe ", harvesting_probe.probe_id, " harvested ", amount, " from resource")

func _on_probe_selected(probe_id: int):
    # Handle probe selection for camera following and UI updates
    var selected_probe = null
    for probe in get_tree().get_nodes_in_group("probes"):
        if probe.probe_id == probe_id:
            selected_probe = probe
            break
    
    if selected_probe:
        camera.get_child(0).set_target(selected_probe)  # Assuming camera controller is first child

# Input handling
func _input(event):
    if event.is_action_pressed("pause_simulation"):
        toggle_simulation_pause()
    elif event.is_action_pressed("reset_simulation"):
        start_new_episode()
    elif event.is_action_pressed("save_simulation"):
        manual_save_simulation()
    elif event.is_action_pressed("load_simulation"):
        show_load_dialog()

func toggle_simulation_pause():
    simulation_running = !simulation_running
    if simulation_running:
        simulation_started.emit()
        print("Simulation resumed")
    else:
        simulation_paused.emit()
        print("Simulation paused")

func manual_save_simulation():
    var save_data = create_save_data()
    var save_path = "user://manual_save_" + str(Time.get_unix_time_from_system()) + ".tres"
    ResourceSaver.save(save_data, save_path)
    print("Manual save completed: ", save_path)

func show_load_dialog():
    # Implementation would show file dialog for loading saved simulations
    pass