# AdvancedParticleManager.gd
extends Node2D
class_name AdvancedParticleManager

var particle_pools: Dictionary = {}
var active_effects: Array[ParticleEffect] = []

func _ready():
    # Pre-create particle pools for performance
    create_particle_pools()

func create_particle_pools():
    var pool_configs = {
        "thruster_exhaust": {"count": 50, "scene": preload("res://effects/ThrusterExhaust.tscn")},
        "mining_sparks": {"count": 20, "scene": preload("res://effects/MiningSparks.tscn")},
        "communication_pulse": {"count": 10, "scene": preload("res://effects/CommunicationPulse.tscn")},
        "energy_field": {"count": 15, "scene": preload("res://effects/EnergyField.tscn")},
        "explosion": {"count": 5, "scene": preload("res://effects/Explosion.tscn")}
    }
    
    for effect_type in pool_configs:
        var config = pool_configs[effect_type]
        particle_pools[effect_type] = []
        
        for i in range(config.count):
            var effect = config.scene.instantiate()
            effect.visible = false
            add_child(effect)
            particle_pools[effect_type].append(effect)

func get_effect(effect_type: String) -> ParticleEffect:
    if not particle_pools.has(effect_type):
        push_error("Unknown particle effect type: " + effect_type)
        return null
    
    var pool = particle_pools[effect_type]
    for effect in pool:
        if not effect.is_active():
            return effect
    
    # Pool exhausted, create new effect
    push_warning("Particle pool exhausted for type: " + effect_type)
    return null

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

func _process(_delta):
    # Clean up finished effects
    for i in range(active_effects.size() - 1, -1, -1):
        var effect = active_effects[i]
        if not effect.is_active():
            active_effects.remove_at(i)