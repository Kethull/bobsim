class_name LODManager
# LODManager.gd
extends Node

## Stores all registered LOD-able objects.
var lod_objects: Array[LODObject] = []
## Reference to the active 2D camera.
var _main_camera: Camera2D = null
## How often to update LODs, in seconds.
@export var update_frequency: float = 0.25  # Update LOD four times per second
var _update_timer: float = 0.0

## Default LOD distances if an object doesn't provide its own.
@export var default_lod_distances: Array[float] = [500.0, 1500.0, 5000.0]
## Prefix for child nodes representing LOD levels (e.g., "LOD0", "LOD1").
@export var lod_node_prefix: String = "LOD"
## Maximum number of LOD child nodes to check for (LOD0 to LOD<N-1>).
@export var max_lod_children: int = 4


class LODObject:
	var node: Node2D  # The main node that has LOD behavior.
	var lod_distance_thresholds: Array[float] # Distances at which LOD changes.
	var current_lod_level: int = -1 # Start at an invalid level to force initial update.
	var lod_child_nodes: Array[Node2D] = [] # Cached child nodes (LOD0, LOD1, etc.).
	var has_apply_lod_method: bool = false # Does the main node have 'apply_active_lod_level'?

	func _init(target_node: Node2D, distances: Array[float], prefix: String, max_children: int):
		node = target_node
		lod_distance_thresholds = distances
		lod_distance_thresholds.sort() # Ensure distances are ascending.

		# Discover child LOD nodes (e.g., LOD0, LOD1)
		for i in range(max_children):
			var child_lod_node = node.get_node_or_null(prefix + str(i))
			if child_lod_node is Node2D:
				lod_child_nodes.append(child_lod_node)
				child_lod_node.visible = (i == 0) # Initially show only LOD0 if multiple exist
			elif child_lod_node:
				push_warning("LOD child '", prefix + str(i), "' in '", node.name, "' is not a Node2D. It will not be managed by LODManager visibility.")
			else:
				# Stop if we don't find a sequential LOD node
				break
		
		if lod_child_nodes.is_empty() and not node.has_method("apply_active_lod_level"):
			push_warning("LODObject '", node.name, "' has no child LOD nodes (e.g. '", prefix, "0') and no 'apply_active_lod_level' method. LOD will have no effect.")
		
		has_apply_lod_method = node.has_method("apply_active_lod_level")
		# Initial update to set correct LOD
		# set_active_lod_level(calculate_new_lod_level(INF), true) # Assume very far initially or pass a large distance

	## Calculates the desired LOD level based on distance.
	func calculate_new_lod_level(distance_to_camera: float) -> int:
		for i in range(lod_distance_thresholds.size()):
			if distance_to_camera <= lod_distance_thresholds[i]:
				return i # LOD level corresponds to the index
		return lod_distance_thresholds.size() # Furthest LOD level (or culled)

	## Applies the specified LOD level to the object.
	func set_active_lod_level(new_level: int, force_update: bool = false):
		if new_level == current_lod_level and not force_update:
			return # No change

		current_lod_level = new_level

		# Manage visibility of child LOD nodes
		for i in range(lod_child_nodes.size()):
			if lod_child_nodes[i] and is_instance_valid(lod_child_nodes[i]):
				lod_child_nodes[i].visible = (i == current_lod_level)
		
		# If the main node has a specific method, call it
		if has_apply_lod_method:
			node.apply_active_lod_level(current_lod_level)

	## Called by LODManager to update this object's LOD based on camera distance.
	func update_lod_from_distance(distance_to_camera: float):
		var new_lod = calculate_new_lod_level(distance_to_camera)
		set_active_lod_level(new_lod)


func _ready():
	# Attempt to find the main 2D camera
	await get_tree().process_frame # Wait a frame for camera to be ready
	_main_camera = get_viewport().get_camera_2d()
	if not _main_camera:
		push_warning("LODManager: No active Camera2D found. LOD updates will not occur.")
	
	# Automatically register objects from specified groups
	_register_objects_from_groups()

func _process(delta: float):
	if not _main_camera:
		return # Cannot update LODs without a camera

	_update_timer += delta
	if _update_timer >= update_frequency:
		_update_timer = 0.0 # Reset timer
		_update_all_lods()

func _register_objects_from_groups():
	# Groups can be defined in your project (e.g., "lod_celestial", "lod_probes")
	var lod_groups_to_scan = ["celestial_bodies", "probes"] # Example groups
	for group_name in lod_groups_to_scan:
		for node_in_group in get_tree().get_nodes_in_group(group_name):
			if node_in_group is Node2D:
				# Try to get LOD distances from the node itself
				var custom_distances: Array[float] = []
				if node_in_group.has_meta("lod_distances"): # Check for metadata
					custom_distances = node_in_group.get_meta("lod_distances") as Array[float]
				elif node_in_group.has_method("get_lod_distances"): # Check for a method
					custom_distances = node_in_group.get_lod_distances() as Array[float]
				elif node_in_group.get("lod_distance_thresholds") != null and node_in_group.get("lod_distance_thresholds") is Array[float]: # Check for exported var
					custom_distances = node_in_group.get("lod_distance_thresholds")

				if custom_distances.is_empty():
					add_lod_object(node_in_group, default_lod_distances.duplicate(true))
					# push_warning("Node '", node_in_group.name, "' in group '", group_name, "' uses default LOD distances.")
				else:
					add_lod_object(node_in_group, custom_distances)
			else:
				push_warning("Node '", node_in_group.name, "' in group '", group_name, "' is not a Node2D and will not be registered for LOD.")


