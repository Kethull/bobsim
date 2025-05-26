extends Node2D

func _ready():
    # Initialize performance systems
    if ObjectPoolManager:
        ObjectPoolManager.initialize_common_pools()
    else:
        print("Warning: ObjectPoolManager (AutoLoad) not found. Cannot initialize common pools.")
    
    # Add LOD manager to scene if needed (currently commented out as per original instruction's implication)
    # var lod_manager = LODManager.new() # Assuming LODManager is a class_name or has a .new()
    # add_child(lod_manager)
    # print("LODManager added to Main scene.")