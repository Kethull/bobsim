class_name AdaptiveQualityManager
extends Node

## Manages dynamic adjustment of game quality settings based on performance (FPS).
## This script is intended to be an AutoLoad singleton.

# References to other managers (expected to be AutoLoads)
var config_manager # ConfigManager instance
var game_config: GameConfiguration # Shortcut to config_manager.config

# FPS Monitoring
var current_fps: float = 60.0

# Thresholds and Timers for Hysteresis
@export var fps_check_interval: float = 1.0 # How often to check FPS and consider quality change
var _time_since_last_fps_check: float = 0.0

@export var low_fps_threshold_offset: int = 10 # FPS below target_fps - offset triggers downgrade consideration
@export var high_fps_threshold_offset: int = 15 # FPS above target_fps + offset triggers upgrade consideration

@export var duration_to_confirm_change: float = 3.0 # Seconds FPS must stay in new zone to change quality
var _time_in_low_fps_zone: float = 0.0
var _time_in_high_fps_zone: float = 0.0

func _ready() -> void:
	# Assuming ConfigManager is an AutoLoad named "ConfigManager"
	if not Engine.has_singleton("ConfigManager"):
		push_error("AdaptiveQualityManager: ConfigManager singleton not found! Adaptive quality will not function.")
		set_process(false) # Disable processing if ConfigManager is missing
		return
	
	config_manager = Engine.get_singleton("ConfigManager")
	if not config_manager or not config_manager.has_method("get_config"): # get_config or direct .config access
		push_error("AdaptiveQualityManager: ConfigManager is invalid or does not provide configuration. Adaptive quality will not function.")
		set_process(false)
		return
		
	game_config = config_manager.get_config() # Assuming ConfigManager has a get_config() method or a public 'config' var
	if not game_config:
		push_error("AdaptiveQualityManager: GameConfiguration not available from ConfigManager. Adaptive quality will not function.")
		set_process(false)
		return

	if not game_config.enable_adaptive_quality:
		print("AdaptiveQualityManager: Adaptive quality is disabled in GameConfiguration.")
		set_process(false) # Don't run if disabled globally
		return

	# Apply initial quality settings based on the configured current_quality_level
	_apply_quality_settings(game_config.current_quality_level)
	print("AdaptiveQualityManager initialized. Current quality: ", GameConfiguration.QualityLevel.keys()[game_config.current_quality_level])


func _process(delta: float) -> void:
	if not game_config or not game_config.enable_adaptive_quality:
		return

	_time_since_last_fps_check += delta
	if _time_since_last_fps_check >= fps_check_interval:
		_time_since_last_fps_check = 0.0
		current_fps = Performance.get_monitor(Performance.TIME_FPS)
		
		var target_fps = float(game_config.target_fps)
		var actual_low_threshold = target_fps - low_fps_threshold_offset
		var actual_high_threshold = target_fps + high_fps_threshold_offset

		if current_fps < actual_low_threshold:
			_time_in_low_fps_zone += fps_check_interval
			_time_in_high_fps_zone = 0.0 # Reset other zone timer
			if _time_in_low_fps_zone >= duration_to_confirm_change:
				_decrease_quality()
				_time_in_low_fps_zone = 0.0 # Reset timer after change
		elif current_fps > actual_high_threshold:
			_time_in_high_fps_zone += fps_check_interval
			_time_in_low_fps_zone = 0.0 # Reset other zone timer
			if _time_in_high_fps_zone >= duration_to_confirm_change:
				_increase_quality()
				_time_in_high_fps_zone = 0.0 # Reset timer after change
		else:
			# FPS is in the stable zone, reset timers
			_time_in_low_fps_zone = 0.0
			_time_in_high_fps_zone = 0.0

func _decrease_quality() -> void:
	var current_level_int = game_config.current_quality_level as int
	if current_level_int > GameConfiguration.QualityLevel.LOW as int:
		current_level_int -= 1
		game_config.current_quality_level = current_level_int
		_apply_quality_settings(game_config.current_quality_level)
		print("AdaptiveQualityManager: Quality decreased to ", GameConfiguration.QualityLevel.keys()[game_config.current_quality_level], " due to low FPS (", current_fps, ")")

