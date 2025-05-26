extends Resource
class_name NeuralNetwork

var layers_config: Array = [] # Stores {"size": int, "activation": String}
var weights: Array = [] # Array of weight matrices (PackedFloat32Array or Array of Arrays)
var biases: Array = []  # Array of bias vectors (PackedFloat32Array or Array)

func _init(p_layers_config: Array = []):
    if not p_layers_config.is_empty():
        layers_config = p_layers_config
        initialize_network()

func add_layer(size: int, activation_type: String = "relu"):
    # activation_type can be "relu", "sigmoid", "linear", "tanh", etc.
    layers_config.append({"size": size, "activation": activation_type})
    # Call initialize_network() if adding layers after initial _init,
    # or have a separate build_network() method. For now, assume layers are defined before init.

func initialize_network():
    weights.clear()
    biases.clear()
    
    if layers_config.size() < 2:
        printerr("NeuralNetwork: At least 2 layers (input and output) are required.")
        return

    for i in range(layers_config.size() - 1):
        var input_neurons = layers_config[i].size
        var output_neurons = layers_config[i+1].size
        
        # Initialize weights (e.g., Xavier/Glorot initialization)
        var limit = sqrt(6.0 / (input_neurons + output_neurons))
        var layer_w = []
        for _j in range(output_neurons): # For each neuron in the current layer (i+1)
            var neuron_w = PackedFloat32Array() # Weights connecting from all input_neurons to this one neuron
            neuron_w.resize(input_neurons)
            for k in range(input_neurons):
                neuron_w[k] = randf_range(-limit, limit)
            layer_w.append(neuron_w)
        weights.append(layer_w)
        
        # Initialize biases (often to zero or small constant)
        var layer_b = PackedFloat32Array()
        layer_b.resize(output_neurons)
        for j in range(output_neurons):
            layer_b[j] = 0.0 # Or randf_range(-0.01, 0.01)
        biases.append(layer_b)

func forward_pass(inputs: PackedFloat32Array) -> PackedFloat32Array:
    if layers_config.is_empty() or inputs.size() != layers_config[0].size:
        printerr("NeuralNetwork: Input size mismatch or network not initialized.")
        return PackedFloat32Array()

    var current_values = inputs.duplicate()

    for layer_idx in range(weights.size()): # Iterate through each layer of weights/biases
        var layer_weights = weights[layer_idx] # This is an array of neuron_weight_vectors for this layer
        var layer_biases: PackedFloat32Array = biases[layer_idx]
        var activation_type = layers_config[layer_idx + 1].activation # Activation for the current layer being computed
        
        var next_layer_values = PackedFloat32Array()
        next_layer_values.resize(layers_config[layer_idx+1].size)

        for neuron_idx in range(layer_weights.size()): # For each neuron in this layer
            var neuron_w: PackedFloat32Array = layer_weights[neuron_idx]
            var dot_product: float = 0.0
            # Weighted sum
            for input_idx in range(current_values.size()):
                dot_product += current_values[input_idx] * neuron_w[input_idx]
            
            dot_product += layer_biases[neuron_idx] # Add bias
            next_layer_values[neuron_idx] = apply_activation(dot_product, activation_type)
            
        current_values = next_layer_values

    return current_values

func apply_activation(value: float, type: String) -> float:
    match type.to_lower():
        "relu":
            return max(0.0, value)
        "sigmoid":
            return 1.0 / (1.0 + exp(-value))
        "tanh":
            return tanh(value)
        "linear":
            return value
        _: # Default to linear if unknown
            printerr("NeuralNetwork: Unknown activation function '%s', using linear." % type)
            return value

func train_batch(batch_inputs: Array[PackedFloat32Array], batch_targets: Array[PackedFloat32Array], learning_rate: float):
    # This is a placeholder for a very simple gradient descent.
    # Proper backpropagation is significantly more complex.
    # The original document's backprop was also very simplified.
    
    if batch_inputs.size() != batch_targets.size() or batch_inputs.is_empty():
        printerr("NN train_batch: Input and target batch sizes differ or are empty.")
        return

    for i in range(batch_inputs.size()):
        var single_input = batch_inputs[i]
        var single_target = batch_targets[i]
        
        # --- Simplified Gradient Calculation (Output Layer Only) ---
        # This is NOT full backpropagation. It's a heuristic adjustment.
        
        # 1. Get current output
        var outputs = forward_pass(single_input)
        if outputs.is_empty(): continue

        # 2. Calculate error for the output layer
        var errors = PackedFloat32Array()
        errors.resize(outputs.size())
        for j in range(outputs.size()):
            errors[j] = single_target[j] - outputs[j] # Simple error

        # 3. Update weights and biases for the output layer only
        if weights.size() > 0 and biases.size() > 0:
            var output_layer_idx = weights.size() - 1 # Index of the last set of weights/biases

            # Get inputs to the output layer (activations of the previous hidden layer)
            var inputs_to_output_layer = PackedFloat32Array()
            if output_layer_idx == 0: # If only one layer of weights (input -> output)
                inputs_to_output_layer = single_input
            else:
                # Need to get activations of the layer before the output layer
                # This requires a partial forward pass or storing intermediate activations.
                # For this simplified version, let's assume we can get them.
                # This is a major simplification point.
                var temp_values = single_input.duplicate()
                for lyr_idx in range(output_layer_idx):
                    var lyr_w = weights[lyr_idx]
                    var lyr_b: PackedFloat32Array = biases[lyr_idx]
                    var act_type = layers_config[lyr_idx + 1].activation
                    var next_vals = PackedFloat32Array()
                    next_vals.resize(layers_config[lyr_idx+1].size)
                    for nrn_idx in range(lyr_w.size()):
                        var nrn_wts: PackedFloat32Array = lyr_w[nrn_idx]
                        var dp: float = 0.0
                        for in_idx in range(temp_values.size()):
                            dp += temp_values[in_idx] * nrn_wts[in_idx]
                        dp += lyr_b[nrn_idx]
                        next_vals[nrn_idx] = apply_activation(dp, act_type)
                    temp_values = next_vals
                inputs_to_output_layer = temp_values


            var output_layer_weights: Array = weights[output_layer_idx] # Array of PackedFloat32Arrays
            var output_layer_biases: PackedFloat32Array = biases[output_layer_idx]

            for neuron_j in range(output_layer_weights.size()): # For each output neuron
                var error_j = errors[neuron_j]
                # Derivative of sigmoid (if output is sigmoid): output_j * (1 - output_j)
                # Derivative of linear: 1
                # Derivative of ReLU: 1 if output > 0, else 0
                # Let's assume a generic gradient factor for simplicity here, or use activation derivative
                var activation_derivative = 1.0 # Placeholder
                if layers_config[output_layer_idx + 1].activation == "sigmoid":
                    activation_derivative = outputs[neuron_j] * (1.0 - outputs[neuron_j])
                elif layers_config[output_layer_idx + 1].activation == "relu":
                    activation_derivative = 1.0 if outputs[neuron_j] > 0 else 0.0
                
                var delta_j = error_j * activation_derivative # Error term for output neuron j

                # Update weights connecting to neuron_j
                var neuron_j_weights: PackedFloat32Array = output_layer_weights[neuron_j]
                for k in range(neuron_j_weights.size()): # For each weight w_kj
                    var input_k_val = inputs_to_output_layer[k] if k < inputs_to_output_layer.size() else 0.0
                    neuron_j_weights[k] += learning_rate * delta_j * input_k_val
                
                # Update bias for neuron_j
                output_layer_biases[neuron_j] += learning_rate * delta_j


