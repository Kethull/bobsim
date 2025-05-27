extends Resource
class_name ProbeData

@export var id: String = ""
@export var probe_type: String = "default" # e.g., "mining", "scout", "constructor"
@export var probe_position: Vector2 = Vector2.ZERO
@export var probe_velocity: Vector2 = Vector2.ZERO
@export var energy_level: float = 0.0
@export var status: String = "idle" # e.g., "idle", "mining", "moving_to_target", "returning_to_base"
@export var ai_state: String = "" # Detailed current AI task or state

@export var target_celestial_body_id: String = "" # ID of celestial body target, if any
@export var target_resource_id: String = "" # ID of resource node target, if any
@export var target_probe_id: String = "" # ID of another probe target, if any

# For resources_carried, an Array of Dictionaries is a flexible start.
# Each dictionary could be e.g.: {"type": "Iron", "amount": 10.0}
@export var resources_carried: Array[Dictionary] = []

func _init(p_id: String = "", p_type: String = "default", p_pos: Vector2 = Vector2.ZERO, p_energy: float = 100.0):
    id = p_id
    probe_type = p_type
    probe_position = p_pos
    energy_level = p_energy
    # Initialize other fields as needed or leave to defaults