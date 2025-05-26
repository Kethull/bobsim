class_name ObjectPoolManager
extends Node

## Manages pools of reusable objects to improve performance by reducing
## the overhead of frequent instantiation and destruction.

## Stores all object pools, keyed by their scene_path.
var pools: Dictionary = {}
## Stores active objects, keyed by their scene_path. Used for tracking.
var active_objects: Dictionary = {}

## Represents a pool for a specific type of object (scene).
class ObjectPool:
	var scene_path: String
	var initial_size: int
	var current_size: int
	var available_objects: Array[Node] = []
	var in_use_objects: Array[Node] = [] # Primarily for stats/debugging
	var _owner_manager: ObjectPoolManager # Reference to the ObjectPoolManager instance

	func _init(path: String, size: int, manager: ObjectPoolManager):
		scene_path = path
		initial_size = size
		current_size = size
		_owner_manager = manager
		_populate_pool(initial_size)

	func _populate_pool(count: int):
		var resource = load(scene_path)
		if not resource:
			push_error("Failed to load resource for pooling: " + scene_path)
			return
		if not resource is PackedScene:
			var type_name = "Unknown"
			if resource != null:
				type_name = str(typeof(resource))
				var script = resource.get_script()
				if script != null and script is GDScript: type_name += " (Script: " + script.resource_path + ")"
				elif script != null: type_name += " (Script Type: " + str(typeof(script)) + ")"
			push_error("Resource at path '" + scene_path + "' is not a PackedScene for _populate_pool. Actual type: " + type_name)
			return
		
		var scene_to_instantiate: PackedScene = resource as PackedScene

		for i in range(count):
			var obj: Node = scene_to_instantiate.instantiate()
			obj.set_meta("pooled", true)
			obj.set_meta("scene_path", scene_path) # Store scene_path for identification
			
			if _owner_manager:
				_owner_manager.add_child(obj) # Add to the ObjectPoolManager node
			else:
				push_error("ObjectPool has no owner_manager. Cannot add pooled object for scene: " + scene_path)
				obj.queue_free() # Avoid memory leak
				continue

			obj.visible = false
			if obj.has_method("set_process"):
				obj.set_process(false)
			if obj.has_method("set_physics_process"):
				obj.set_physics_process(false)
			available_objects.append(obj)
		current_size = available_objects.size() + in_use_objects.size()


## Creates a new object pool for the given scene path with a specified initial size.
## scene_path: Path to the PackedScene file (e.g., "res://path/to/MyObject.tscn").
## initial_pool_size: The number of objects to pre-instantiate in the pool.
func create_pool(scene_path: String, initial_pool_size: int) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("Cannot create pool. Scene file does not exist: " + scene_path)
		return

	var loaded_resource_for_check = load(scene_path)
	var is_verified_packed_scene = false
	if loaded_resource_for_check is PackedScene:
		is_verified_packed_scene = true
	
	if not is_verified_packed_scene:
		var type_name = "Unknown"
		if loaded_resource_for_check != null:
			type_name = str(typeof(loaded_resource_for_check))
			var script = loaded_resource_for_check.get_script()
			if script != null and script is GDScript: type_name += " (Script: " + script.resource_path + ")"
			elif script != null: type_name += " (Script Type: " + str(typeof(script)) + ")"
		push_error("Cannot create pool. Resource at path '" + scene_path + "' is not a PackedScene. Actual type: " + type_name)
		return

	if pools.has(scene_path):
		push_warning("Pool already exists for scene: " + scene_path)
		return

	if initial_pool_size <= 0:
		push_warning("Initial pool size must be greater than 0 for scene: " + scene_path)
		initial_pool_size = 10 # Default to a small size

	var new_pool = ObjectPool.new(scene_path, initial_pool_size, self) # Pass 'self' as the manager
	pools[scene_path] = new_pool
	active_objects[scene_path] = []
	print("Object pool created for '", scene_path, "' with size: ", initial_pool_size)

## Requests an object from the pool associated with the given scene_path.
## If the pool is empty, it can be dynamically expanded.
## scene_path: Path to the PackedScene file of the desired object.
## Returns a Node instance from the pool, or null if the pool doesn't exist or an error occurs.
func request_object(scene_path: String) -> Node:
	if not pools.has(scene_path):
		push_error("Pool does not exist for scene: " + scene_path + ". Create it first using create_pool().")
		return null

	var pool: ObjectPool = pools[scene_path]

	if pool.available_objects.is_empty():
		var expand_by = max(1, int(pool.initial_size * 0.5))
		push_warning("Pool for '", scene_path, "' exhausted. Expanding by ", expand_by, " objects.")
		expand_pool(scene_path, pool.current_size + expand_by)
		if pool.available_objects.is_empty():
			push_error("Failed to expand pool or no objects available after expansion for: " + scene_path)
			return null

	var obj: Node = pool.available_objects.pop_back()
	pool.in_use_objects.append(obj)
	active_objects[scene_path].append(obj)

	obj.visible = true
	if obj.has_method("set_process"): obj.set_process(true)
	if obj.has_method("set_physics_process"): obj.set_physics_process(true)
	if obj.has_method("on_requested_from_pool"): obj.on_requested_from_pool()

	return obj

