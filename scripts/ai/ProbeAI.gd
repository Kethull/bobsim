extends Node
class_name ProbeAI

# Reference to the Probe this AI component is attached to.
# Should be set by the Probe node itself.
var probe_node: Node # Changed from 'probe: Probe' to avoid cyclic dependency if Probe class not yet defined

var ai_model: ProbeAIModel
var experience_buffer: Array[Dictionary] = [] # Stores {"obs", "action", "reward", "next_obs", "done"}
var learning_enabled: bool = Config.RL.LEARNING_ENABLED_DEFAULT # Default from config

var previous_observation_for_reward: Array = [] # Store previous obs to calculate reward based on state change

func _ready():
    # ai_model should be initialized by the GameManager or when the probe is created/setup.
    # For standalone testing, you might initialize a default model here:
    # if not ai_model:
    #    initialize_ai_model() # Or a more specific setup
    pass

func initialize_ai_model(model_to_use: ProbeAIModel = null):
    if model_to_use:
        ai_model = model_to_use
    else:
        ai_model = ProbeAIModel.new()
        # Ensure the neural network within the model is set up
        # The parameters for setup_neural_network might come from Config.RL
        ai_model.setup_neural_network(
            Config.RL.OBSERVATION_SPACE_SIZE,
            Config.RL.ACTION_SPACE_DIMS,
            Config.RL.HIDDEN_LAYER_SIZES
        )
    # print("ProbeAI initialized with model (Gen: %d)" % ai_model.generation if ai_model else "ProbeAI initialized (No model)")

func predict_action_q_learning(observation_array: Array) -> Array:
    if not ai_model:
        # printerr("ProbeAI (%s): No AI model available for prediction. Returning random action." % probe_node.name if probe_node else "ProbeAI")
        return get_random_action_array()

    var observation_packed = PackedFloat32Array(observation_array)
    var q_values: PackedFloat32Array = ai_model.predict(observation_packed)

    if q_values.is_empty():
        # printerr("ProbeAI (%s): AI model prediction returned empty. Returning random action." % probe_node.name if probe_node else "ProbeAI")
        return get_random_action_array()

    # Epsilon-greedy strategy for exploration
    if learning_enabled and randf() < Config.RL.get_epsilon_current():
        return get_random_action_array()
    else:
        # Choose action with the highest Q-value
        var best_action_flat_index = 0
        var max_q = -INF
        for i in range(q_values.size()):
            if q_values[i] > max_q:
                max_q = q_values[i]
                best_action_flat_index = i
        return get_action_array_from_flat_index(best_action_flat_index)


func get_action_array_from_flat_index(flat_index: int) -> Array:
    # Converts a flat index (from NN output) back to a multi-discrete action array.
    # E.g., if ACTION_SPACE_DIMS = [3, 2], index 0 -> [0,0], 1 -> [0,1], 2 -> [1,0]
    if Config.RL.ACTION_SPACE_DIMS.is_empty():
        printerr("ProbeAI: ACTION_SPACE_DIMS is empty. Cannot convert flat index to action array.")
        return [flat_index] # Assuming single dimension if empty

    var action_array: Array = []
    action_array.resize(Config.RL.ACTION_SPACE_DIMS.size())
    var current_index = flat_index

    # Iterate from first action dimension to last
    for i in range(Config.RL.ACTION_SPACE_DIMS.size()):
        var dim_size = Config.RL.ACTION_SPACE_DIMS[i]
        if dim_size <= 0: 
            printerr("ProbeAI: Invalid dimension size in ACTION_SPACE_DIMS: ", dim_size)
            action_array[i] = 0 # Default
            continue
            
        var product_of_subsequent_dims = 1
        for j in range(i + 1, Config.RL.ACTION_SPACE_DIMS.size()):
            product_of_subsequent_dims *= Config.RL.ACTION_SPACE_DIMS[j]
        
        var choice_for_dim = floor(current_index / product_of_subsequent_dims)
        action_array[i] = int(choice_for_dim)
        current_index -= choice_for_dim * product_of_subsequent_dims
        
    return action_array

