extends Node
class_name Config

# Fundamental Physical Constants
const AU_KM = 149597870.7
const GRAVITATIONAL_CONSTANT = 6.67430e-20 # km^3 kg^-1 s^-2
const SECONDS_PER_DAY = 86400.0

# Simulation Scale Constants
const AU_SCALE = 10000.0 # Arbitrary units in simulation per AU
const KM_SCALE = AU_SCALE / AU_KM # Arbitrary units in simulation per KM

# World Configuration
class World:
    const SIZE_AU = 10.0 # Size of the simulation area in AU
    const SIZE_SIM = SIZE_AU * AU_SCALE # Size of the simulation area in simulation units
    const WIDTH_SIM = SIZE_SIM
    const HEIGHT_SIM = SIZE_SIM
    const CENTER_SIM = Vector2(WIDTH_SIM / 2.0, HEIGHT_SIM / 2.0)

    # Asteroid Belt (example values)
    const ASTEROID_BELT_INNER_AU = 2.2
    const ASTEROID_BELT_OUTER_AU = 3.2
    const ASTEROID_COUNT = 500

# Physics Configuration
class Physics:
    const TIMESTEP_SECONDS = 3600.0 # e.g., 1 hour per simulation step
    const INTEGRATION_METHOD = "verlet" # As specified in doc, though OrbitalMechanics uses a specific Verlet
    const DEFAULT_PROBE_MASS_KG = 8.0

# Probe Configuration
class Probe:
    const MAX_PROBES = 20
    const INITIAL_PROBES = 1
    const MAX_ENERGY = 100000.0
    const INITIAL_ENERGY = 90000.0
    const REPLICATION_COST = 80000.0
    const MAX_VELOCITY_SIM_PER_STEP = 10000.0 # Max speed in simulation units per physics step

    const THRUST_FORCE_MAGNITUDES = [0.0, 0.08, 0.18, 0.32] # Discrete thrust levels
    const THRUST_ENERGY_COST_FACTOR = 0.001 # Energy cost per unit of thrust force per second (or step)
    const ENERGY_DECAY_RATE_PER_STEP = 0.001 # Passive energy decay per step

    const MOMENT_OF_INERTIA = 5.0 # For rotational physics
    const TORQUE_MAGNITUDES = [0.0, 0.008, 0.018] # Discrete torque levels (0, low, med)
    const MAX_ANGULAR_VELOCITY_RAD_PER_STEP = PI / 4.0 # Max rotation speed
    const ANGULAR_DAMPING_FACTOR = 0.05 # To slow down rotation over time
    const ROTATIONAL_ENERGY_COST_FACTOR = 0.0005 # Energy cost for torque

# Solar System Data
var PLANET_DATA = {
    "Sun": {
        "mass_kg": 1.9885e30,
        "radius_km": 695700.0,
        "display_radius_sim": 500.0, # Visual radius in simulation units
        "color": Color.YELLOW,
        "semi_major_axis_au": 0.0,
        "eccentricity": 0.0,
        "central_body": null # Sun is the central body for itself (or for the system)
    },
    "Earth": {
        "mass_kg": 5.97237e24,
        "radius_km": 6371.0,
        "display_radius_sim": 50.0,
        "color": Color.BLUE,
        "semi_major_axis_au": 1.0,
        "eccentricity": 0.0167,
        "inclination_deg": 0.0, # Relative to ecliptic
        "longitude_of_ascending_node_deg": 0.0, # Omega
        "argument_of_perihelion_deg": 114.2, # omega (lowercase)
        "mean_anomaly_at_epoch_deg": 357.5, # M0
        "central_body": "Sun"
    }
    # Add other celestial bodies as per SolarSystem.gd create_celestial_bodies:
    # "Mercury": { ... }, "Venus": { ... }, "Mars": { ... },
    # "Jupiter": { ... }, "Saturn": { ... }, "Uranus": { ... }, "Neptune": { ... }
}

# Visualization Configuration
class Visualization:
    const SCREEN_WIDTH = 1400
    const SCREEN_HEIGHT = 900
    const FPS = 60
    const PROBE_SIZE_PX = 12 # Base size for probe visuals
    const ORGANIC_SHIP_ENABLED = true
    const ENABLE_PARTICLE_EFFECTS = true
    const MAX_ORBIT_PATH_POINTS = 1000 # For celestial bodies
    const MAX_PROBE_TRAIL_POINTS = 500 # For probes
    const MAX_PARTICLES_PER_SYSTEM = 500 # For ParticleSystem manager

# Resource Configuration
class SimResource:
    const COUNT = 100 # Initial number of resource nodes
    const MIN_AMOUNT = 50.0
    const MAX_AMOUNT = 200.0
    const BASE_DISPLAY_RADIUS = 10.0 # Visual base size in sim units
    const REGEN_RATE_PER_STEP = 0.1 # Amount regenerated per physics step (if applicable per second)
    const HARVEST_DISTANCE_SIM = 50.0 # Max distance to harvest
    const HARVEST_RATE_PER_STEP = 1.0 # Amount harvested per step if in range
    const ENERGY_CONVERSION_RATE = 5.0 # Energy gained per unit of resource

