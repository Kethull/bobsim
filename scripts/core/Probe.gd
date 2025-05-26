extends CharacterBody2D
class_name Probe

# --- Signals ---
signal energy_depleted(probe_instance: Probe)
signal replication_attempted(probe_instance: Probe, cost: float) # cost might be useful for GameManager
signal mining_started(probe_instance: Probe, target_resource: ResourceNode)
signal mining_stopped(probe_instance: Probe)
signal destroyed(probe_instance: Probe) # General destruction signal

# --- Exported Variables ---
@export var probe_id: int = -1
@export var energy: float = Config.Probe.INITIAL_ENERGY:
    set(value):
        var prev_energy = energy
        energy = clamp(value, 0.0, Config.Probe.MAX_ENERGY)
        if energy <= 0.0 and prev_energy > 0.0 and alive:
            die()
@export var mass_kg: float = Config.Physics.DEFAULT_PROBE_MASS_KG # Renamed from 'mass' for clarity
@export var generation: int = 0
@export var alive: bool = true:
    set(value):
        if alive == value: return
        alive = value
        if not alive:
            # Ensure modulate is reset if it was changed for death effect
            modulate = Color.WHITE 
            # Additional cleanup or visual changes for death can go here
            # For example, stop particles, change appearance via renderer
            if is_instance_valid(ship_renderer_node):
                ship_renderer_node.queue_redraw() # Update visual to reflect dead state
            if is_instance_valid(thruster_particles_node): # Assuming a direct particle node for thrusters
                thruster_particles_node.emitting = false
            if is_instance_valid(trail_renderer_node):
                pass # Trail might persist for a bit or be cleared

# --- Internal State ---
var current_angle_rad: float = 0.0 # Renamed from angle_rad to avoid conflict with Node2D.rotation
var current_angular_velocity: float = 0.0 # Renamed from angular_velocity

var thrust_input_level: int = 0 # Discrete level 0, 1, 2, 3...
var torque_input_level: int = 0 # Discrete level -N to N (0 = no torque, positive = CCW, negative = CW)

var target_resource_node: ResourceNode = null # Renamed from target_resource
var is_mining_active: bool = false # Renamed from is_mining

var trail_points_buffer: Array[Vector2] = []

# --- OnReady Node References ---
# These will be assigned in _ready() using get_node()
@onready var ship_renderer_node: OrganicShipRenderer = $OrganicShipRenderer
# ProbePhysics component is removed as physics is handled directly here or via CharacterBody2D
@onready var ai_component_node: ProbeAI = $ProbeAI
@onready var thruster_particles_node: GPUParticles2D = $ThrusterParticles # Assuming GPUParticles2D for thrusters
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D # Standard for CharacterBody2D
@onready var trail_renderer_node: TrailRenderer = $TrailRenderer

# For Verlet integration or more complex physics if not solely relying on CharacterBody2D's move_and_slide
var previous_step_acceleration: Vector2 = Vector2.ZERO # Renamed from previous_acceleration

# For AI state tracking
var last_observation: Array = []
var last_action_taken: Array = []
var steps_since_last_learn: int = 0


func _ready():
    # Ensure unique name for node if probe_id is set, useful for get_node by name
    if probe_id != -1:
        name = "Probe_" + str(probe_id)
    
    # Initial rotation setup
    rotation = current_angle_rad

    # Setup AI Component
    if is_instance_valid(ai_component_node):
        ai_component_node.set_probe_reference(self)
        # AI model for ai_component_node should be set by GameManager
    else:
        printerr("Probe (%s): AIComponent node not found!" % name)

    # Setup Visuals
    if is_instance_valid(ship_renderer_node):
        ship_renderer_node.set_target_probe(self) # Pass self (this Probe node)
    else:
        printerr("Probe (%s): OrganicShipRenderer node not found!" % name)

    if is_instance_valid(trail_renderer_node):
        trail_renderer_node.trail_color = Color.PALE_TURQUOISE # Example color
        trail_renderer_node.trail_width = 1.5
    else:
        printerr("Probe (%s): TrailRenderer node not found!" % name)
        
    if not is_instance_valid(thruster_particles_node):
        printerr("Probe (%s): ThrusterParticles node not found!" % name)

    # Add to group for easier access by other systems
    add_to_group("probes")
    
    # Initialize last_observation with current state
    last_observation = get_current_observation()


