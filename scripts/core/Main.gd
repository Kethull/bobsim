extends Node2D
class_name Main

# --- OnReady Node References ---
# These nodes are expected to be children of Main in the Main.tscn scene
@onready var game_camera: Camera2D = $GameCamera # Renamed from 'camera' for clarity
@onready var solar_system_node: SolarSystem = $SolarSystem
@onready var ui_manager_node: ModernUI = $UICanvasLayer/ModernUI # Assuming UI is on a CanvasLayer
@onready var game_manager_node: GameManager = $GameManager
# @onready var audio_manager_node: AudioManager = $AudioManager # If you have one

# --- Simulation State ---
var is_simulation_running: bool = true # Renamed from simulation_running
var current_episode_count: int = 0 # Renamed from episode_count
var enable_training_mode: bool = true # Renamed from training_mode

var current_selected_probe_id_main: int = -1 # Track selected probe at Main level

func _ready():
    # Ensure essential nodes are present
    if not is_instance_valid(game_camera): printerr("Main: GameCamera node not found!")
    if not is_instance_valid(solar_system_node): printerr("Main: SolarSystem node not found!")
    if not is_instance_valid(ui_manager_node): printerr("Main: ModernUI node not found!")
    if not is_instance_valid(game_manager_node): printerr("Main: GameManager node not found!")

    _initial_camera_setup()
    _connect_system_signals()
    
    start_main_simulation_loop()

func _initial_camera_setup():
    if is_instance_valid(game_camera):
        game_camera.position = Config.World.CENTER_SIM
        game_camera.zoom = Vector2.ONE * Config.Visualization.INITIAL_ZOOM # Use a config value for initial zoom
        # Enable smoothing for camera movement
        game_camera.position_smoothing_enabled = true
        game_camera.position_smoothing_speed = 5.0 # Adjust as needed

func _connect_system_signals():
    if is_instance_valid(solar_system_node):
        solar_system_node.probe_created_in_system.connect(_on_solar_system_probe_created)
        solar_system_node.probe_destroyed_in_system.connect(_on_solar_system_probe_destroyed)
        solar_system_node.all_probes_dead.connect(_on_all_probes_dead_in_system)
        # solar_system_node.simulation_step_completed.connect(_on_simulation_step_done) # If needed

    if is_instance_valid(ui_manager_node):
        ui_manager_node.probe_selection_changed.connect(_on_ui_probe_selection_changed)

    # GameManager might emit signals like 'training_epoch_completed' if needed.

func start_main_simulation_loop():
    if is_instance_valid(game_manager_node):
        game_manager_node.initialize_game_state() # Renamed from initialize
    
    if is_instance_valid(solar_system_node):
        solar_system_node.initialize_environment() # Reset and set up solar system entities

    # The original guide had a loop for episodes here.
    # In Godot, the game loop is continuous via _process or _physics_process.
    # Episode logic (resetting, learning phases) will be managed by GameManager or triggered by events.
    # For now, we just ensure the simulation starts.
    # If you need explicit episodes, GameManager would control the reset and learning triggers.
    print("Main: Simulation started. Game loop is active via Godot's process functions.")
    # If a fixed number of episodes is desired, a counter and logic in _process or a timer could handle it.
    # For now, let it run indefinitely until 'ui_cancel'.


func _physics_process(delta: float): # Using physics process for simulation logic
    if not is_simulation_running:
        return

    # 1. Handle Input (moved to _unhandled_input for better event propagation)

    # 2. Step the Solar System Simulation (SolarSystem has its own _physics_process)
    # solar_system_node._physics_process(delta) # This is called automatically by Godot

    # 3. Update Game Manager (if it needs per-step updates not tied to specific entity physics)
    if is_instance_valid(game_manager_node):
        game_manager_node.update_game_step(delta) # Example method if needed

    # 4. Camera Update
    _update_game_camera_movement(delta)

    # 5. UI Update (push data to UI)
    _update_main_ui_display()
    
    # Episode management / learning triggers would go here if not event-driven
    # For example, after N steps, trigger learning phase.
    # if enable_training_mode and solar_system_node.current_step_count % Config.RL.LEARNING_INTERVAL_STEPS == 0:
    #     _trigger_learning_phase()


