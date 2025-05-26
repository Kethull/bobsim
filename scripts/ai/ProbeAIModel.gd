extends Resource
class_name ProbeAIModel

const NeuralNetwork = preload("res://scripts/ai/NeuralNetwork.gd")
var neural_network: NeuralNetwork
var generation: int = 0
var mutation_rate: float = Config.RL.MUTATION_RATE_INITIAL # Assuming MUTATION_RATE_INITIAL is in Config.RL
var mutation_strength: float = Config.RL.MUTATION_STRENGTH_INITIAL # Assuming MUTATION_STRENGTH_INITIAL is in Config.RL

func _init(p_generation: int = 0, p_mutation_rate: float = -1.0, p_mutation_strength: float = -1.0):
    generation = p_generation
    if p_mutation_rate >= 0: mutation_rate = p_mutation_rate
    if p_mutation_strength >= 0: mutation_strength = p_mutation_strength
    # Neural network is usually setup by calling setup_neural_network explicitly

func setup_neural_network(input_size: int = -1, output_action_dims: Array = [], hidden_layer_sizes: Array = []):
    neural_network = NeuralNetwork.new()

    var obs_space_size = Config.RL.OBSERVATION_SPACE_SIZE if input_size == -1 else input_size
    var action_space_dims = Config.RL.ACTION_SPACE_DIMS if output_action_dims.is_empty() else output_action_dims
    var hid_layers = Config.RL.HIDDEN_LAYER_SIZES if hidden_layer_sizes.is_empty() else hidden_layer_sizes

    # Calculate total output units if action space is multi-discrete
    # For Q-learning, output is typically Q-values for each discrete action combination.
    var output_size = 1
    if action_space_dims.size() > 0 : # If it's an array of dimensions for discrete actions
        for dim_size in action_space_dims:
            output_size *= dim_size # Total number of combined discrete actions
    else: # If action_space_dims is just a number (e.g. for continuous or single discrete)
        output_size = action_space_dims if not typeof(action_space_dims) == TYPE_ARRAY else Config.RL.DEFAULT_ACTION_OUTPUT_SIZE # Fallback

    neural_network.add_layer(obs_space_size, "relu") # Input layer implicitly defined by first weights, first add_layer is first hidden
    for hidden_size in hid_layers:
        neural_network.add_layer(hidden_size, "relu")
    neural_network.add_layer(output_size, "linear") # Output layer for Q-values is typically linear

    neural_network.initialize_network()


func predict(observation: PackedFloat32Array) -> PackedFloat32Array: # Expect PackedFloat32Array
    if not neural_network:
        printerr("ProbeAIModel: Neural network not initialized.")
        # Return a default action array of the correct size if possible
        var output_size = 1
        var action_space_dims = Config.RL.ACTION_SPACE_DIMS
        if action_space_dims.size() > 0 :
            for dim_size in action_space_dims: output_size *= dim_size
        else: output_size = action_space_dims if not typeof(action_space_dims) == TYPE_ARRAY else Config.RL.DEFAULT_ACTION_OUTPUT_SIZE
        
        var default_output = PackedFloat32Array()
        default_output.resize(output_size)
        default_output.fill(0.0) # Fill with zeros
        return default_output

    return neural_network.forward_pass(observation)

func train_on_batch(experiences: Array): # experiences is an array of Dictionaries
    if not neural_network or experiences.is_empty():
        printerr("ProbeAIModel: NN not initialized or no experiences to train on.")
        return

    var batch_inputs: Array[PackedFloat32Array] = []
    var batch_targets: Array[PackedFloat32Array] = []

    for experience in experiences:
        var obs_array: Array = experience.observation # Assuming observation is Array, convert to PackedFloat32Array
        var next_obs_array: Array = experience.next_observation
        
        var current_observation_packed = PackedFloat32Array(obs_array)
        var next_observation_packed = PackedFloat32Array(next_obs_array)

        # Get current Q-values for the current observation
        var current_q_values: PackedFloat32Array = predict(current_observation_packed)
        var target_q_values = current_q_values.duplicate() # Start with current Q-values

        # Calculate target Q-value for the action taken
        var reward: float = experience.reward
        var done: bool = experience.done
        var action_taken_array: Array = experience.action # Assuming action is Array
        
        var action_index = get_flat_action_index(action_taken_array)

        if action_index < 0 or action_index >= target_q_values.size():
            printerr("ProbeAIModel: Action index out of bounds. Action: ", action_taken_array, " Index: ", action_index, " Q-size: ", target_q_values.size())
            continue

        var future_q_value: float = 0.0
        if not done:
            var next_q_values: PackedFloat32Array = predict(next_observation_packed)
            if next_q_values.size() > 0:
                var max_q = -INF
                for q_val in next_q_values:
                    if q_val > max_q:
                        max_q = q_val
                future_q_value = max_q # Max Q-value for the next state (Q-learning)
        
        var updated_q_value = reward + Config.RL.GAMMA * future_q_value
        target_q_values[action_index] = updated_q_value
        
        batch_inputs.append(current_observation_packed)
        batch_targets.append(target_q_values)

    if not batch_inputs.is_empty():
        neural_network.train_batch(batch_inputs, batch_targets, Config.RL.LEARNING_RATE)