func _physics_process(delta: float):
    if not alive:
        # If dead, maybe some minimal physics like drifting, or just do nothing.
        # velocity = velocity.lerp(Vector2.ZERO, 0.01 * delta) # Slow down if dead
        # move_and_slide()
        return

    # 1. AI Decision Making (if AI is active)
    if is_instance_valid(ai_component_node):
        var current_obs = get_current_observation()
        # The AI component calculates reward based on the *previous* state and action leading to *current_obs*
        # So, reward calculation and experience storage should happen *before* new action prediction for this step.
        
        # If this isn't the first step (last_action_taken is populated)
        if not last_action_taken.is_empty():
            var reward = ai_component_node.calculate_reward(current_obs) # Reward for reaching current_obs from last_observation via last_action_taken
            ai_component_node.record_transition_and_learn(last_observation, last_action_taken, reward, current_obs, not alive)
        
        var new_action = ai_component_node.predict_action_q_learning(current_obs)
        apply_ai_action(new_action) # Updates thrust_input_level, torque_input_level etc.
        
        # Store for next step's reward calculation and experience replay
        last_observation = current_obs.duplicate() # Store a copy
        last_action_taken = new_action.duplicate() # Store a copy
        steps_since_last_learn +=1

    # 2. Apply Physics based on current thrust/torque levels
    var current_acceleration = Vector2.ZERO

    # Apply Thrust
    if thrust_input_level > 0 and energy > 0:
        var thrust_magnitude_sim = Config.Probe.THRUST_FORCE_MAGNITUDES[thrust_input_level] / mass_kg # F = ma => a = F/m
        var thrust_vector_world = Vector2.RIGHT.rotated(rotation) * thrust_magnitude_sim # CharacterBody2D rotation is used
        
        current_acceleration += thrust_vector_world
        
        var energy_cost_thrust = Config.Probe.THRUST_FORCE_MAGNITUDES[thrust_input_level] * Config.Probe.THRUST_ENERGY_COST_FACTOR * delta
        consume_energy(energy_cost_thrust)
        
        if is_instance_valid(thruster_particles_node) and Config.Visualization.ENABLE_PARTICLE_EFFECTS:
            thruster_particles_node.emitting = true
            # Adjust particle emission based on thrust_level if GPUParticles2D allows dynamic changes easily
            # Or use a ParticleSystemManager if more control is needed:
            # get_tree().root.get_node("ParticleSystemManager").emit_thruster_exhaust(global_position, rotation, thrust_input_level)
        
    elif is_instance_valid(thruster_particles_node):
        thruster_particles_node.emitting = false

    # Apply Torque
    if torque_input_level != 0 and energy > 0:
        var torque_magnitude_cfg_idx = abs(torque_input_level)
        var torque_value_sim = Config.Probe.TORQUE_MAGNITUDES[torque_magnitude_cfg_idx]
        if torque_input_level < 0: # Negative torque level means clockwise
            torque_value_sim = -torque_value_sim
        
        var angular_accel = torque_value_sim / Config.Probe.MOMENT_OF_INERTIA # alpha = Torque / I
        current_angular_velocity += angular_accel * delta
        
        var energy_cost_torque = abs(torque_value_sim) * Config.Probe.ROTATIONAL_ENERGY_COST_FACTOR * delta # Assuming ROTATIONAL_ENERGY_COST_FACTOR in Config
        consume_energy(energy_cost_torque)

    # Angular Damping & Clamping
    current_angular_velocity *= (1.0 - Config.Probe.ANGULAR_DAMPING_FACTOR * delta)
    current_angular_velocity = clamp(current_angular_velocity, -Config.Probe.MAX_ANGULAR_VELOCITY_RAD_PER_STEP, Config.Probe.MAX_ANGULAR_VELOCITY_RAD_PER_STEP)
    
    # Update rotation (angle)
    rotation += current_angular_velocity * delta # rotation is a built-in Node2D property for angle in radians

    # Apply acceleration to velocity (CharacterBody2D velocity)
    velocity += current_acceleration * delta # Assuming current_acceleration is already (Force/mass)*delta or just Force/mass
                                            # If current_acceleration is F/m, then: velocity += current_acceleration * delta
                                            # If current_acceleration is F, then: velocity += (current_acceleration / mass_kg) * delta
                                            # The current_acceleration above is F/m, so this is correct.

    # Velocity Clamping (CharacterBody2D velocity)
    if velocity.length_squared() > Config.Probe.MAX_VELOCITY_SIM_PER_STEP * Config.Probe.MAX_VELOCITY_SIM_PER_STEP :
        velocity = velocity.normalized() * Config.Probe.MAX_VELOCITY_SIM_PER_STEP

    # Apply movement
    var _collision_info = move_and_slide() # CharacterBody2D handles collisions

    # Energy Decay
    consume_energy(Config.Probe.ENERGY_DECAY_RATE_PER_STEP * delta)

    # Update Trail
    add_point_to_trail(global_position)
    
    # Update previous_step_acceleration for next frame (if using custom physics like Verlet)
    previous_step_acceleration = current_acceleration # Store F/m

    # Check for death again, in case energy ran out due to decay/actions
    if energy <= 0.0 and alive:
        die()