func get_random_action_array() -> Array:
    var random_action: Array = []
    if Config.RL.ACTION_SPACE_DIMS.is_empty():
        # Fallback for a single continuous action or undefined discrete space
        random_action.append(randf_range(Config.RL.RANDOM_ACTION_LOW_FALLBACK, Config.RL.RANDOM_ACTION_HIGH_FALLBACK))
        return random_action

    for dim_size in Config.RL.ACTION_SPACE_DIMS:
        if dim_size <= 0:
            printerr("ProbeAI: Invalid dimension size for random action: ", dim_size)
            random_action.append(0) # Default
        else:
            random_action.append(randi() % dim_size)
    return random_action

func store_experience(observation: Array, action: Array, reward: float, next_observation: Array, done: bool):
    if not learning_enabled:
        return

    experience_buffer.append({
        "observation": observation,       # Array
        "action": action,                 # Array (multi-discrete choices)
        "reward": reward,                 # float
        "next_observation": next_observation, # Array
        "done": done                      # bool
    })
    
    # Keep buffer size within limits
    var max_buffer_size = Config.RL.EXPERIENCE_BUFFER_SIZE
    while experience_buffer.size() > max_buffer_size:
        experience_buffer.pop_front()

func learn_from_experience_batch():
    if not learning_enabled or not ai_model or experience_buffer.size() < Config.RL.BATCH_SIZE:
        return

    # Sample a random batch from the buffer
    var batch: Array[Dictionary] = []
    var buffer_size = experience_buffer.size()
    for _i in range(Config.RL.BATCH_SIZE):
        batch.append(experience_buffer[randi() % buffer_size])
    
    ai_model.train_on_batch(batch)

    # Decay epsilon for epsilon-greedy strategy
    Config.RL.decay_epsilon_value()


func calculate_reward(current_observation: Array) -> float:
    # Reward calculation needs access to probe's state, which should be part of current_observation
    # or directly from probe_node if absolutely necessary (though obs is cleaner).
    # The original document's reward function used probe.is_mining, probe.target_resource etc.
    # These need to be mapped from current_observation indices or by accessing probe_node.
    
    var reward: float = 0.0
    if not is_instance_valid(probe_node): return 0.0 # No probe, no reward context

    # --- Survival Reward ---
    reward += Config.RL.REWARD_ALIVE_PER_STEP

    # --- Energy Management ---
    # Assuming energy is at a known index in current_observation, e.g., index 6 from original Probe.gd
    var energy_normalized: float = current_observation[Config.RL.OBS_IDX_ENERGY] if Config.RL.OBS_IDX_ENERGY < current_observation.size() else 0.0
    
    if energy_normalized > Config.RL.HIGH_ENERGY_THRESHOLD:
        reward += Config.RL.REWARD_HIGH_ENERGY_BONUS
    elif energy_normalized < Config.RL.PENALTY_LOW_ENERGY_THRESHOLD_1:
        reward -= Config.RL.PENALTY_LOW_ENERGY_FACTOR_1
        if energy_normalized < Config.RL.PENALTY_LOW_ENERGY_THRESHOLD_2:
            reward -= Config.RL.PENALTY_LOW_ENERGY_FACTOR_2
    
    # --- Mining Rewards ---
    # This requires knowing if the probe is mining. This state might be part of the observation
    # or needs to be fetched from probe_node.
    var is_mining_flag = probe_node.get("is_mining") if probe_node else false # Example access
    if is_mining_flag:
        reward += Config.RL.REWARD_MINING_SUCCESS_PER_STEP
        # Could add bonus for amount mined if that info is available
        # var mined_this_step = probe_node.get("last_mined_amount") # Fictional property
        # reward += mined_this_step * Config.RL.REWARD_MINING_AMOUNT_MULTIPLIER

    # --- Proximity to Target Resource ---
    # This requires knowing the distance to the target resource.
    # Observation might include relative_pos_to_target.x, relative_pos_to_target.y
    # Or, if probe_node.target_resource is set:
    var target_res = probe_node.get("target_resource") if probe_node else null
    if is_instance_valid(target_res):
        var dist_to_target_sq = probe_node.global_position.distance_squared_to(target_res.global_position)
        # Normalize distance or use a falloff function
        var proximity_reward_val = Config.RL.REWARD_TARGET_PROXIMITY_FACTOR / (1.0 + sqrt(dist_to_target_sq) / Config.RL.REWARD_PROXIMITY_FALLOFF_DIST_SIM)
        reward += proximity_reward_val
        
    # --- Action Cost Penalties (Optional) ---
    # var action_taken = ... (if needed, but usually handled by energy consumption)
    # reward -= get_action_cost(action_taken)

    # --- Exploration Bonus (More advanced) ---
    # E.g., based on visiting new states or uncertainty.

    # --- Penalty for dying ---
    var is_alive_flag = probe_node.get("alive") if probe_node else true
    if not is_alive_flag:
        reward -= Config.RL.PENALTY_DEATH

    # Update previous_observation_for_reward for next step's calculation if needed
    # previous_observation_for_reward = current_observation.duplicate()
    
    return reward

