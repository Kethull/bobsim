extends Node2D

func _ready():
	# Initialize performance systems
	var pool_manager = null
	
	# Check if available as singleton
	if Engine.has_singleton("ObjectPoolManager"):
		print("Found ObjectPoolManager as Engine singleton")
		pool_manager = Engine.get_singleton("ObjectPoolManager")
	# Check if available as autoload
	elif has_node("/root/ObjectPoolManager"):
		print("Found ObjectPoolManager as autoload at /root")
		pool_manager = get_node("/root/ObjectPoolManager")
	# Try to find by class name
	else:
		var potential_managers = get_tree().get_nodes_in_group("object_pool_managers")
		if potential_managers.size() > 0:
			print("Found ObjectPoolManager in object_pool_managers group")
			pool_manager = potential_managers[0]
	
	# Initialize pools if manager was found
	if pool_manager != null:
		if pool_manager.has_method("initialize_common_pools"):
			pool_manager.initialize_common_pools()
			print("Successfully initialized object pools")
		else:
			push_error("ObjectPoolManager found but missing initialize_common_pools() method")
	else:
		push_error("ObjectPoolManager not found. Performance may be affected. Check project settings and autoloads.")
	
	# Add LOD manager to scene if needed (currently commented out as per original instruction's implication)
	# var lod_manager = LODManager.new() # Assuming LODManager is a class_name or has a .new()
	# add_child(lod_manager)
	# print("LODManager added to Main scene.")
