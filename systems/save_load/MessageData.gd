# MessageData.gd
extends Resource
class_name MessageData

@export var sender_id: int = 0
@export var message_type: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var timestamp: int = 0
@export var data: Dictionary = {}