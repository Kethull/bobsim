extends Node

# Manages the game's configuration settings.
# This script is intended to be an AutoLoad.

# The game configuration resource.
var config: GameConfiguration

# The path to the configuration file.
var config_path: String = "user://game_config.tres"

# Signal emitted when configuration is loaded and validated.
signal configuration_loaded_and_validated

# Flag to indicate if the ConfigManager has completed its _ready() setup.
var is_fully_ready := false


func _ready():
	load_configuration() # This internally handles loading, creation, saving, and validation.
	
	is_fully_ready = true
	if config:
		configuration_loaded_and_validated.emit()
		print_debug("ConfigManager: Configuration loaded and signal emitted.")
	else:
		push_error("ConfigManager: config is null after load_configuration in _ready. Cannot emit configuration_loaded_and_validated.")
		print_debug("ConfigManager: config is null, signal NOT emitted.")


# Loads the game configuration from the specified path.
# If the configuration file doesn't exist, a new one is created.
func load_configuration():
	if ResourceLoader.exists(config_path):
		var loaded_resource = ResourceLoader.load(config_path)
		if loaded_resource is GameConfiguration:
			config = loaded_resource
		else: # Handle case where file exists but is not a valid resource or wrong type
			if loaded_resource != null:
				push_error("Loaded resource at %s is not a GameConfiguration. Type: %s. Creating a new one." % [config_path, typeof(loaded_resource)])
			else:
				push_error("Failed to load configuration file at %s (returned null). Creating a new one." % config_path)
			config = GameConfiguration.new()
			save_configuration()
	else:
		config = GameConfiguration.new()
		save_configuration()

	if not validate_configuration():
		push_error("Game configuration is invalid. Please check the settings.")
		# Optionally, reset to default or handle error appropriately
		# For now, we proceed with potentially invalid config, but errors are logged.


# Saves the current game configuration to the specified path.
func save_configuration():
	var error = ResourceSaver.save(config, config_path)
	if error != OK:
		push_error("Failed to save configuration file: %s. Error code: %s" % [config_path, error])


# Validates the current game configuration.
# Returns true if the configuration is valid, false otherwise.
func validate_configuration() -> bool:
	if config == null:
		push_error("Configuration is null.")
		return false

	var is_valid = true

	if config.world_size_au <= 0:
		push_error("World size (AU) must be greater than 0.")
		is_valid = false
	
	if config.asteroid_belt_inner_au >= config.asteroid_belt_outer_au:
		push_error("Asteroid belt inner radius must be less than outer radius.")
		is_valid = false
		
	if config.max_probes <= 0 or config.initial_probes <= 0:
		push_error("Max probes and initial probes must be greater than 0.")
		is_valid = false
	
	# Add more validation as needed
	
	return is_valid