func _increase_quality() -> void:
	var current_level_int = game_config.current_quality_level as int
	if current_level_int < GameConfiguration.QualityLevel.ULTRA as int:
		current_level_int += 1
		game_config.current_quality_level = current_level_int
		_apply_quality_settings(game_config.current_quality_level)
		print("AdaptiveQualityManager: Quality increased to ", GameConfiguration.QualityLevel.keys()[game_config.current_quality_level], " due to high FPS (", current_fps, ")")

func _apply_quality_settings(level: GameConfiguration.QualityLevel) -> void:
	if not game_config:
		push_error("AdaptiveQualityManager: Cannot apply quality settings, GameConfiguration is null.")
		return

	match level:
		GameConfiguration.QualityLevel.LOW:
			game_config.runtime_enable_particle_effects = game_config.particle_effects_on_low
			game_config.runtime_particle_density_factor = game_config.particle_density_low
			game_config.runtime_lod_distance_scale = game_config.lod_scale_low
			# game_config.runtime_max_active_sounds = 8 # Example
		GameConfiguration.QualityLevel.MEDIUM:
			game_config.runtime_enable_particle_effects = game_config.particle_effects_on_medium
			game_config.runtime_particle_density_factor = game_config.particle_density_medium
			game_config.runtime_lod_distance_scale = game_config.lod_scale_medium
			# game_config.runtime_max_active_sounds = 16 # Example
		GameConfiguration.QualityLevel.HIGH:
			game_config.runtime_enable_particle_effects = game_config.particle_effects_on_high
			game_config.runtime_particle_density_factor = game_config.particle_density_high
			game_config.runtime_lod_distance_scale = game_config.lod_scale_high
			# game_config.runtime_max_active_sounds = 32 # Example
		GameConfiguration.QualityLevel.ULTRA:
			game_config.runtime_enable_particle_effects = game_config.particle_effects_on_ultra
			game_config.runtime_particle_density_factor = game_config.particle_density_ultra
			game_config.runtime_lod_distance_scale = game_config.lod_scale_ultra
			# game_config.runtime_max_active_sounds = 48 # Example
		_:
			push_error("AdaptiveQualityManager: Unknown quality level specified: ", level)
			# Default to HIGH perhaps
			game_config.runtime_enable_particle_effects = game_config.particle_effects_on_high
			game_config.runtime_particle_density_factor = game_config.particle_density_high
			game_config.runtime_lod_distance_scale = game_config.lod_scale_high

	# Potentially emit a signal that quality settings have changed, so other systems can react if needed.
	# quality_settings_changed.emit(level)

	# IMPORTANT: This manager changes RUNTIME settings. It does NOT save them to disk
	# unless explicitly told to do so by another system or user action.
	# Saving would be done via config_manager.save_configuration()

# Public function to manually set a quality level if needed (e.g., from a settings menu)
func set_quality_level_manually(new_level: GameConfiguration.QualityLevel) -> void:
	if not game_config: return
	
	if new_level >= GameConfiguration.QualityLevel.LOW and new_level <= GameConfiguration.QualityLevel.ULTRA:
		game_config.current_quality_level = new_level
		_apply_quality_settings(new_level)
		# If set manually, perhaps disable adaptive quality temporarily or reset its timers?
		_time_in_low_fps_zone = 0.0
		_time_in_high_fps_zone = 0.0
		print("AdaptiveQualityManager: Quality manually set to ", GameConfiguration.QualityLevel.keys()[new_level])
	else:
		push_error("AdaptiveQualityManager: Invalid manual quality level set: ", new_level)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if game_config:
			print("AdaptiveQualityManager shutting down. Final quality level: ", GameConfiguration.QualityLevel.keys()[game_config.current_quality_level])