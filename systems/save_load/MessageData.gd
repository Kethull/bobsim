extends Resource
class_name MessageData

@export var id: String = "" # Unique ID for the message
@export var timestamp: String = "" # Simulation time or real time when message was generated
@export var source: String = "System" # e.g., "Probe Alpha", "System", "AI Core", "Anomaly"
@export var content: String = "" # The actual message text
@export var message_type: String = "info" # e.g., "info", "warning", "error", "discovery", "narrative"
@export var priority: int = 0 # Lower numbers could be higher priority
@export var read: bool = false # Has the player seen this message?

# Optional: For messages linked to specific game entities
@export var related_entity_id: String = ""
@export var related_entity_type: String = "" # e.g., "Probe", "CelestialBody", "ResourceNode"

func _init(p_id: String = "", p_content: String = "", p_source: String = "System", p_type: String = "info"):
    id = p_id
    # Consider using Time.get_datetime_string_from_system() for a default timestamp
    timestamp = Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_system())
    source = p_source
    content = p_content
    message_type = p_type
    # Initialize other fields as needed