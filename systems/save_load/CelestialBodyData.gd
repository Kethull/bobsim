extends Resource
class_name CelestialBodyData

@export var id: String = ""
@export var body_type: String = "planet"  # e.g., "planet", "moon", "asteroid_field", "star", "nebula"
@export var name: String = "Unnamed Body"
@export var position: Vector2 = Vector2.ZERO
@export var radius: float = 100.0 # Arbitrary unit for size
@export var mass: float = 1.0 # Arbitrary unit for mass, affects gravity

@export var atmosphere_type: String = "none" # e.g., "thin_oxygen", "methane", "corrosive"
@export var temperature: float = 0.0 # Kelvin or Celsius, be consistent
@export var gravity: float = 9.8 # m/s^2 or relative unit

# List of resource types available on/in this body, could be simple strings or more complex objects
@export var available_resources: Array[String] = [] 

# Orbit parameters if applicable
@export var orbits_body_id: String = "" # ID of the body it orbits, if any
@export var orbital_distance: float = 0.0
@export var orbital_period: float = 0.0 # In simulation days or standard time unit
@export var current_orbital_angle: float = 0.0 # Degrees or radians

# Other relevant properties
@export var description: String = ""
@export var discovered: bool = false
@export var discovery_date: String = "" # Timestamp or formatted date

func _init(p_id: String = "", p_name: String = "Unnamed", p_type: String = "planet", p_pos: Vector2 = Vector2.ZERO):
    id = p_id
    name = p_name
    body_type = p_type
    position = p_pos
    # Initialize other fields as needed