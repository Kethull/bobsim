extends Resource
class_name CelestialBodyData

@export var id: String = ""
@export var celestial_name: String = "Unnamed Celestial Body"
@export var mass: float = 1.0
@export var radius: float = 100.0
@export var celestial_position: Vector2 = Vector2.ZERO # Renamed to avoid potential conflicts
@export var celestial_velocity: Vector2 = Vector2.ZERO # Renamed to avoid potential conflicts
@export var resource_deposits: Array[ResourceData] = []