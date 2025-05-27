extends Node2D
class_name ParticleEffect

signal effect_finished

# Call this when the particle effect should start
# func play():
#  if has_node("GPUParticles2D"):
#      get_node("GPUParticles2D").emitting = true
#      # Connect to finished signal if the particle node has one
#      if get_node("GPUParticles2D").has_signal("finished"):
#          get_node("GPUParticles2D").finished.connect(_on_particles_finished)
#  elif has_node("CPUParticles2D"):
#      get_node("CPUParticles2D").emitting = true
#      # Connect to finished signal
#      if get_node("CPUParticles2D").has_signal("finished"):
#          get_node("CPUParticles2D").finished.connect(_on_particles_finished)


# func _on_particles_finished():
#  effect_finished.emit()
#  # Optional: queue_free() or return to an object pool
#  # queue_free()