# Reinforcement Learning / AI Configuration
class RL:
    const OBSERVATION_SPACE_SIZE = 16 # Probe: 7 + Nearest Resources: 3 * 3 = 9 -> 7+9=16
    # Action space: [Thrust(0-3), Torque(-2 to 2 -> 5 levels), Communicate(0/1), Replicate(0/1), TargetResource(0-3 -> 0:none, 1-3:res1-3)]
    # Thrust levels: Config.Probe.THRUST_FORCE_MAGNITUDES.size() (e.g., 4)
    # Torque levels: Config.Probe.TORQUE_MAGNITUDES.size() * 2 - 1 (e.g., 3*2-1 = 5 for +/- low/med and zero)
    const ACTION_SPACE_DIMS = [4, 5, 2, 2, 4] # Corresponds to sizes of discrete action components
    const NUM_OBSERVED_RESOURCES_FOR_TARGETING = 3 # How many nearest resources are part of observation/targeting
    const BATCH_SIZE = 64
    const GAMMA = 0.99 # Discount factor for future rewards
    const LEARNING_RATE = 0.001
    const EPISODE_LENGTH_STEPS = 5000 # Max steps per training episode
    const MUTATION_RATE_INITIAL = 0.1
    const MUTATION_STRENGTH_INITIAL = 0.05
    const HIDDEN_LAYER_SIZES = [64, 32] # Default hidden layer sizes for NN
    const DEFAULT_ACTION_OUTPUT_SIZE = 1 # Fallback for NN output size
    const LEARNING_ENABLED_DEFAULT = true
    const EXPERIENCE_BUFFER_SIZE = 10000
    const LEARN_EVERY_N_STEPS = 4 # Learn every N simulation steps

    # Epsilon-greedy strategy parameters
    const EPSILON_START = 1.0
    const EPSILON_END = 0.01
    const EPSILON_DECAY_STEPS = 100000
    static var EPSILON_CURRENT = EPSILON_START # This will be decayed over time
    const EPSILON_MIN = 0.01 # Minimum epsilon value
    const EPSILON_DECAY_RATE = 0.9995 # Multiplicative decay factor

    static func get_epsilon_current() -> float:
        return EPSILON_CURRENT

    static func set_epsilon_current(value: float):
        EPSILON_CURRENT = value

    static func decay_epsilon_value(): # Renamed to avoid conflict if a field was also named decay_epsilon
        if EPSILON_CURRENT > EPSILON_MIN:
            EPSILON_CURRENT *= EPSILON_DECAY_RATE
            EPSILON_CURRENT = max(EPSILON_CURRENT, EPSILON_MIN)

    # Random action fallback for uninitialized model
    const RANDOM_ACTION_LOW_FALLBACK = -1.0
    const RANDOM_ACTION_HIGH_FALLBACK = 1.0
    
    # Observation indices (example, adjust as per actual observation vector structure)
    const OBS_IDX_ENERGY = 6 # Assuming energy is the 7th element (0-indexed)

    # Reward/Penalty constants
    const REWARD_ALIVE_PER_STEP = 0.01 # Renamed from STAY_ALIVE_REWARD_BONUS_PER_STEP for consistency
    const HIGH_ENERGY_THRESHOLD = 0.8 # Renamed from HIGH_ENERGY_THRESHOLD_PERCENT
    const REWARD_HIGH_ENERGY_BONUS = 0.1 # Renamed from HIGH_ENERGY_REWARD_BONUS
    const PENALTY_LOW_ENERGY_THRESHOLD_1 = 0.3 # Renamed from LOW_ENERGY_PENALTY_LEVEL_1_THRESHOLD_PERCENT
    const PENALTY_LOW_ENERGY_FACTOR_1 = 0.05 # Renamed from LOW_ENERGY_PENALTY_LEVEL_1_FACTOR
    const PENALTY_LOW_ENERGY_THRESHOLD_2 = 0.1 # Renamed from LOW_ENERGY_PENALTY_LEVEL_2_THRESHOLD_PERCENT
    const PENALTY_LOW_ENERGY_FACTOR_2 = 0.1 # Renamed from LOW_ENERGY_PENALTY_LEVEL_2_FACTOR
    const REWARD_MINING_SUCCESS_PER_STEP = 0.02 # Renamed from SUSTAINED_MINING_REWARD_PER_STEP
    const REWARD_TARGET_PROXIMITY_FACTOR = 0.5 # Consistent name
    const REWARD_PROXIMITY_FALLOFF_DIST_SIM = 500.0 # Renamed from PROXIMITY_REWARD_FALLOFF_SIM
    const PENALTY_DEATH = 100.0 # Penalty for probe dying