# --- AI Action Application ---
func apply_ai_action(action_array: Array):
    if action_array.size() < Config.RL.ACTION_SPACE_DIMS.size():
        printerr("Probe (%s): Received action array smaller than expected dimensions." % name)
        return

    # Assuming action_array maps directly to Config.RL.ACTION_SPACE_DIMS
    # Example: Thrust, Torque, Communicate, Replicate, Target
    thrust_input_level = clamp(int(action_array[0]), 0, Config.Probe.THRUST_FORCE_MAGNITUDES.size() - 1)
    
    # Torque: map [0, TORQUE_MAGNITUDES.size()*2] to [-TORQUE_MAGNITUDES.size()+1, TORQUE_MAGNITUDES.size()-1]
    # Example: if TORQUE_MAGNITUDES has 3 levels (0,1,2 for actual torque values), then input action is 0..4
    # 0 -> -2 (max CW), 1 -> -1 (mid CW), 2 -> 0 (no torque), 3 -> 1 (mid CCW), 4 -> 2 (max CCW)
    var num_torque_levels_positive = Config.Probe.TORQUE_MAGNITUDES.size() -1 # Number of non-zero torque levels
    var raw_torque_action = int(action_array[1])
    torque_input_level = raw_torque_action - num_torque_levels_positive 
    # This makes action_array[1] range from 0 to (num_torque_levels_positive * 2)
    # Example: if TORQUE_MAGNITUDES = [0.0, 0.008, 0.018] (size 3), num_torque_levels_positive = 2
    # Action input range for torque: 0, 1, 2, 3, 4
    # 0 -> torque_input_level = 0 - 2 = -2
    # 1 -> torque_input_level = 1 - 2 = -1
    # 2 -> torque_input_level = 2 - 2 =  0
    # 3 -> torque_input_level = 3 - 2 =  1
    # 4 -> torque_input_level = 4 - 2 =  2
    
    # --- Other actions from AI ---
    var communicate_action = int(action_array[2]) if action_array.size() > 2 else 0
    var replicate_action = int(action_array[3]) if action_array.size() > 3 else 0
    var target_action_idx = int(action_array[4]) if action_array.size() > 4 else 0 # 0 means no change or clear target

    if communicate_action == 1:
        # TODO: Implement communication logic (e.g., send message via SolarSystem)
        pass
    
    if replicate_action == 1 and energy >= Config.Probe.REPLICATION_COST:
        attempt_replication()
    
    if target_action_idx > 0: # Assuming 0 is "no target" or "keep current"
        var nearest_resources = get_nearby_entities("resources", Config.RL.NUM_OBSERVED_RESOURCES_FOR_TARGETING)
        var actual_target_idx = target_action_idx - 1 # Adjust if 0 was "no target"
        if actual_target_idx < nearest_resources.size():
            var new_target = nearest_resources[actual_target_idx]
            if new_target is ResourceNode:
                set_target_resource(new_target)
    elif target_action_idx == 0: # Explicitly clear target if action is 0
        set_target_resource(null)


