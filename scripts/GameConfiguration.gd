# GameConfiguration.gd
extends Resource
class_name GameConfiguration

# === World Configuration ===
@export_group("World Settings")
@export var world_size_au: float = 10.0
@export var asteroid_belt_inner_au: float = 2.2
@export var asteroid_belt_outer_au: float = 3.2
@export var asteroid_count: int = 500
@export var asteroid_mass_range: Vector2 = Vector2(1e10, 1e15)

# === Physics Configuration ===
@export_group("Physics Settings")
@export var timestep_seconds: float = 3600.0
@export var integration_method: String = "verlet"
@export var gravitational_constant: float = 6.67430e-20
@export var au_scale: float = 10000.0

# === Probe Configuration ===
@export_group("Probe Settings")
@export var max_probes: int = 20
@export var initial_probes: int = 1
@export var max_energy: float = 100000.0
@export var initial_energy: float = 90000.0
@export var replication_cost: float = 80000.0
@export var replication_min_energy: float = 99900.0
@export var probe_mass: float = 8.0
@export var thrust_force_magnitudes: Array[float] = [0.0, 0.08, 0.18, 0.32]
@export var thrust_energy_cost_factor: float = 0.001
@export var energy_decay_rate: float = 0.001
@export var max_velocity: float = 10000.0
@export var moment_of_inertia: float = 5.0
@export var torque_magnitudes: Array[float] = [0.0, 0.008, 0.018]
@export var max_angular_velocity: float = PI / 4
@export var communication_range: float = 100.0

# === Resource Configuration ===
@export_group("Resource Settings")
@export var resource_count: int = 15
@export var resource_amount_range: Vector2 = Vector2(10000, 20000)
@export var resource_regen_rate: float = 0.0
@export var harvest_rate: float = 2.0
@export var harvest_distance: float = 5.0
@export var discovery_range: float = 12.5

# === RL Configuration ===
@export_group("Reinforcement Learning")
@export var episode_length_steps: int = 50000
@export var learning_rate: float = 3e-4
@export var batch_size: int = 64
@export var observation_space_size: int = 25
@export var num_observed_resources: int = 3
@export var reward_factors: Dictionary = {
    "mining": 0.05,
    "high_energy": 0.1,
    "proximity": 1.95,
    "reach_target": 2.0,
    "stay_alive": 0.02
}

# === AI Settings Configuration ===
@export_group("AI Settings")
# Time interval between AI updates in seconds
@export var ai_update_interval_sec: float = 1.0
# Enable detailed logging of AI learning progress
@export var ai_debug_logging: bool = true
# Show visual indicators for AI decisions and states
@export var ai_show_debug_visuals: bool = true
# Save Q-learning table to disk when an episode ends
@export var q_learning_save_on_episode_end: bool = true
# Load Q-learning table from disk when an episode starts
@export var q_learning_load_on_episode_start: bool = true
# Filename for saving/loading Q-learning table
@export var q_learning_table_filename: String = "q_table_fallback.json"
# Timeout in seconds for external AI requests
@export var ai_request_timeout: float = 5.0
# Whether to use external AI service instead of local Q-learning
# CRITICAL: Must be false to avoid HTTP errors
@export var use_external_ai: bool = false

# === Visualization Configuration ===
@export_group("Visualization")
@export var screen_width: int = 1400
@export var screen_height: int = 900
# target_fps moved to Performance & Quality
@export var probe_size: int = 12
# enable_particle_effects moved to Performance & Quality
@export var enable_organic_ships: bool = true
@export var max_trail_points: int = 500
@export var max_orbit_points: int = 1000

# === Performance & Quality Configuration ===
@export_group("Performance & Quality")
enum QualityLevel { LOW, MEDIUM, HIGH, ULTRA } # Defines available quality presets
@export var target_fps: int = 60 # The desired target frame rate for the application.
@export var current_quality_level: QualityLevel = QualityLevel.HIGH # The game's current applied quality level.
@export var enable_adaptive_quality: bool = true # Master switch to enable/disable the adaptive quality system.

# Settings controllable by adaptive quality
@export_subgroup("Adaptive Settings Values") # These are the values applied AT each quality level
# Note: These are examples. Actual values would be fine-tuned.
@export var particle_effects_on_low: bool = false
@export var particle_density_low: float = 0.2
@export var lod_scale_low: float = 0.75

@export var particle_effects_on_medium: bool = true
@export var particle_density_medium: float = 0.5
@export var lod_scale_medium: float = 0.9

@export var particle_effects_on_high: bool = true
@export var particle_density_high: float = 1.0
@export var lod_scale_high: float = 1.0

@export var particle_effects_on_ultra: bool = true
@export var particle_density_ultra: float = 1.2 # Example: could allow even more if capable
@export var lod_scale_ultra: float = 1.1

# These are the RUNTIME settings that get modified by AdaptiveQualityManager
# They are not typically edited directly in the inspector if adaptive quality is on.
@export_subgroup("Runtime Applied Quality Settings")
@export var runtime_enable_particle_effects: bool = true
@export var runtime_particle_density_factor: float = 1.0 # Range 0.0 (none) to 1.0 (full)
@export var runtime_lod_distance_scale: float = 1.0 # Multiplier for LOD distances. <1 = lower detail sooner, >1 = higher detail further
# @export var runtime_max_active_sounds: int = 32 # Example

# === Debug Configuration ===
@export_group("Debug Settings")
@export var debug_mode: bool = false
@export var show_orbital_mechanics: bool = true
@export var show_energy_conservation: bool = true
@export var memory_warn_mb: int = 2048