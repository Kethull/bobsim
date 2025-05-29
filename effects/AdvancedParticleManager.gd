# AdvancedParticleManager.gd
extends Node2D
class_name AdvancedParticleManager

# Effect pools and tracking
var particle_pools: Dictionary = {}
var active_effects: Array[ParticleEffect] = []
var base_effect_path: String = "res://effects/ParticleEffect.tscn"
var effect_paths: Dictionary = {
	"thruster_exhaust": "res://effects/ThrusterExhaust.tscn",
	"mining_sparks": "res://effects/MiningEffect.tscn",
	"communication_pulse": "res://effects/CommunicationBeam.tscn",
	"energy_field": "res://effects/EnergyField.tscn",
	"explosion": "res://effects/ExplosionEffect.tscn"
}

# Pool configuration
var pool_sizes: Dictionary = {
	"thruster_exhaust": 50,
	"mining_sparks": 20,
	"communication_pulse": 10,
	"energy_field": 15,
	"explosion": 5
}

func _ready():
	# Pre-create particle pools for performance
	create_particle_pools()

func create_particle_pools():
	# Ensure base effect exists and can be loaded
	var base_effect_scene = _load_scene_with_fallback(base_effect_path)
	if not base_effect_scene:
		push_error("Critical error: Base ParticleEffect.tscn not found or failed to load. Particle system will not function.")
		return
	
	# Create pools for each effect type
	for effect_type in pool_sizes:
		var count = pool_sizes[effect_type]
		particle_pools[effect_type] = []
		
		# Determine which scene to use
		var effect_path = effect_paths.get(effect_type, base_effect_path)
		var scene_to_use = _load_scene_with_fallback(effect_path, base_effect_scene)
		
		# Create the pool
		for i in range(count):
			var effect = scene_to_use.instantiate()
			if effect:
				effect.visible = false
				add_child(effect)
				particle_pools[effect_type].append(effect)
				
				# Connect to effect finished signal if available
				if effect.has_signal("effect_finished"):
					if not effect.is_connected("effect_finished", _on_effect_finished):
						effect.effect_finished.connect(_on_effect_finished.bind(effect))

func _load_scene_with_fallback(path: String, fallback = null) -> Resource:
	# Check if file exists
	if not FileAccess.file_exists(path):
		push_warning("Scene file not found: " + path)
		return fallback
	
	# Try to load the scene
	var scene = null
	
	# Use error handling to catch load failures
	var error = ResourceLoader.load_threaded_request(path)
	if error == OK:
		scene = ResourceLoader.load_threaded_get(path)
		if scene:
			return scene
	
	# Direct load as fallback
	scene = load(path)
	if scene:
		return scene
		
	push_warning("Failed to load scene: " + path)
	return fallback

func get_effect(effect_type: String) -> ParticleEffect:
	# Check if effect type exists
	if not particle_pools.has(effect_type):
		push_error("Unknown particle effect type: " + effect_type)
		
		# Try to use a generic effect as fallback
		if particle_pools.has("thruster_exhaust"):
			push_warning("Falling back to thruster_exhaust effect type")
			return get_effect("thruster_exhaust")
		return null
	
	var pool = particle_pools[effect_type]
	
	# First, try to find an inactive effect in the pool
	for effect in pool:
		if is_instance_valid(effect) and not effect.is_active():
			return effect
	
	# Pool exhausted, try to create a new effect
	push_warning("Particle pool exhausted for type: " + effect_type + ". Creating additional instance.")
	
	# Try to create a new instance
	var new_effect = _create_additional_effect(effect_type)
	if new_effect:
		return new_effect
	
	# If we can't create a new effect, try to find any inactive effect from any pool
	push_warning("Failed to create additional effect. Looking for any available effect.")
	for pool_type in particle_pools:
		for effect in particle_pools[pool_type]:
			if is_instance_valid(effect) and not effect.is_active():
				push_warning("Using " + pool_type + " effect as fallback for " + effect_type)
				return effect
	
	# Absolutely nothing available
	push_error("No particle effects available in any pool")
	return null

func _create_additional_effect(effect_type: String) -> ParticleEffect:
	# Get template from pool or use base effect
	var template = null
	var pool = particle_pools[effect_type]
	
	if pool.size() > 0 and is_instance_valid(pool[0]):
		template = pool[0]
	
	# Determine scene path
	var scene_path = effect_paths.get(effect_type, base_effect_path)
	if template and template.scene_file_path and FileAccess.file_exists(template.scene_file_path):
		scene_path = template.scene_file_path
	
	# Load scene
	var scene = _load_scene_with_fallback(scene_path)
	if not scene:
		return null
	
	# Create instance
	var effect = scene.instantiate()
	if not effect:
		return null
		
	effect.visible = false
	add_child(effect)
	
	# Connect signal
	if effect.has_signal("effect_finished"):
		if not effect.is_connected("effect_finished", _on_effect_finished):
			effect.effect_finished.connect(_on_effect_finished.bind(effect))
	
	# Add to pool
	particle_pools[effect_type].append(effect)
	return effect

func _on_effect_finished(effect: ParticleEffect):
	# Remove from active effects when finished
	if effect in active_effects:
		active_effects.erase(effect)

func create_thruster_effect(position: Vector2, direction: Vector2, intensity: float):
	var effect = get_effect("thruster_exhaust")
	if effect:
		effect.setup_thruster_effect(position, direction, intensity)
		active_effects.append(effect)

func create_mining_effect(start_pos: Vector2, target_pos: Vector2, intensity: float):
	var effect = get_effect("mining_sparks")
	if effect:
		effect.setup_mining_effect(start_pos, target_pos, intensity)
		active_effects.append(effect)

func create_communication_effect(start_pos: Vector2, end_pos: Vector2):
	var effect = get_effect("communication_pulse")
	if effect:
		effect.setup_communication_effect(start_pos, end_pos)
		active_effects.append(effect)

func create_explosion_effect(position: Vector2, size: float = 1.0):
	var effect = get_effect("explosion")
	if effect:
		# Assuming setup_explosion_effect exists or falls back to a generic setup
		if effect.has_method("setup_explosion_effect"):
			effect.setup_explosion_effect(position, size)
		else:
			effect.global_position = position
			effect.scale = Vector2.ONE * size
			effect.play()
		active_effects.append(effect)

func create_energy_field_effect(position: Vector2, radius: float, duration: float = 3.0):
	var effect = get_effect("energy_field")
	if effect:
		# Assuming setup_energy_field_effect exists or falls back to a generic setup
		if effect.has_method("setup_energy_field_effect"):
			effect.setup_energy_field_effect(position, radius, duration)
		else:
			effect.global_position = position
			effect.scale = Vector2.ONE * (radius / 50.0) # Assuming 50 is base size
			effect.duration = duration
			effect.play()
		active_effects.append(effect)

func _process(_delta):
	# Clean up finished effects
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		if not is_instance_valid(effect) or not effect.is_active():
			active_effects.remove_at(i)