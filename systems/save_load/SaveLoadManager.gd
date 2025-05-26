# SaveLoadManager.gd (AutoLoad)
extends Node

const ProbeData = preload("res://systems/save_load/ProbeData.gd")
const ResourceData = preload("res://systems/save_load/ResourceData.gd")
const CelestialBodyData = preload("res://systems/save_load/CelestialBodyData.gd")

var current_save_data: SimulationSaveData
var autosave_enabled: bool = true
var autosave_interval: float = 300.0  # 5 minutes
var max_autosaves: int = 5
var last_autosave_time: float = 0.0

signal save_completed(save_path: String)
signal load_completed(save_data: SimulationSaveData)
signal save_failed(error_message: String)
signal load_failed(error_message: String)

func _ready():
    # Create save directory if it doesn't exist
    DirAccess.make_dir_absolute("user://saves/")

func _process(delta):
    if autosave_enabled:
        last_autosave_time += delta
        if last_autosave_time >= autosave_interval:
            last_autosave_time = 0.0
            autosave()

func save_simulation(file_name: String = "") -> bool:
    var save_data = create_save_data()
    
    if file_name.is_empty():
        var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
        file_name = "simulation_" + timestamp + ".tres"
    
    var save_path = "user://saves/" + file_name
    
    var error = ResourceSaver.save(save_data, save_path)
    if error == OK:
        print("Simulation saved to: ", save_path)
        save_completed.emit(save_path)
        return true
    else:
        var error_msg = "Failed to save simulation: " + str(error)
        print(error_msg)
        save_failed.emit(error_msg)
        return false

func load_simulation(file_path: String) -> bool:
    if not ResourceLoader.exists(file_path):
        var error_msg = "Save file does not exist: " + file_path
        print(error_msg)
        load_failed.emit(error_msg)
        return false
    
    var save_data = ResourceLoader.load(file_path)
    if not save_data is SimulationSaveData:
        var error_msg = "Invalid save file format: " + file_path
        print(error_msg)
        load_failed.emit(error_msg)
        return false
    
    current_save_data = save_data
    apply_save_data(save_data)
    
    print("Simulation loaded from: ", file_path)
    load_completed.emit(save_data)
    return true

func create_save_data() -> SimulationSaveData:
    var save_data = SimulationSaveData.new()
    
    # Basic simulation state
    save_data.save_timestamp = Time.get_datetime_string_from_system()
    save_data.episode_count = get_simulation_manager().episode_count
    save_data.current_step = get_simulation_manager().current_step
    save_data.total_resources_mined = get_simulation_manager().total_resources_mined
    save_data.simulation_running = get_simulation_manager().simulation_running
    
    # Camera state
    var camera = get_tree().get_first_node_in_group("camera")
    if camera:
        save_data.camera_position = camera.global_position
        save_data.camera_zoom = camera.zoom.x
    
    # UI state
    var ui = get_tree().get_first_node_in_group("ui")
    if ui and ui.has_method("get_selected_probe_id"):
        save_data.selected_probe_id = ui.get_selected_probe_id()
    
    # Probe data
    for probe in get_tree().get_nodes_in_group("probes"):
        var probe_data = ProbeData.new()
        probe_data.id = probe.probe_id
        probe_data.generation = probe.generation
        probe_data.position = probe.global_position
        probe_data.velocity = probe.linear_velocity
        probe_data.rotation = probe.rotation
        probe_data.angular_velocity = probe.angular_velocity
        probe_data.energy = probe.current_energy
        probe_data.max_energy = probe.max_energy
        probe_data.is_alive = probe.is_alive
        probe_data.current_task = probe.current_task
        probe_data.current_target_id = probe.current_target_id
        probe_data.trail_points = probe.trail_points.duplicate()
        
        # AI state
        if probe.ai_agent:
            probe_data.ai_enabled = probe.ai_agent.use_external_ai
            probe_data.last_action = probe.ai_agent.current_action.duplicate()
        
        save_data.probes.append(probe_data)
    
    # Resource data
    for resource in get_tree().get_nodes_in_group("resources"):
        var resource_data = ResourceData.new()
        resource_data.position = resource.global_position
        resource_data.current_amount = resource.current_amount
        resource_data.max_amount = resource.max_amount
        resource_data.resource_type = resource.resource_type
        resource_data.regeneration_rate = resource.regeneration_rate
        resource_data.discovered_by = resource.discovered_by.duplicate()
        resource_data.harvest_difficulty = resource.harvest_difficulty
        
        save_data.resources.append(resource_data)
    
    # Celestial body data
    for body in get_tree().get_nodes_in_group("celestial_bodies"):
        var body_data = CelestialBodyData.new()
        body_data.name = body.body_name
        body_data.position = body.global_position
        body_data.velocity = body.linear_velocity
        body_data.mass_kg = body.mass_kg
        body_data.radius_km = body.radius_km
        body_data.orbit_points = body.orbit_points.duplicate()
        
        save_data.celestial_bodies.append(body_data)
    
    return save_data

