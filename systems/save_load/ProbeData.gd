class_name ProbeData
extends Resource

@export var id: int = 0
@export var generation: int = 0
@export var position: Vector2 = Vector2.ZERO
@export var velocity: Vector2 = Vector2.ZERO
@export var rotation: float = 0.0
@export var angular_velocity: float = 0.0
@export var energy: float = 0.0
@export var max_energy: float = 100000.0
@export var is_alive: bool = true
@export var current_task: String = "idle"
@export var current_target_id: int = -1
@export var trail_points: Array[Vector2] = []

# AI state
@export var ai_enabled: bool = true
@export var last_action: Array[int] = [0, 0, 0, 0, 0]
@export var action_history: Array[Array] = []