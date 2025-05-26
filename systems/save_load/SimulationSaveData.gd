extends Resource
class_name SimulationSaveData

@export var simulation_time: float = 0.0
@export var game_score: int = 0
@export var probes: Array[ProbeData] = []
@export var celestial_bodies: Array[CelestialBodyData] = []
@export var messages: Array[MessageData] = []
# Add any other global game state variables here
# For example:
# @export var research_points: int = 0
# @export var game_difficulty: String = "normal"