func mutate_weights(mutation_rate: float, mutation_strength: float = 0.1):
    for layer_w_list in weights: # layer_w_list is an array of PackedFloat32Array (neuron weights)
        for neuron_weights_packed_array in layer_w_list: # neuron_weights_packed_array is PackedFloat32Array
            for i in range(neuron_weights_packed_array.size()):
                if randf() < mutation_rate:
                    neuron_weights_packed_array[i] += randf_range(-mutation_strength, mutation_strength)
    
    for layer_b_packed_array in biases: # layer_b_packed_array is PackedFloat32Array
        for i in range(layer_b_packed_array.size()):
            if randf() < mutation_rate:
                layer_b_packed_array[i] += randf_range(-mutation_strength, mutation_strength)

func clone() -> NeuralNetwork:
    var new_nn = NeuralNetwork.new()
    new_nn.layers_config = layers_config.duplicate(true) # Deep copy
    
    for layer_w_list in weights:
        var new_layer_w_list = []
        for neuron_w_packed in layer_w_list:
            new_layer_w_list.append(neuron_w_packed.duplicate())
        new_nn.weights.append(new_layer_w_list)
        
    for layer_b_packed in biases:
        new_nn.biases.append(layer_b_packed.duplicate())
        
    return new_nn

func save_to_dictionary() -> Dictionary:
    # Convert PackedFloat32Arrays to regular Arrays for JSON serialization if needed,
    # or ensure JSON stringify handles them. Godot's JSON might handle them.
    var serializable_weights = []
    for layer_w_list in weights:
        var s_layer_w = []
        for neuron_w_packed in layer_w_list:
            s_layer_w.append(Array(neuron_w_packed)) # Convert to Array
        serializable_weights.append(s_layer_w)

    var serializable_biases = []
    for layer_b_packed in biases:
        serializable_biases.append(Array(layer_b_packed)) # Convert to Array

    return {
        "layers_config": layers_config,
        "weights": serializable_weights,
        "biases": serializable_biases
    }

func load_from_dictionary(data: Dictionary):
    layers_config = data.get("layers_config", [])
    
    var loaded_weights_raw = data.get("weights", [])
    weights.clear()
    for s_layer_w_list in loaded_weights_raw:
        var new_layer_w = []
        for s_neuron_w_array in s_layer_w_list:
            new_layer_w.append(PackedFloat32Array(s_neuron_w_array)) # Convert back
        weights.append(new_layer_w)

    var loaded_biases_raw = data.get("biases", [])
    biases.clear()
    for s_layer_b_array in loaded_biases_raw:
        biases.append(PackedFloat32Array(s_layer_b_array)) # Convert back
    
    # If layers_config is present but weights/biases are empty (e.g. new model structure)
    # and you want to initialize, you could call initialize_network() here.
    # However, typically load_from_dictionary implies loading trained weights.
    if layers_config and (weights.is_empty() or biases.is_empty()) and not (loaded_weights_raw or loaded_biases_raw) :
        printerr("NN: Loaded layer config but no weights/biases found in data. Reinitializing.")
        initialize_network()


# Example: Save to file (using the dictionary methods)
func save_to_file(path: String):
    var data_dict = save_to_dictionary()
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        printerr("Failed to open file for saving NN: %s" % path)
        return
    file.store_string(JSON.stringify(data_dict, "\t")) # Use pretty print for readability
    file.close()

# Example: Load from file
func load_from_file(path: String):
    if not FileAccess.file_exists(path):
        printerr("NN file not found: %s" % path)
        return

    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        printerr("Failed to open file for loading NN: %s" % path)
        return
        
    var json_string = file.get_as_text()
    file.close()
    
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        printerr("Failed to parse NN JSON from %s. Error: %s, Line: %s" % [path, json.get_error_message(), json.get_error_line()])
        return
    
    load_from_dictionary(json.data)