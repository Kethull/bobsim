# ObjectPoolManager.gd (AutoLoad)
extends Node

var pools: Dictionary = {}
var active_objects: Dictionary = {}

class ObjectPool:
    var pool_name: String
    var scene_path: String
    var pool_size: int
    var available_objects: Array = []
    var in_use_objects: Array = []
    
    func _init(name: String, path: String, size: int):
        pool_name = name
        scene_path = path
        pool_size = size
        create_pool()
    
    func create_pool():
        var scene = load(scene_path)
        for i in range(pool_size):
            var obj = scene.instantiate()
            obj.set_meta("pooled", true)
            obj.set_meta("pool_name", pool_name)
            available_objects.append(obj)

func create_pool(pool_name: String, scene_path: String, pool_size: int):
    if pools.has(pool_name):
        push_warning("Pool already exists: " + pool_name)
        return
    
    pools[pool_name] = ObjectPool.new(pool_name, scene_path, pool_size)
    active_objects[pool_name] = []

func get_object(pool_name: String) -> Node:
    if not pools.has(pool_name):
        push_error("Pool does not exist: " + pool_name)
        return null
    
    var pool = pools[pool_name]
    
    if pool.available_objects.is_empty():
        # Pool exhausted, expand it
        expand_pool(pool_name, pool.pool_size * 2)
    
    var obj = pool.available_objects.pop_back()
    pool.in_use_objects.append(obj)
    active_objects[pool_name].append(obj)
    
    # Reset object state
    if obj.has_method("reset_for_pool"):
        obj.reset_for_pool()
    
    return obj

func return_object(obj: Node):
    if not obj.has_meta("pooled") or not obj.has_meta("pool_name"):
        push_error("Object is not from a pool")
        return
    
    var pool_name = obj.get_meta("pool_name")
    if not pools.has(pool_name):
        push_error("Pool does not exist: " + pool_name)
        return
    
    var pool = pools[pool_name]
    
    if obj in pool.in_use_objects:
        pool.in_use_objects.erase(obj)
        pool.available_objects.append(obj)
        active_objects[pool_name].erase(obj)
        
        # Hide and disable object
        obj.visible = false
        if obj.has_method("set_physics_process"):
            obj.set_physics_process(false)
        if obj.has_method("set_process"):
            obj.set_process(false)

func expand_pool(pool_name: String, new_size: int):
    if not pools.has(pool_name):
        return
    
    var pool = pools[pool_name]
    var scene = load(pool.scene_path)
    
    for i in range(pool.pool_size, new_size):
        var obj = scene.instantiate()
        obj.set_meta("pooled", true)
        obj.set_meta("pool_name", pool_name)
        pool.available_objects.append(obj)
    
    pool.pool_size = new_size
    print("Expanded pool '", pool_name, "' to size: ", new_size)

func get_pool_stats(pool_name: String) -> Dictionary:
    if not pools.has(pool_name):
        return {}
    
    var pool = pools[pool_name]
    return {
        "total_size": pool.pool_size,
        "available": pool.available_objects.size(),
        "in_use": pool.in_use_objects.size()
    }

func initialize_common_pools():
    # Create pools for commonly used objects
    create_pool("particle_effects", "res://effects/ParticleEffect.tscn", 50)
    create_pool("ui_elements", "res://ui/UIElement.tscn", 20)
    create_pool("audio_sources", "res://audio/AudioSource.tscn", 30)
    create_pool("visual_effects", "res://effects/VisualEffect.tscn", 25)

func _ready():
    initialize_common_pools()