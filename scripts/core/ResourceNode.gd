extends Area2D
class_name ResourceNode

signal resource_depleted
signal being_mined(miner_probe: Node) # Changed from Probe to Node for more flexibility, can cast later

@export var amount: float = Config.SimResource.MAX_AMOUNT
@export var max_amount: float = Config.SimResource.MAX_AMOUNT
@export var resource_type: String = "generic"
# Add a unique ID for targeting if necessary, e.g. by SolarSystem
var resource_id: int = -1 

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_particles: GPUParticles2D = $GlowParticles # Ensure this node exists in Resource.tscn
# @onready var collision_shape: CollisionShape2D = $CollisionShape2D # For adjusting radius if needed

var miners: Array[Node] = [] # Store references to probes mining this node
var regeneration_timer: float = 0.0

func _ready():
    setup_visual()
    # Area2D signals are typically connected in the editor, but can be done here if preferred.
    # body_entered.connect(_on_body_entered)
    # body_exited.connect(_on_body_exited)
    add_to_group("resources") # Add to group for easy lookup by probes

func setup_visual():
    update_visual_properties() # Renamed from update_visual
    
    if glow_particles and is_instance_valid(glow_particles):
        setup_glow_effect()

func setup_glow_effect():
    if not (glow_particles and is_instance_valid(glow_particles)):
        return

    var material = ParticleProcessMaterial.new()
    # Basic glow particle properties
    material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    material.emission_sphere_radius = Config.SimResource.BASE_DISPLAY_RADIUS * 0.5 # Emit from near the center
    material.direction = Vector3(0, 0, 0) # No specific direction, expand outwards
    material.spread = 180.0 # Degrees
    
    material.initial_velocity_min = 5.0
    material.initial_velocity_max = 15.0
    material.gravity = Vector3(0, 0, 0) # No gravity for this glow
    
    material.scale_min = 0.5
    material.scale_max = 1.2
    material.color = Color(0.2, 0.9, 0.3, 0.7) # Greenish glow

    # Lifetime
    material.lifetime = randf_range(0.5, 1.5)
    
    glow_particles.process_material = material
    # Texture for particles (a simple white dot or soft circle is good)
    glow_particles.draw_pass_1 = create_glow_particle_mesh() # Use a simple mesh for particles
    update_glow_intensity()


func create_glow_particle_mesh() -> Mesh:
    # Using a QuadMesh for particles. A custom texture can be set on this mesh's material.
    var quad = QuadMesh.new()
    quad.size = Vector2(2,2) # Small base size, will be scaled by particle process material
    var mat = StandardMaterial3D.new() # Or CanvasItemMaterial if rendering in 2D without 3D properties
    mat.albedo_color = Color(1,1,1,1) # White, so particle color tints it
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    quad.material = mat
    return quad

func create_glow_texture() -> ImageTexture: # Fallback if not using mesh or for sprite
    var size = 16
    var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center = Vector2(size / 2.0, size / 2.0)
    for x in range(size):
        for y in range(size):
            var dist = Vector2(x, y).distance_to(center)
            var alpha = 1.0 - (dist / (size / 2.0))
            alpha = pow(max(0.0, alpha), 2) # Sharper falloff for glow
            image.set_pixel(x, y, Color(0.5, 1.0, 0.5, alpha * 0.6)) # Greenish, adjust as needed
    
    var texture = ImageTexture.create_from_image(image)
    return texture

func update_visual_properties(): # Renamed from update_visual
    if not sprite or not is_instance_valid(sprite):
        return
        
    var size_ratio = 0.0
    if max_amount > 0:
        size_ratio = clamp(amount / max_amount, 0.0, 1.0)
    else: # Avoid division by zero if max_amount is 0
        size_ratio = 0.0 if amount <=0 else 1.0

    var radius = Config.SimResource.BASE_DISPLAY_RADIUS * (0.5 + size_ratio * 0.5) # Min size 0.5*base, max base
    var resource_color = Color.GREEN.lerp(Color.DARK_GREEN, 1.0 - size_ratio)
    
    sprite.texture = create_resource_texture(radius, resource_color)
    # Collision shape should also be updated if it's dynamic
    # if collision_shape and is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
    #    (collision_shape.shape as CircleShape2D).radius = radius

    update_glow_intensity()

func update_glow_intensity():
    if glow_particles and is_instance_valid(glow_particles):
        var size_ratio = 0.0
        if max_amount > 0:
            size_ratio = clamp(amount / max_amount, 0.0, 1.0)
        glow_particles.emitting = amount > 0
        glow_particles.amount = int(size_ratio * 30) + 5 # Number of particles

func create_resource_texture(radius: float, color: Color) -> ImageTexture:
    var diameter = int(max(4.0, radius * 2.0)) # Ensure diameter is at least 4
    var image = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
    var center = Vector2(float(diameter) / 2.0, float(diameter) / 2.0)

    for y in range(diameter):
        for x in range(diameter):
            var current_pos = Vector2(float(x) + 0.5, float(y) + 0.5)
            var dist = current_pos.distance_to(center)
            if dist <= radius:
                var intensity = 1.0 - (dist / radius) * 0.7
                intensity = clamp(intensity, 0.0, 1.0)
                var pixel_color = Color(color.r * intensity, color.g * intensity, color.b * intensity, 1.0)
                image.set_pixel(x, y, pixel_color)
            else:
                image.set_pixel(x,y,Color(0,0,0,0))
                
    var texture = ImageTexture.create_from_image(image)
    return texture

func _physics_process(delta: float):
    if amount < max_amount:
        regeneration_timer += delta
        if regeneration_timer >= 1.0: # Regenerate based on per-second rate
            regenerate_amount(Config.SimResource.REGEN_RATE_PER_STEP * regeneration_timer)
            regeneration_timer = 0.0 # Reset timer
    
    # Mining is handled by probes calling harvest() or by signals

func regenerate_amount(regen_val: float):
    if amount < max_amount:
        amount = min(max_amount, amount + regen_val)
        update_visual_properties()

func harvest(rate_per_second_by_harvester: float, delta_time: float) -> float:
    if amount <= 0:
        return 0.0

    var harvested_this_frame = min(rate_per_second_by_harvester * delta_time, amount)
    amount = max(0, amount - harvested_this_frame)
    
    update_visual_properties()
    
    if amount <= 0:
        resource_depleted.emit()
        # Optionally, queue_free() or disable after depletion and some timeout
    
    return harvested_this_frame

func add_miner(probe: Node):
    if not probe in miners:
        miners.append(probe)
        being_mined.emit(probe) # Signal that a probe started mining

func remove_miner(probe: Node):
    if probe in miners:
        miners.erase(probe)
        # Optionally, emit a signal that a probe stopped mining

# Connected in editor or _ready
func _on_body_entered(body: Node2D):
    # This is for proximity detection. Actual mining might be more complex.
    # For example, a probe might "lock on" and then call harvest.
    # The guide implies probes manage their mining state.
    if body.is_in_group("probes"): # Assuming probes are in a "probes" group
        # print("Probe %s entered resource %s area" % [body.name, self.name])
        pass # Probes will handle their own logic for starting mining

func _on_body_exited(body: Node2D):
    if body.is_in_group("probes"):
        # print("Probe %s exited resource %s area" % [body.name, self.name])
        pass