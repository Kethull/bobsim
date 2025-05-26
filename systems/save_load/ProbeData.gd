extends Resource
class_name ProbeData

@export var id: String = ""
@export var probe_position: Vector2 = Vector2.ZERO
@export var probe_velocity: Vector2 = Vector2.ZERO
@export var energy_level: float = 100.0
@export var resources_carried: Array[ResourceData] = []
@export var ai_state: String = "idle" # Or could be an enum
@export var target_celestial_body_id: String = ""