# --- Observation for AI ---
func get_current_observation() -> Array:
    var obs: Array[float] = [] # Use Array of floats for PackedFloat32Array conversion

    # 1. Probe's own state
    obs.append(global_position.x / Config.World.WIDTH_SIM) # Normalize
    obs.append(global_position.y / Config.World.HEIGHT_SIM) # Normalize
    obs.append(velocity.x / Config.Probe.MAX_VELOCITY_SIM_PER_STEP) # Normalize
    obs.append(velocity.y / Config.Probe.MAX_VELOCITY_SIM_PER_STEP) # Normalize
    obs.append(fmod(rotation + TAU, TAU) / TAU) # Normalize angle to 0-1 (TAU = 2*PI)
    obs.append(current_angular_velocity / Config.Probe.MAX_ANGULAR_VELOCITY_RAD_PER_STEP) # Normalize
    obs.append(energy / Config.Probe.MAX_ENERGY) # Normalize
    obs.append(float(is_mining_active)) # Boolean to float

    # 2. Nearest Resources (example: 3 resources)
    var nearest_resources = get_nearby_entities("resources", Config.RL.NUM_OBSERVED_RESOURCES_FOR_TARGETING)
    for i in range(Config.RL.NUM_OBSERVED_RESOURCES_FOR_TARGETING):
        if i < nearest_resources.size():
            var res_node: ResourceNode = nearest_resources[i]
            var relative_pos = res_node.global_position - global_position
            obs.append(relative_pos.x / Config.World.WIDTH_SIM)  # Normalized relative position
            obs.append(relative_pos.y / Config.World.HEIGHT_SIM)
            obs.append(relative_pos.length() / Config.World.WIDTH_SIM) # Normalized distance
            obs.append(res_node.amount / res_node.max_amount if res_node.max_amount > 0 else 0.0) # Normalized amount
            obs.append(1.0 if res_node == target_resource_node else 0.0) # Is this resource the current target
        else:
            # Pad with default values if fewer than NUM_OBSERVED_RESOURCES are found
            obs.append(0.0); obs.append(0.0); obs.append(1.0); obs.append(0.0); obs.append(0.0) # Large distance, no amount

    # 3. Nearest Probes (example: 2 other probes)
    # var nearest_probes = get_nearby_entities("probes", Config.RL.NUM_OBSERVED_PROBES + 1, self) # +1 to exclude self, then take top N
    # var actual_other_probes_observed = 0
    # for i in range(Config.RL.NUM_OBSERVED_PROBES):
    #     if i < nearest_probes.size():
    #         var other_probe: Probe = nearest_probes[i]
    #         var rel_pos_other = other_probe.global_position - global_position
    #         obs.append(rel_pos_other.x / Config.World.WIDTH_SIM)
    #         obs.append(rel_pos_other.y / Config.World.HEIGHT_SIM)
    #         obs.append(other_probe.energy / Config.Probe.MAX_ENERGY)
    #         # Potentially communication status or other relevant info
    #         actual_other_probes_observed += 1
    #     else:
    #         obs.append(0.0); obs.append(0.0); obs.append(0.0)
            
    # Ensure observation array matches expected size from Config.RL.OBSERVATION_SPACE_SIZE
    while obs.size() < Config.RL.OBSERVATION_SPACE_SIZE:
        obs.append(0.0) # Pad with zeros
    if obs.size() > Config.RL.OBSERVATION_SPACE_SIZE:
        obs = obs.slice(0, Config.RL.OBSERVATION_SPACE_SIZE) # Truncate if too long

    return obs

func get_nearby_entities(group_name: String, count: int, exclude_self: Node = null) -> Array:
    var entities_in_group = get_tree().get_nodes_in_group(group_name)
    var sorted_entities: Array[Node] = []

    var distances: Array[Dictionary] = [] # Store as {"node": Node, "dist_sq": float}
    for entity_node in entities_in_group:
        if not is_instance_valid(entity_node) or entity_node == exclude_self:
            continue
        if not entity_node is Node2D: continue # Ensure it has global_position

        var dist_sq = global_position.distance_squared_to(entity_node.global_position)
        distances.append({"node": entity_node, "dist_sq": dist_sq})

    distances.sort_custom(func(a,b): return a.dist_sq < b.dist_sq)

    for i in range(min(count, distances.size())):
        sorted_entities.append(distances[i].node)
        
    return sorted_entities


# --- Probe Actions & State Changes ---
func consume_energy(amount: float):
    if amount <= 0: return
    energy -= amount # Setter handles clamping and death check

func die():
    if not alive: return # Already dead
    
    print("Probe %s is dying." % name)
    alive = false # Setter handles visual changes
    energy = 0 # Ensure energy is zero
    
    # Emit signal for GameManager or SolarSystem to handle
    energy_depleted.emit(self) # Or a more general 'probe_died' signal
    destroyed.emit(self)
    
    # Stop any ongoing actions
    if is_mining_active:
        stop_mining()
        
    # Could add a small explosion effect or change sprite to wreckage
    # This might be better handled by a separate "death_effect" node spawned by SolarSystem
    
    # Optional: After a delay, queue_free() the probe node.
    # This should be managed by a higher-level system (e.g., SolarSystem cleanup)
    # to avoid issues if other nodes still reference it.
    # For now, just mark as not alive. Visuals handled by OrganicShipRenderer.

func attempt_replication():
    if energy >= Config.Probe.REPLICATION_COST:
        # Don't deduct energy here; let SolarSystem confirm and deduct upon successful creation
        replication_attempted.emit(self, Config.Probe.REPLICATION_COST)
        # SolarSystem will listen to this, try to create a new probe, and if successful,
        # it will call a method on this probe to deduct the energy.
    else:
        # print("Probe %s: Not enough energy to replicate." % name)
        pass

