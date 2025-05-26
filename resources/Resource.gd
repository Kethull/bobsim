# Resource.gd
extends Area2D
class_name CollectibleResource
@export_group("Resource Properties")
@export var resource_type: String = "mineral"
@export var max_amount: float = 20000.0
@export var current_amount: float = 20000.0
@export var regeneration_rate: float = 0.0
@export var harvest_difficulty: float = 1.0

@onready var resource_sprite: Sprite2D = $ResourceSprite
@onready var glow_effect: Sprite2D = $GlowEffect
@onready var amount_label: Label = $AmountLabel
@onready var particle_effect: GPUParticles2D = $ParticleEffect
@onready var audio_component: AudioStreamPlayer2D = $AudioComponent
@onready var collection_area: CollisionShape2D = $CollectionShape

var discovered_by: Array[int] = []  # Probe IDs that discovered this resource
var being_harvested_by: Array[Probe] = []
var glow_tween: Tween

signal resource_depleted(resource: CollectibleResource)
signal resource_discovered(resource: CollectibleResource, discovering_probe: Probe)
signal resource_harvested(resource: CollectibleResource, harvesting_probe: Probe, amount: float)

func _ready():
	# Configure collision detection
	set_collision_layer_value(3, true)  # Resources layer
	set_collision_mask_value(2, true)   # Detect probes
	
	# Add to groups
	add_to_group("resources")
	
	# Setup visual appearance
	setup_visual_appearance()
	
	# Setup particle effects
	setup_particle_effects()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Start glow animation
	start_glow_animation()

func setup_visual_appearance():
	# Set resource color based on type and amount
	var color_map = {
		"mineral": Color.GREEN,
		"energy": Color.CYAN,
		"rare_earth": Color.YELLOW,
		"water": Color.BLUE
	}
	
	var base_color = color_map.get(resource_type, Color.WHITE)
	resource_sprite.modulate = base_color
	
	# Scale sprite based on amount
	var amount_ratio = current_amount / max_amount
	var scale_factor = 0.5 + (amount_ratio * 1.5)  # Scale from 0.5 to 2.0
	resource_sprite.scale = Vector2.ONE * scale_factor
	
	# Setup glow effect
	glow_effect.modulate = base_color * 0.7
	glow_effect.modulate.a = 0.6
	glow_effect.scale = resource_sprite.scale * 1.8

func setup_particle_effects():
	# Configure ambient resource particles
	var material = ParticleProcessMaterial.new()
	
	material.emission.amount = int(20 * (current_amount / max_amount))
	material.emission.rate = 10.0
	
	# Circular emission around resource
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 30.0
	
	# Gentle floating motion
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -2, 0)
	material.scale_min = 0.2
	material.scale_max = 0.8
	
	# Resource-appropriate color
	var color_map = {
		"mineral": Color.GREEN,
		"energy": Color.CYAN,
		"rare_earth": Color.YELLOW,
		"water": Color.BLUE
	}
	material.color = color_map.get(resource_type, Color.WHITE)
	
	# Lifetime and fading
	material.lifetime = 4.0
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.8, material.color)
	gradient.add_point(1.0, Color.TRANSPARENT)
	
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	material.color_ramp = texture
	
	particle_effect.process_material = material

func start_glow_animation():
	glow_tween = create_tween()
	glow_tween.set_loops()
	
	var intensity_variation = 0.3 + (current_amount / max_amount) * 0.4
	glow_tween.tween_method(update_glow_intensity, 0.4, 1.0, 2.0)
	glow_tween.tween_method(update_glow_intensity, 1.0, 0.4, 2.0)

func update_glow_intensity(intensity: float):
	if glow_effect:
		glow_effect.modulate.a = intensity * 0.6

func _physics_process(delta):
	# Regenerate resource if applicable
	if regeneration_rate > 0 and current_amount < max_amount:
		current_amount = min(max_amount, current_amount + regeneration_rate * delta)
		update_visual_state()
	
	# Update amount label
	if amount_label.visible:
		amount_label.text = str(int(current_amount))
	
	# Process harvesting
	process_harvesting(delta)

func process_harvesting(delta):
	for probe in being_harvested_by:
		if not probe or not probe.is_alive:
			continue
		
		var distance = global_position.distance_to(probe.global_position)
		if distance <= ConfigManager.config.harvest_distance:
			var harvest_amount = ConfigManager.config.harvest_rate * delta * harvest_difficulty
			var actual_harvested = harvest(harvest_amount)
			
			if actual_harvested > 0:
				# Give energy to the harvesting probe
				probe.current_energy = min(probe.max_energy, probe.current_energy + actual_harvested * 0.1)
				resource_harvested.emit(self, probe, actual_harvested)
				
				# Visual and audio feedback
				create_harvest_effect(probe)

func harvest(amount: float) -> float:
	if current_amount <= 0:
		return 0.0
	
	var harvested = min(amount, current_amount)
	current_amount -= harvested
	
	update_visual_state()
	
	if current_amount <= 0:
		resource_depleted.emit(self)
		# Don't destroy immediately - allow for potential regeneration
	
	return harvested

func update_visual_state():
	# Update visual appearance based on current amount
	var amount_ratio = current_amount / max_amount
	
	# Update sprite scale
	var scale_factor = 0.3 + (amount_ratio * 1.2)
	resource_sprite.scale = Vector2.ONE * scale_factor
	glow_effect.scale = resource_sprite.scale * 1.8
	
	# Update particle count
	var material = particle_effect.process_material as ParticleProcessMaterial
	if material:
		material.emission.amount = max(5, int(20 * amount_ratio))
	
	# Update glow intensity
	var base_color = resource_sprite.modulate
	glow_effect.modulate = base_color * (0.4 + amount_ratio * 0.6)
	
	# Hide if completely depleted
	if current_amount <= 0:
		visible = false
		set_collision_mask_value(2, false)
	else:
		visible = true
		set_collision_mask_value(2, true)

func create_harvest_effect(harvesting_probe: Probe):
	# Create visual effect for harvesting
	var effect = preload("res://effects/HarvestEffect.tscn").instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	effect.setup_effect(global_position, harvesting_probe.global_position)
	
	# Play harvest sound
	if not audio_component.playing:
		audio_component.play()

func discover(discovering_probe: Probe):
	if discovering_probe.probe_id not in discovered_by:
		discovered_by.append(discovering_probe.probe_id)
		resource_discovered.emit(self, discovering_probe)
		
		# Visual discovery effect
		var discovery_effect = preload("res://effects/DiscoveryEffect.tscn").instantiate()
		get_tree().current_scene.add_child(discovery_effect)
		discovery_effect.global_position = global_position

func _on_body_entered(body):
	if body is Probe:
		var probe: Probe = body as Probe
		if probe.is_alive:
			# Check if within harvest distance
			var distance = global_position.distance_to(probe.global_position)
			if distance <= ConfigManager.config.harvest_distance:
				if probe not in being_harvested_by:
					being_harvested_by.append(probe)
					probe.start_mining(self)
			
			# Check for discovery
			if distance <= ConfigManager.config.discovery_range:
				discover(probe)

func _on_body_exited(body):
	if body is Probe:
		var probe: Probe = body as Probe
		if probe in being_harvested_by:
			being_harvested_by.erase(probe)
			probe.stop_mining()
