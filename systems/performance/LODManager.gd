class_name LODManager
# LODManager.gd
extends Node

var lod_objects: Array[LODObject] = []
var camera_position: Vector2 = Vector2.ZERO
var update_frequency: float = 0.5  # Update LOD twice per second
var update_timer: float = 0.0

class LODObject:
    var node: Node2D
    var lod_distances: Array[float]
    var current_lod: int = 0
    var lod_nodes: Array[Node] = []
    
    func _init(target_node: Node2D, distances: Array[float]):
        node = target_node
        lod_distances = distances
        setup_lod_nodes()
    
    func setup_lod_nodes():
        # Assuming LOD nodes are children named LOD0, LOD1, etc.
        for i in range(4):  # Support up to 4 LOD levels
            var lod_node = node.get_node_or_null("LOD" + str(i))
            if lod_node:
                lod_nodes.append(lod_node)
            else:
                break
    
    func update_lod(distance: float):
        var new_lod = calculate_lod_level(distance)
        if new_lod != current_lod:
            set_lod_level(new_lod)
    
    func calculate_lod_level(distance: float) -> int:
        for i in range(lod_distances.size()):
            if distance <= lod_distances[i]:
                return i
        return lod_distances.size()  # Furthest LOD
    
    func set_lod_level(lod_level: int):
        current_lod = lod_level
        
        # Hide all LOD nodes
        for lod_node in lod_nodes:
            lod_node.visible = false
        
        # Show appropriate LOD node
        if lod_level < lod_nodes.size():
            lod_nodes[lod_level].visible = true

func _ready():
    # Register all objects that need LOD management
    register_lod_objects()

func _process(delta):
    update_timer += delta
    if update_timer >= update_frequency:
        update_timer = 0.0
        update_all_lods()

func register_lod_objects():
    # Register celestial bodies
    for body in get_tree().get_nodes_in_group("celestial_bodies"):
        var distances = [1000.0, 5000.0, 20000.0]  # LOD distances
        add_lod_object(body, distances)
    
    # Register probes (if they have LOD nodes)
    for probe in get_tree().get_nodes_in_group("probes"):
        if probe.has_node("LOD0"):
            var distances = [500.0, 2000.0, 10000.0]
            add_lod_object(probe, distances)

func add_lod_object(node: Node2D, lod_distances: Array[float]):
    var lod_obj = LODObject.new(node, lod_distances)
    lod_objects.append(lod_obj)

func remove_lod_object(node: Node2D):
    for i in range(lod_objects.size() - 1, -1, -1):
        if lod_objects[i].node == node:
            lod_objects.remove_at(i)
            break

func update_camera_position(new_position: Vector2):
    camera_position = new_position

func update_all_lods():
    for lod_obj in lod_objects:
        if lod_obj.node and is_instance_valid(lod_obj.node):
            var distance = camera_position.distance_to(lod_obj.node.global_position)
            lod_obj.update_lod(distance)
        else:
            # Remove invalid objects
            lod_objects.erase(lod_obj)

func get_lod_stats() -> Dictionary:
    var stats = {"lod_0": 0, "lod_1": 0, "lod_2": 0, "lod_3": 0, "culled": 0}
    
    for lod_obj in lod_objects:
        var lod_key = "lod_" + str(lod_obj.current_lod)
        if stats.has(lod_key):
            stats[lod_key] += 1
        else:
            stats["culled"] += 1
    
    return stats