func _unhandled_input(event: InputEvent):
    if not is_simulation_running:
        return

    # UI Input (pass to UI manager first)
    if is_instance_valid(ui_manager_node) and ui_manager_node.has_method("_input"): # Check if UI wants to handle it
         # ui_manager_node._input(event) # Let UI handle its own input if needed, or connect to its signals
         # If UI consumes it, it should call get_viewport().set_input_as_handled()
        pass # ModernUI connects to ItemList signals, specific button signals, etc.

    # Global Input (if not handled by UI)
    if event.is_action_just_pressed("ui_cancel"):
        is_simulation_running = false
        print("Main: Simulation paused/stopped by user (ui_cancel).")
        get_tree().quit() # Or show a menu, etc.

    # Camera Zoom Input
    if is_instance_valid(game_camera):
        var zoom_increment = 0.1 # Configurable
        if event.is_action_pressed("zoom_in"): # Continuous zoom if held
            game_camera.zoom /= (1.0 + zoom_increment) # Zoom in = decrease zoom value
            get_viewport().set_input_as_handled()
        elif event.is_action_pressed("zoom_out"):
            game_camera.zoom *= (1.0 + zoom_increment) # Zoom out = increase zoom value
            get_viewport().set_input_as_handled()
        
        # Clamp zoom
        game_camera.zoom = game_camera.zoom.clamp(Vector2(Config.Visualization.MIN_ZOOM, Config.Visualization.MIN_ZOOM), 
                                                 Vector2(Config.Visualization.MAX_ZOOM, Config.Visualization.MAX_ZOOM))


func _update_game_camera_movement(delta: float):
    if not is_instance_valid(game_camera) or not is_instance_valid(solar_system_node):
        return

    if current_selected_probe_id_main != -1:
        var selected_probe: Probe = solar_system_node.get_probe_instance_by_id(current_selected_probe_id_main)
        if is_instance_valid(selected_probe) and selected_probe.alive:
            # Smoothly follow the selected probe
            game_camera.global_position = game_camera.global_position.lerp(selected_probe.global_position, Config.Visualization.CAMERA_FOLLOW_SPEED * delta)
        # else: # If probe is dead or invalid, maybe revert to default view or hold last position
            # current_selected_probe_id_main = -1 # Stop following
    else:
        # Allow free camera movement if no probe is selected (TODO: Implement free cam controls)
        # For now, it just stays or can be manually moved by other inputs if implemented
        pass


func _update_main_ui_display():
    if not is_instance_valid(ui_manager_node) or not is_instance_valid(solar_system_node):
        return

    var env_data = solar_system_node.get_simulation_environment_data()
    var fps = Performance.get_monitor(Performance.TIME_FPS)
    var cam_zoom = game_camera.zoom.x if is_instance_valid(game_camera) else 1.0
    
    ui_manager_node.update_simulation_data(
        env_data,
        current_selected_probe_id_main,
        cam_zoom,
        fps
    )

func _trigger_learning_phase():
    if not is_instance_valid(game_manager_node) or not enable_training_mode:
        return
        
    print("Main: Triggering learning phase for AI agents...")
    game_manager_node.perform_global_learning_step()


# --- Signal Handlers from other systems ---
func _on_solar_system_probe_created(probe_instance: Probe):
    if is_instance_valid(game_manager_node) and is_instance_valid(probe_instance):
        game_manager_node.register_new_probe_agent(probe_instance)
    # If no probe is selected, select the first one created
    if current_selected_probe_id_main == -1 and is_instance_valid(probe_instance):
        current_selected_probe_id_main = probe_instance.probe_id
        if is_instance_valid(ui_manager_node):
            ui_manager_node.set_selected_probe_externally(current_selected_probe_id_main)


func _on_solar_system_probe_destroyed(probe_instance: Probe): # Probe instance might be invalid soon
    if is_instance_valid(game_manager_node) and is_instance_valid(probe_instance): # Check instance validity
        game_manager_node.unregister_probe_agent(probe_instance.probe_id) # Pass ID
    
    if probe_instance and probe_instance.probe_id == current_selected_probe_id_main:
        current_selected_probe_id_main = -1 # Deselect if the selected probe was destroyed
        if is_instance_valid(ui_manager_node):
             ui_manager_node.set_selected_probe_externally(-1) # Update UI

func _on_all_probes_dead_in_system():
    print("Main: All probes are dead. Episode might end here.")
    # Potentially trigger end of episode, reset, or specific game over logic
    # if enable_training_mode:
        # _trigger_learning_phase() # Final learning before reset
        # current_episode_count += 1
        # print("Main: Episode %d ended." % current_episode_count)
        # if current_episode_count < Config.RL.MAX_EPISODES_PER_TRAINING_RUN:
            # solar_system_node.initialize_environment() # Reset for new episode
            # game_manager_node.reset_agents_for_new_episode()
        # else:
            # print("Main: Max training episodes reached.")
            # is_simulation_running = false
    # else: # Non-training mode
        # print("Main: Game Over - All probes lost.")
        # is_simulation_running = false # Or show a game over screen

func _on_ui_probe_selection_changed(newly_selected_probe_id: int):
    current_selected_probe_id_main = newly_selected_probe_id
    # Camera will pick this up in _update_game_camera_movement
    # UI is already updated by itself, this is just to keep Main's state in sync.