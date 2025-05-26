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

# === Visualization Configuration ===
@export_group("Visualization")
@export var screen_width: int = 1400
@export var screen_height: int = 900
@export var target_fps: int = 60
@export var probe_size: int = 12
@export var enable_particle_effects: bool = true
@export var enable_organic_ships: bool = true
@export var max_trail_points: int = 500
@export var max_orbit_points: int = 1000

# === Debug Configuration ===
@export_group("Debug Settings")
@export var debug_mode: bool = false
@export var show_orbital_mechanics: bool = true
@export var show_energy_conservation: bool = true
@export var memory_warn_mb: int = 2048