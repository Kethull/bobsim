extends Node2D
class_name ParticleEffect

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

func _ready():
	if not gpu_particles_2d:
		push_error("ParticleEffect requires a GPUParticles2D child node named 'GPUParticles2D'")

func is_active() -> bool:
	if gpu_particles_2d:
		return gpu_particles_2d.emitting
	return false

func activate_effect():
	if gpu_particles_2d:
		gpu_particles_2d.emitting = true
		# Potentially reset other properties or start timers here
	visible = true

func deactivate_effect():
	if gpu_particles_2d:
		gpu_particles_2d.emitting = false
	visible = false
	# Call this when the effect is done and can be returned to a pool

# Placeholder for specific effect setups
func setup_thruster_effect(position: Vector2, direction: Vector2, intensity: float):
	global_position = position
	# Customize GPUParticles2D for thruster: direction, emission_shape, colors, etc.
	# Example:
	# gpu_particles_2d.process_material.set("direction", direction.normalized())
	# gpu_particles_2d.process_material.set("initial_velocity_min", intensity * 0.5)
	# gpu_particles_2d.process_material.set("initial_velocity_max", intensity)
	activate_effect()
	# Potentially use a timer to deactivate after a duration
	# get_tree().create_timer(gpu_particles_2d.lifetime).timeout.connect(deactivate_effect)


func setup_mining_effect(start_pos: Vector2, target_pos: Vector2, intensity: float):
	global_position = start_pos
	# Customize for mining: maybe beam-like or sparks
	activate_effect()

func setup_communication_effect(start_pos: Vector2, end_pos: Vector2):
	global_position = start_pos
	# Customize for communication pulse
	activate_effect()

func _process(delta):
	# If the effect is active and has a finite lifetime,
	# check if it should be deactivated.
	if is_active() and gpu_particles_2d and not gpu_particles_2d.one_shot:
		# This logic might need to be more sophisticated depending on how
		# one_shot and lifetime interact with your desired pooling behavior.
		# If one_shot is false, emitting might stay true.
		# You might need a separate timer or check if active_particles == 0
		pass
	elif is_active() and gpu_particles_2d and gpu_particles_2d.one_shot:
		# For one-shot particles, they stop emitting automatically.
		# We might want to wait until all particles are gone before deactivating.
		if gpu_particles_2d.get_meta("particle_count_tracker", 0) == 0 and not gpu_particles_2d.emitting:
			# This is a conceptual way to track; GPUParticles2D doesn't directly expose active particle count.
			# A common pattern is to use a timer based on lifetime.
			# For now, let's assume if it's one_shot and not emitting, it's done.
			# A more robust solution would be a timer.
			# deactivate_effect() # Be careful with immediate deactivation if pooling
			pass

# Call this when the object is requested from an object pool
func on_requested_from_pool():
	visible = true
	# Reset any state if necessary

# Call this when the object is returned to an object pool
func reset_for_pool():
	visible = false
	if gpu_particles_2d:
		gpu_particles_2d.emitting = false
		gpu_particles_2d.restart() # Clears existing particles
	# Reset any other custom properties to their default state
	global_position = Vector2.ZERO
	rotation = 0.0