## Returns an object instance to its designated pool.
func return_object(object_instance: Node, scene_path: String) -> void:
	if not object_instance:
		push_error("Attempted to return a null object to pool: " + scene_path)
		return

	if not object_instance.has_meta("pooled") or object_instance.get_meta("scene_path") != scene_path:
		push_error("Object is not from the specified pool ('", scene_path, "') or not a pooled object. Object name: " + object_instance.name)
		return

	if not pools.has(scene_path):
		push_error("Pool does not exist to return object to: " + scene_path)
		return

	var pool: ObjectPool = pools[scene_path]

	if object_instance in pool.available_objects:
		push_warning("Object already in available list for pool: " + scene_path + ". Object name: " + object_instance.name)
		return

	if pool.in_use_objects.has(object_instance): pool.in_use_objects.erase(object_instance)
	if active_objects.has(scene_path) and active_objects[scene_path].has(object_instance):
		active_objects[scene_path].erase(object_instance)

	if object_instance.has_method("reset_for_pool"): object_instance.reset_for_pool()
	else: push_warning("Pooled object '", object_instance.name, "' from '", scene_path, "' has no reset_for_pool() method.")

	object_instance.visible = false
	if object_instance.has_method("set_process"): object_instance.set_process(false)
	if object_instance.has_method("set_physics_process"): object_instance.set_physics_process(false)

	pool.available_objects.append(object_instance)

## Dynamically expands an existing object pool.
func expand_pool(scene_path: String, new_total_size: int) -> void:
	if not pools.has(scene_path):
		push_error("Cannot expand non-existent pool: " + scene_path)
		return

	var pool: ObjectPool = pools[scene_path]
	if new_total_size <= pool.current_size:
		push_warning("New size (", new_total_size, ") is not greater than current size (", pool.current_size, ") for pool: ", scene_path)
		return

	var objects_to_add = new_total_size - pool.current_size
	
	var resource = load(pool.scene_path)
	if not resource:
		push_error("Failed to load resource for expanding pool: " + pool.scene_path)
		return
	if not resource is PackedScene:
		var type_name = "Unknown"
		if resource != null:
			type_name = str(typeof(resource))
			var script = resource.get_script()
			if script != null and script is GDScript: type_name += " (Script: " + script.resource_path + ")"
			elif script != null: type_name += " (Script Type: " + str(typeof(script)) + ")"
		push_error("Resource at path '" + pool.scene_path + "' is not a PackedScene for expand_pool. Actual type: " + type_name)
		return
		
	var scene_to_instantiate: PackedScene = resource as PackedScene

	for i in range(objects_to_add):
		var obj: Node = scene_to_instantiate.instantiate()
		obj.set_meta("pooled", true)
		obj.set_meta("scene_path", pool.scene_path)
		add_child(obj) # 'self' (ObjectPoolManager) is the parent
		obj.visible = false
		if obj.has_method("set_process"): obj.set_process(false)
		if obj.has_method("set_physics_process"): obj.set_physics_process(false)
		pool.available_objects.append(obj)

	pool.current_size = new_total_size
	print("Expanded pool '", scene_path, "' to new total size: ", new_total_size, ". Added ", objects_to_add, " objects.")

## Retrieves statistics for a specific object pool.
func get_pool_stats(scene_path: String) -> Dictionary:
	if not pools.has(scene_path):
		push_warning("No pool stats available for non-existent pool: " + scene_path)
		return {}

	var pool: ObjectPool = pools[scene_path]
	return {
		"scene_path": pool.scene_path,
		"initial_size": pool.initial_size,
		"current_total_size": pool.current_size,
		"available": pool.available_objects.size(),
		"in_use": pool.in_use_objects.size()
	}

## Initializes pools for commonly used objects.
func initialize_common_pools() -> void:
	var probe_scene_path = "res://probes/Probe.tscn"
	var can_pool_probe = false
	if ResourceLoader.exists(probe_scene_path):
		var loaded_probe_res = load(probe_scene_path)
		if loaded_probe_res is PackedScene: can_pool_probe = true
	
	if can_pool_probe: create_pool(probe_scene_path, 20)
	else: push_warning("Probe scene file ('" + probe_scene_path + "') not found or not a PackedScene, cannot pool.")

	var particle_effect_scene_path = "res://effects/ParticleEffect.tscn"
	var can_pool_particle = false
	if ResourceLoader.exists(particle_effect_scene_path):
		var loaded_particle_res = load(particle_effect_scene_path)
		if loaded_particle_res is PackedScene: can_pool_particle = true
			
	if can_pool_particle: create_pool(particle_effect_scene_path, 50)
	else: push_warning("Particle effect scene file ('" + particle_effect_scene_path + "') not found or not a PackedScene, cannot pool.")

## Called when the node is added to the scene tree.
func _ready() -> void:
	if get_tree() and get_parent() == get_tree().root and name == "ObjectPoolManager":
		initialize_common_pools()
	else:
		var msg = "ObjectPoolManager: "
		if not get_tree(): msg += "Not in scene tree during _ready. "
		elif get_parent() != get_tree().root: msg += "Not a direct child of root. "
		if name != "ObjectPoolManager": msg += "Name is '" + name + "' not 'ObjectPoolManager'. "
		msg += "Common pools not initialized. Ensure Autoload setup is correct or call initialize_common_pools() manually."
		push_warning(msg)