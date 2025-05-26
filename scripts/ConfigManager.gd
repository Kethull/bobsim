extends Node

var config: GameConfiguration
var config_path: String = "user://game_config.tres"

func _ready():
    load_configuration()

func load_configuration():
    if ResourceLoader.exists(config_path):
        config = ResourceLoader.load(config_path)
    else:
        config = GameConfiguration.new()
        save_configuration()

func save_configuration():
    ResourceSaver.save(config, config_path)

func validate_configuration() -> bool:
    # Comprehensive validation logic
    if config.world_size_au <= 0:
        push_error("World size must be positive")
        return false
    
    if config.asteroid_belt_inner_au >= config.asteroid_belt_outer_au:
        push_error("Asteroid belt inner radius must be less than outer radius")
        return false
    
    if config.max_probes <= 0 or config.initial_probes <= 0:
        push_error("Probe counts must be positive")
        return false
    
    # Add more validation as needed
    return true