func apply_save_data(save_data: SimulationSaveData):
    var sim_manager = get_simulation_manager()
    if not sim_manager:
        push_error("SimulationManager not found")
        return
    
    # Stop current simulation
    sim_manager.simulation_running = false
    
    # Clear existing entities
    clear_simulation_entities()
    
    # Restore simulation state
    sim_manager.episode_count = save_data.episode_count
    sim_manager.current_step = save_data.current_step
    sim_manager.total_resources_mined = save_data.total_resources_mined
    
    # Restore camera state
    var camera = get_tree().get_first_node_in_group("camera")
    if camera:
        camera.global_position = save_data.camera_position
        camera.zoom = Vector2.ONE * save_data.camera_zoom
    
    # Restore probes
    restore_probes(save_data.probes)
    
    # Restore resources
    restore_resources(save_data.resources)
    
    # Restore celestial bodies (positions and velocities)
    restore_celestial_bodies(save_data.celestial_bodies)
    
    # Resume simulation
    sim_manager.simulation_running = save_data.simulation_running
    
    print("Save data applied successfully")

func clear_simulation_entities():
    # Clear probes
    for probe in get_tree().get_nodes_in_group("probes"):
        probe.queue_free()
    
    # Clear messages
    for message in get_tree().get_nodes_in_group("messages"):
        message.queue_free()
    
    # Resources will be updated in place

func restore_probes(probe_data_array: Array[ProbeData]):
    var probe_scene = preload("res://probes/Probe.tscn")
    var probe_manager = get_tree().get_first_node_in_group("probe_manager")
    
    for probe_data in probe_data_array:
        var probe = probe_scene.instantiate()
        
        # Restore basic properties
        probe.probe_id = probe_data.id
        probe.generation = probe_data.generation
        probe.global_position = probe_data.position
        probe.linear_velocity = probe_data.velocity
        probe.rotation = probe_data.rotation
        probe.angular_velocity = probe_data.angular_velocity
        probe.current_energy = probe_data.energy
        probe.max_energy = probe_data.max_energy
        probe.is_alive = probe_data.is_alive
        probe.current_task = probe_data.current_task
        probe.current_target_id = probe_data.current_target_id
        probe.trail_points = probe_data.trail_points.duplicate()
        
        probe_manager.add_child(probe)
        probe.add_to_group("probes")
        
        # Restore AI state
        if probe.ai_agent and probe_data.ai_enabled:
            probe.ai_agent.current_action = probe_data.last_action.duplicate()
        
        # Connect signals
        get_simulation_manager().connect_probe_signals(probe)

func restore_resources(resource_data_array: Array[ResourceData]):
    var existing_resources = get_tree().get_nodes_in_group("resources")
    
    # Update existing resources or create new ones
    for i in range(resource_data_array.size()):
        var resource_data = resource_data_array[i]
        var resource = null
        
        if i < existing_resources.size():
            resource = existing_resources[i]
        else:
            # Create new resource if needed
            var resource_scene = preload("res://resources/Resource.tscn")
            resource = resource_scene.instantiate()
            get_tree().get_first_node_in_group("resource_manager").add_child(resource)
            resource.add_to_group("resources")
        
        # Restore resource properties
        resource.global_position = resource_data.position
        resource.current_amount = resource_data.current_amount
        resource.max_amount = resource_data.max_amount
        resource.resource_type = resource_data.resource_type
        resource.regeneration_rate = resource_data.regeneration_rate
        resource.discovered_by = resource_data.discovered_by.duplicate()
        resource.harvest_difficulty = resource_data.harvest_difficulty
        
        # Update visual state
        resource.update_visual_state()

func restore_celestial_bodies(body_data_array: Array[CelestialBodyData]):
    var existing_bodies = get_tree().get_nodes_in_group("celestial_bodies")
    
    for body_data in body_data_array:
        # Find matching celestial body by name
        var matching_body = null
        for body in existing_bodies:
            if body.body_name == body_data.name:
                matching_body = body
                break
        
        if matching_body:
            # Restore position and velocity
            matching_body.global_position = body_data.position
            matching_body.linear_velocity = body_data.velocity
            matching_body.orbit_points = body_data.orbit_points.duplicate()

func autosave():
    if not autosave_enabled:
        return
    
    var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
    var autosave_name = "autosave_" + timestamp + ".tres"
    
    if save_simulation(autosave_name):
        # Clean up old autosaves
        cleanup_old_autosaves()

func cleanup_old_autosaves():
    var dir = DirAccess.open("user://saves/")
    if not dir:
        return
    
    var autosave_files = []
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.begins_with("autosave_") and file_name.ends_with(".tres"):
            autosave_files.append(file_name)
        file_name = dir.get_next()
    
    # Sort by modification time (newest first)
    autosave_files.sort_custom(func(a, b): 
        var time_a = FileAccess.get_modified_time("user://saves/" + a)
        var time_b = FileAccess.get_modified_time("user://saves/" + b)
        return time_a > time_b
    )
    
    # Remove excess autosaves
    for i in range(max_autosaves, autosave_files.size()):
        dir.remove(autosave_files[i])
        print("Removed old autosave: ", autosave_files[i])

func get_simulation_manager():
    return get_tree().get_first_node_in_group("simulation_manager")

func get_save_files() -> Array[String]:
    var save_files = []
    var dir = DirAccess.open("user://saves/")
    if not dir:
        return save_files
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        if file_name.ends_with(".tres"):
            save_files.append(file_name)
        file_name = dir.get_next()
    
    return save_files

func delete_save_file(file_name: String) -> bool:
    var file_path = "user://saves/" + file_name
    var dir = DirAccess.open("user://saves/")
    if dir and dir.file_exists(file_name):
        return dir.remove(file_name) == OK
    return false