func confirm_replication_energy_deduction():
    consume_energy(Config.Probe.REPLICATION_COST)
    # print("Probe %s: Energy deducted for successful replication." % name)


func set_target_resource(new_target: ResourceNode):
    if target_resource_node == new_target:
        return # No change

    if is_mining_active: # If currently mining something else, stop first
        stop_mining()

    target_resource_node = new_target
    # print("Probe %s new target: %s" % [name, target_resource_node.name if target_resource_node else "None"])

    # AI might need to be notified or re-evaluate if target changes externally
    # For now, observation includes target status.

func start_mining(resource_node: ResourceNode):
    if not is_instance_valid(resource_node) or resource_node.amount <= 0:
        # print("Probe %s: Cannot start mining, target invalid or depleted." % name)
        return

    if target_resource_node != resource_node: # Ensure we are targeting what we are trying to mine
        set_target_resource(resource_node) # This will stop previous mining if any

    if global_position.distance_to(resource_node.global_position) <= Config.SimResource.HARVEST_DISTANCE_SIM:
        is_mining_active = true
        # ResourceNode itself handles energy gain for the probe via its process_mining
        # Probe just needs to signal its intent or state.
        # The ResourceNode can check if this probe is in its 'miners' list.
        # For clarity, the probe can also directly tell the resource it's starting.
        if resource_node.has_method("add_miner"): # Assuming ResourceNode has add_miner
            resource_node.add_miner(self)
        mining_started.emit(self, resource_node)
        # print("Probe %s started mining %s" % [name, resource_node.name])
    # else:
        # print("Probe %s: Target %s too far to start mining." % [name, resource_node.name])


func stop_mining():
    if not is_mining_active:
        return
    
    is_mining_active = false
    if is_instance_valid(target_resource_node):
        if target_resource_node.has_method("remove_miner"): # Assuming ResourceNode has remove_miner
            target_resource_node.remove_miner(self)
        mining_stopped.emit(self) # Pass self
        # print("Probe %s stopped mining %s" % [name, target_resource_node.name if target_resource_node else ""])
    # target_resource_node = null # Optionally clear target when stopping mining, or let AI decide


# --- Trail Management ---
func add_point_to_trail(pos: Vector2):
    trail_points_buffer.append(pos)
    if trail_points_buffer.size() > Config.Visualization.MAX_PROBE_TRAIL_POINTS:
        trail_points_buffer.pop_front()
    
    if is_instance_valid(trail_renderer_node):
        trail_renderer_node.update_trail(trail_points_buffer)

# --- Public getters/setters if needed by other systems ---
func get_probe_id() -> int: return probe_id
func get_energy() -> float: return energy
func is_alive() -> bool: return alive
func get_generation() -> int: return generation

# Called by SolarSystem or GameManager to assign an AI model
func assign_ai_model(model: ProbeAIModel):
    if is_instance_valid(ai_component_node):
        ai_component_node.initialize_ai_model(model)
    else:
        printerr("Probe %s: Cannot assign AI model, AIComponent not found." % name)

# For SolarSystem to reset probe for a new episode
func reset_for_new_episode(start_pos: Vector2, start_angle_rad: float = 0.0):
    global_position = start_pos
    current_angle_rad = start_angle_rad
    rotation = current_angle_rad
    
    velocity = Vector2.ZERO
    current_angular_velocity = 0.0
    previous_step_acceleration = Vector2.ZERO
    
    energy = Config.Probe.INITIAL_ENERGY
    alive = true # This will trigger setter if it was false
    
    thrust_input_level = 0
    torque_input_level = 0
    
    is_mining_active = false
    if is_instance_valid(target_resource_node) and target_resource_node.has_method("remove_miner"):
        target_resource_node.remove_miner(self)
    target_resource_node = null
    
    trail_points_buffer.clear()
    if is_instance_valid(trail_renderer_node):
        trail_renderer_node.update_trail(trail_points_buffer)
        
    if is_instance_valid(thruster_particles_node):
        thruster_particles_node.emitting = false
        thruster_particles_node.restart() # Reset particle system state

    if is_instance_valid(ai_component_node):
        # AI model is usually kept, but experience buffer might be cleared by GameManager or AI itself
        # ai_component_node.experience_buffer.clear() # Or handle this in GameManager
        pass

    last_observation = get_current_observation() # Get fresh observation
    last_action_taken.clear()
    steps_since_last_learn = 0

    print("Probe %s reset for new episode." % name)