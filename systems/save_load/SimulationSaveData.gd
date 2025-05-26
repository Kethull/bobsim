# SimulationSaveData.gd
extends Resource
class_name SimulationSaveData

@export var save_version: String = "1.0"
@export var save_timestamp: String = ""
@export var episode_count: int = 0
@export var current_step: int = 0
@export var total_resources_mined: float = 0.0
@export var simulation_running: bool = false

@export var probes: Array[ProbeData] = []
@export var resources: Array[ResourceData] = []
@export var celestial_bodies: Array[CelestialBodyData] = []
@export var messages: Array[MessageData] = []

@export var camera_position: Vector2 = Vector2.ZERO
@export var camera_zoom: float = 1.0
@export var selected_probe_id: int = -1

@export var performance_stats: Dictionary = {}