# Call this from the Probe's main update loop
func update_ai_logic(current_observation_array: Array):
    if not is_instance_valid(probe_node) or not probe_node.get("alive"):
        return

    # 1. Decide action based on current observation
    var action_to_take = predict_action_q_learning(current_observation_array)
    
    # 2. Probe applies the action (this happens in Probe.gd after getting action from AI)
    # probe_node.apply_action(action_to_take) 
    # After action, probe's state changes, and it gets a new observation (next_observation)
    # and a reward. This typically happens in the next frame/step.

    # For storing experience, we need:
    # - The observation that led to `action_to_take` (which is `current_observation_array`)
    # - The `action_to_take` itself
    # - The `reward` received *after* taking the action
    # - The `next_observation` *after* taking the action
    # - Whether the episode is `done` *after* taking the action

    # This means store_experience is usually called *after* the probe has acted and the environment has responded.
    # So, the Probe.gd script, after calling its physics update and getting a new observation,
    # would call something like: ai_component.record_transition(prev_obs, action_taken, reward_received, new_obs, is_done)
    
    # For now, let's assume the reward calculation and experience storage will be triggered
    # by the Probe after it has processed a step.

    # If learning is enabled and it's time to learn (e.g., every N steps or buffer has enough)
    if learning_enabled and experience_buffer.size() >= Config.RL.BATCH_SIZE:
        var _scll_val = probe_node.get("step_count_since_last_learn") # scll: step_count_since_last_learn
        if (_scll_val if _scll_val != null else 0) >= Config.RL.LEARN_EVERY_N_STEPS: # Fictional counter
             learn_from_experience_batch()
             # probe_node.set("step_count_since_last_learn", 0) # Reset counter


# This method would be called by the Probe after its state has been updated
# and a new observation is available.
func record_transition_and_learn(
    prev_observation: Array, 
    action_taken: Array, 
    reward_for_action: float, 
    current_new_observation: Array, 
    is_episode_done: bool
    ):
    store_experience(prev_observation, action_taken, reward_for_action, current_new_observation, is_episode_done)
    
    # Potentially trigger learning
    if learning_enabled and experience_buffer.size() >= Config.RL.BATCH_SIZE:
        # Add a condition to learn only every N steps or based on some other trigger
        # For example, if a counter in the probe or game manager says it's time.
        # This avoids learning on every single step which can be computationally intensive.
        # Let's assume a global step counter or a probe-specific one.
        var game_step = Engine.get_physics_frames() # Example global step
        if game_step % Config.RL.LEARN_EVERY_N_STEPS == 0:
             learn_from_experience_batch()

func set_probe_reference(p_probe_node: Node):
    probe_node = p_probe_node