## Registers a Node2D for LOD management.
## node: The Node2D to manage.
## lod_distances: An array of float values representing distance thresholds for each LOD level.
##                e.g., [100.0, 500.0, 2000.0] for LOD0 up to 100, LOD1 up to 500, etc.
func add_lod_object(node_to_add: Node2D, distances: Array[float]):
	if not is_instance_valid(node_to_add):
		push_warning("Attempted to add an invalid node to LODManager.")
		return
	
	# Check if already added
	for lod_obj_existing in lod_objects:
		if lod_obj_existing.node == node_to_add:
			push_warning("Node '", node_to_add.name, "' already added to LODManager.")
			return

	if distances.is_empty():
		push_warning("LOD distances for '", node_to_add.name, "' are empty. Using default or skipping if defaults are also empty.")
		if default_lod_distances.is_empty():
			push_error("Cannot add LOD object '", node_to_add.name, "': no LOD distances provided and no defaults set in LODManager.")
			return
		distances = default_lod_distances.duplicate(true)

	var new_lod_obj = LODObject.new(node_to_add, distances, lod_node_prefix, max_lod_children)
	lod_objects.append(new_lod_obj)
	# Initial LOD update for the newly added object
	if _main_camera and is_instance_valid(_main_camera):
		var cam_pos = _main_camera.get_global_transform_with_canvas().origin
		var node_pos = node_to_add.global_position
		new_lod_obj.update_lod_from_distance(cam_pos.distance_to(node_pos))
	else:
		new_lod_obj.set_active_lod_level(0, true) # Default to LOD0 if no camera yet


## Removes a Node2D from LOD management.
func remove_lod_object(node_to_remove: Node2D):
	for i in range(lod_objects.size() - 1, -1, -1): # Iterate backwards for safe removal
		if lod_objects[i].node == node_to_remove:
			lod_objects.remove_at(i)
			# print("Removed '", node_to_remove.name, "' from LODManager.")
			break

## Main update loop called by _process.
func _update_all_lods():
	if not _main_camera or not is_instance_valid(_main_camera):
		# Try to get camera again if it was lost
		_main_camera = get_viewport().get_camera_2d()
		if not _main_camera:
			# push_warning("LODManager: No Camera2D for _update_all_lods.")
			return

	var cam_pos: Vector2 = _main_camera.get_global_transform_with_canvas().origin

	for i in range(lod_objects.size() - 1, -1, -1): # Iterate backwards for safe removal
		var lod_obj_instance = lod_objects[i]
		if lod_obj_instance.node and is_instance_valid(lod_obj_instance.node):
			var node_pos: Vector2 = lod_obj_instance.node.global_position
			lod_obj_instance.update_lod_from_distance(cam_pos.distance_to(node_pos))
		else:
			# Node was freed or became invalid, remove it from tracking
			lod_objects.remove_at(i)
			# print("LODManager: Removed invalid object from tracking.")


## Returns statistics about current LOD distribution.
func get_lod_stats() -> Dictionary:
	var stats = {} # Use a flexible dictionary for stats keys like "lod_0", "lod_1", etc.
	var total_objects = lod_objects.size()
	stats["total_managed_objects"] = total_objects
	
	if total_objects == 0:
		return stats

	for lod_obj_item in lod_objects:
		var lod_key = lod_node_prefix.to_lower() + "_" + str(lod_obj_item.current_lod_level)
		if not stats.has(lod_key):
			stats[lod_key] = 0
		stats[lod_key] += 1
	
	return stats

# Example of how a Node2D might provide LOD distances and handle complexity:
#
# class_name MyLODableObject
# extends Node2D
#
# # Exported for LODManager to pick up, or provide via get_lod_distances() or metadata
# @export var lod_distance_thresholds: Array[float] = [200.0, 800.0, 3000.0]
#
# # Optional: Child nodes for different visual LODs
# # @onready var lod0_visuals: Node2D = $LOD0
# # @onready var lod1_visuals: Node2D = $LOD1
# # ...
#
# @onready var complex_script_component: Node = $PathToComplexScriptNode # Example
# @onready var particle_emitter: CPUParticles2D = $Particles
#
# func apply_active_lod_level(level: int) -> void:
# 	print(name, " applying LOD level: ", level)
# 	match level:
# 		0: # Highest detail
# 			if complex_script_component: complex_script_component.set_process(true)
# 			if particle_emitter: particle_emitter.emitting = true
# 			# Ensure high-res mesh/shader is active if not using child LOD nodes for this
# 		1: # Medium detail
# 			if complex_script_component: complex_script_component.set_process(true) # Maybe still process
# 			if particle_emitter: particle_emitter.amount_ratio = 0.5 # Reduce particles
# 		2: # Low detail
# 			if complex_script_component: complex_script_component.set_process(false) # Disable complex script
# 			if particle_emitter: particle_emitter.emitting = false
# 		_: # Furthest LOD / Culled (level == lod_distance_thresholds.size())
# 			if complex_script_component: complex_script_component.set_process(false)
# 			if particle_emitter: particle_emitter.emitting = false
# 			# Optionally, hide this node entirely if not handled by child LOD node visibility
# 			# self.visible = false (but LODManager handles child LODx visibility)
#
# # Alternative way to provide distances if not using @export or metadata
# # func get_lod_distances() -> Array[float]:
# # 	return [200.0, 800.0, 3000.0]
#