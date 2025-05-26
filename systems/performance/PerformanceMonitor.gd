class_name PerformanceMonitor
extends Node

## Monitors and provides information about system performance, starting with memory usage.

signal memory_usage_updated(memory_data_string: String, memory_data_dict: Dictionary)

@export var update_interval: float = 1.0 # Seconds
var _time_since_last_update: float = 0.0

func _process(delta: float) -> void:
	_time_since_last_update += delta
	if _time_since_last_update >= update_interval:
		_time_since_last_update = 0.0
		var data_dict := get_memory_usage_data()
		var data_string := get_formatted_memory_usage_string(data_dict)
		memory_usage_updated.emit(data_string, data_dict)
		# For debugging if no UI is connected yet:
		# print(data_string)

## Returns a dictionary containing current memory usage in bytes.
## Keys: "static", "dynamic", "physical_process", "free", "stack", "rss" (Resident Set Size)
func get_memory_usage_data() -> Dictionary:
	# Godot 4 uses Performance monitors for some, and OS.get_memory_info() for others.
	# OS.get_memory_info() is generally more comprehensive for process memory.
	var mem_info: Dictionary = OS.get_memory_info()

	# Extract relevant values, ensuring they exist.
	var static_mem_bytes: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	# Performance.MEMORY_DYNAMIC does not exist. Dynamic memory is part of the overall process physical memory.
	var physical_process_mem_bytes: int = mem_info.get("physical", 0) # Memory used by the game process (includes heap, etc.)
	var free_mem_bytes: int = mem_info.get("free", 0) # System-wide free memory
	var stack_mem_bytes: int = mem_info.get("stack", 0) # Process stack memory
	var rss_mem_bytes: int = mem_info.get("rss", 0) # Resident Set Size - actual physical RAM used by process

	return {
		"static_bytes": static_mem_bytes,
		"physical_process_bytes": physical_process_mem_bytes, # This is a good overall indicator for the game's heap + other allocations
		"system_free_bytes": free_mem_bytes,
		"system_stack_bytes": stack_mem_bytes,
		"process_rss_bytes": rss_mem_bytes, # Often the most practical value for "how much RAM is it using"
		"engine_static_bytes": static_mem_bytes # Explicitly state this is from Performance.MEMORY_STATIC
	}

## Returns a human-readable string of the current memory usage.
## Uses data from get_memory_usage_data() if not provided.
func get_formatted_memory_usage_string(memory_data: Dictionary = {}) -> String:
	if memory_data.is_empty():
		memory_data = get_memory_usage_data()

	var static_str := _format_bytes(memory_data.get("engine_static_bytes", 0))
	var physical_str := _format_bytes(memory_data.get("physical_process_bytes", 0))
	var rss_str := _format_bytes(memory_data.get("process_rss_bytes", 0))
	
	# Focus on the most relevant metrics for game performance
	return "Mem - Static: %s | ProcessPhys: %s | RSS: %s" % [static_str, physical_str, rss_str]

## Helper function to format byte counts into KB or MB.
static func _format_bytes(bytes: int) -> String:
	if bytes < 0: bytes = 0 # Ensure non-negative
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.2f KB" % (float(bytes) / 1024.0)
	else:
		return "%.2f MB" % (float(bytes) / (1024.0 * 1024.0))

# --- Potentially other performance metrics could be added here ---

# func get_fps() -> int:
# 	return Performance.get_monitor(Performance.TIME_FPS)

# func get_draw_calls() -> int:
# 	return Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

# func get_objects_in_frame() -> int:
# 	return Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

# func get_all_performance_metrics_string() -> String:
# 	var mem_str = get_formatted_memory_usage_string()
# 	var fps_str = "FPS: %d" % get_fps()
# 	var draw_calls_str = "Draw Calls: %d" % get_draw_calls()
# 	var objects_str = "Objects: %d" % get_objects_in_frame()
# 	return "%s\n%s | %s | %s" % [mem_str, fps_str, draw_calls_str, objects_str]

## Call this function to get a snapshot of all relevant performance data.
func get_performance_snapshot_string() -> String:
	var mem_string = get_formatted_memory_usage_string()
	# Add more metrics as needed
	return mem_string

## Call this function to get a dictionary of all relevant performance data.
func get_performance_snapshot_data() -> Dictionary:
	var data = {}
	data["memory"] = get_memory_usage_data()
	# data["fps"] = get_fps()
	# data["draw_calls"] = get_draw_calls()
	# data["objects_in_frame"] = get_objects_in_frame()
	return data

func _enter_tree() -> void:
	# Initialize the timer correctly upon entering the tree
	_time_since_last_update = update_interval # Trigger an update on the first possible _process call
	print("PerformanceMonitor active. Emitting memory usage updates every %.2f seconds." % update_interval)

func _exit_tree() -> void:
	print("PerformanceMonitor deactivated.")