func get_flat_action_index(action_array: Array) -> int:
    # Converts a multi-discrete action (array of choices for each dimension)
    # into a single flat index for the Q-table/NN output array.
    # E.g., if ACTION_SPACE_DIMS = [3, 2], actions [0,0] -> 0, [0,1] -> 1, [1,0] -> 2, etc.
    if action_array.is_empty() or Config.RL.ACTION_SPACE_DIMS.is_empty():
        # Handle case for single continuous action or if action_array is already an index
        if action_array.size() == 1 and typeof(action_array[0]) in [TYPE_INT, TYPE_FLOAT]:
            return int(action_array[0]) 
        printerr("ProbeAIModel: Action array or ACTION_SPACE_DIMS is empty for flat index conversion.")
        return 0 # Default or error index

    var index = 0
    var multiplier = 1
    # Iterate from the last action dimension to the first
    for i in range(Config.RL.ACTION_SPACE_DIMS.size() - 1, -1, -1):
        if i >= action_array.size(): 
            printerr("ProbeAIModel: Action array size mismatch with ACTION_SPACE_DIMS.")
            return -1 # Error
        
        var choice_for_dim = action_array[i]
        var dim_size = Config.RL.ACTION_SPACE_DIMS[i]
        
        if not typeof(choice_for_dim) in [TYPE_INT, TYPE_FLOAT] or choice_for_dim < 0 or choice_for_dim >= dim_size:
            printerr("ProbeAIModel: Invalid action choice for dimension. Choice: ", choice_for_dim, " Dim size: ", dim_size)
            return -1 # Error
            
        index += int(choice_for_dim) * multiplier
        multiplier *= dim_size
        
    return index

func mutate():
    if neural_network:
        neural_network.mutate_weights(mutation_rate, mutation_strength)
        generation += 1 # Increment generation after mutation

func clone() -> ProbeAIModel:
    var new_model = ProbeAIModel.new(generation, mutation_rate, mutation_strength)
    if neural_network:
        new_model.neural_network = neural_network.clone()
    # If NN is not yet set up in the original, the clone also won't have it set up.
    # It would need to be set up via setup_neural_network() later.
    return new_model

# --- Save/Load Functionality ---
func save_to_file(path: String):
    if not neural_network:
        printerr("ProbeAIModel: Cannot save, NeuralNetwork not initialized.")
        return

    var model_data = {
        "generation": generation,
        "mutation_rate": mutation_rate,
        "mutation_strength": mutation_strength,
        "neural_network_data": neural_network.save_to_dictionary() # NN saves its own structure
    }
    
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        printerr("Failed to open file for saving ProbeAIModel: %s" % path)
        return
    file.store_string(JSON.stringify(model_data, "\t"))
    file.close()
    print("ProbeAIModel saved to: %s" % path)

func load_from_file(path: String):
    if not FileAccess.file_exists(path):
        printerr("ProbeAIModel file not found: %s" % path)
        return false

    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        printerr("Failed to open file for loading ProbeAIModel: %s" % path)
        return false
        
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        printerr("Failed to parse ProbeAIModel JSON from %s. Error: %s, Line: %s" % [path, json.get_error_message(), json.get_error_line()])
        return false
    
    var data: Dictionary = json.data
    
    generation = data.get("generation", 0)
    mutation_rate = data.get("mutation_rate", Config.RL.MUTATION_RATE_INITIAL)
    mutation_strength = data.get("mutation_strength", Config.RL.MUTATION_STRENGTH_INITIAL)
    
    var nn_data = data.get("neural_network_data")
    if nn_data:
        if not neural_network: # Create if not exists
            neural_network = NeuralNetwork.new()
        neural_network.load_from_dictionary(nn_data)
    else:
        printerr("ProbeAIModel: No neural_network_data found in file. NN not loaded/reinitialized.")
        # Optionally, reinitialize a default one:
        # setup_neural_network() 
        return false
        
    print("ProbeAIModel loaded from: %s (Gen: %d)" % [path, generation])
    return true