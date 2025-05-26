extends Resource
class_name MessageData

@export var sender_id: String = ""
@export var receiver_id: String = ""
@export var content: String = ""
@export var timestamp: float = 0.0 # Using float for Time.get_unix_time_from_system()
@export var message_type: String = "standard" # E.g., "standard", "alert", "discovery"