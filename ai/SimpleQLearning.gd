extends Node
class_name SimpleQLearning

# Enhanced Q-Learning implementation for Probe AI

# Q-Table and learning parameters
var q_table: Dictionary = {}
var learning_rate: float = 0.1       # Controls how quickly model adapts to new info
var discount_factor: float = 0.99    # Value future rewards highly
var epsilon: float = 1.0             # Initial exploration rate (start fully exploring)
var epsilon_decay: float = 0.001     # Gradual shift to exploitation
var min_epsilon: float = 0.01        # Maintain minimal exploration
var action_space_size: int = 20      # Expanded action space for more probe controls

# Metrics and debugging
var total_updates: int = 0           # Count of Q-value updates
var total_explorations: int = 0      # Count of random actions (exploration)
var total_exploitations: int = 0     # Count of best actions (exploitation)
var states_discovered: int = 0       # Number of unique states discovered
var episode_steps: int = 0           # Steps in current episode
var episode_rewards: float = 0.0     # Total rewards in current episode
var episode_count: int = 0           # Count of episodes completed

# State tracking
var _config = null                   # Will hold GameConfiguration reference
var _debug_enabled: bool = true      # For detailed logging

func _ready():
	# Get config reference
	_config = ConfigManager.config
	
	# Apply configuration values
	learning_rate = _config.learning_rate if _config.learning_rate > 0 else learning_rate
	discount_factor = 0.99  # Value future rewards highly as specified
	epsilon = 1.0  # Start with full exploration
	epsilon_decay = 0.001  # Gradual shift to exploitation
	min_epsilon = 0.01  # Maintain minimal exploration
	_debug_enabled = _config.ai_debug_logging
	
	# Set up epsilon decay timer (decay happens at regular intervals)
	var timer = Timer.new()
	timer.wait_time = 5.0  # Decay every 5 seconds to allow enough exploration
	timer.timeout.connect(_decay_epsilon)
	add_child(timer)
	timer.start()
	
	# Try to load existing Q-table if enabled
	if _config.q_learning_load_on_episode_start:
		load_q_table()
		
	if _debug_enabled:
		print("SimpleQLearning: Initialized with learning_rate=", learning_rate,
			  ", discount_factor=", discount_factor,
			  ", epsilon=", epsilon)
		print("SimpleQLearning: Action space size = ", action_space_size)

# Decay epsilon according to the schedule (called by timer)
func _decay_epsilon():
	var old_epsilon = epsilon
	epsilon = max(min_epsilon, epsilon - epsilon_decay)
	
	if _debug_enabled and abs(old_epsilon - epsilon) > 0.01:
		print("SimpleQLearning: Epsilon decayed from ", old_epsilon, " to ", epsilon)
		print("SimpleQLearning: Exploration/Exploitation ratio: ",
			  total_explorations, "/", total_exploitations,
			  " (", (float(total_explorations) / max(1, total_explorations + total_exploitations)) * 100.0, "%)")

# Get an action using epsilon-greedy strategy
func get_action(state: String) -> int:
	# Implement epsilon-greedy exploration
	if randf() < epsilon:
		# Explore: Choose a random action
		var action = randi() % action_space_size
		total_explorations += 1
		return action
	else:
		# Exploit: Choose the best action
		total_exploitations += 1
		return get_best_action(state)

# Get the best action for a given state
func get_best_action(state: String) -> int:
	if not q_table.has(state):
		initialize_state(state)
	
	var best_action = 0
	var best_value = q_table[state][0]
	
	for i in range(1, action_space_size):
		if q_table[state][i] > best_value:
			best_value = q_table[state][i]
			best_action = i
	
	return best_action

# Get the maximum Q-value for a state
func get_max_q_value(state: String) -> float:
	if not q_table.has(state):
		initialize_state(state)
	
	var max_value = q_table[state][0]
	for i in range(1, action_space_size):
		max_value = max(max_value, q_table[state][i])
	
	return max_value

# Update Q-value using the Q-learning update rule
func update_q_value(state: String, action: int, reward: float, next_state: String):
	if not q_table.has(state):
		initialize_state(state)
	
	var current_q = q_table[state][action]
	var max_next_q = get_max_q_value(next_state)
	
	# Q-learning update formula: Q(s,a) = Q(s,a) + α * (r + γ * max(Q(s',a')) - Q(s,a))
	var new_q = current_q + learning_rate * (reward + discount_factor * max_next_q - current_q)
	q_table[state][action] = new_q
	
	# Update metrics
	total_updates += 1
	episode_rewards += reward
	episode_steps += 1
	
	if _debug_enabled and total_updates % 100 == 0:
		print("SimpleQLearning: Q-table size: ", q_table.size(), " states, ",
			  "Updates: ", total_updates,
			  ", Avg reward: ", episode_rewards / max(1, episode_steps))

# Initialize a new state in the Q-table
func initialize_state(state: String):
	q_table[state] = []
	for i in range(action_space_size):
		q_table[state].append(0.0)
	
	states_discovered += 1
	if _debug_enabled and states_discovered % 10 == 0:
		print("SimpleQLearning: Discovered state #", states_discovered, ": ", state)

# Load Q-table from disk
func load_q_table() -> bool:
	var filename = _config.q_learning_table_filename
	if filename.is_empty():
		return false
	
	var file = FileAccess.open(filename, FileAccess.READ)
	if not file:
		if _debug_enabled:
			print("SimpleQLearning: Could not load Q-table from ", filename)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json_result = JSON.parse_string(json_string)
	if json_result == null:
		if _debug_enabled:
			print("SimpleQLearning: Failed to parse Q-table JSON")
		return false
	
	# Load the Q-table
	q_table = json_result.q_table
	
	# Load metrics if available
	if json_result.has("metrics"):
		total_updates = json_result.metrics.total_updates
		total_explorations = json_result.metrics.total_explorations
		total_exploitations = json_result.metrics.total_exploitations
		states_discovered = json_result.metrics.states_discovered
		episode_count = json_result.metrics.episode_count
	
	if _debug_enabled:
		print("SimpleQLearning: Loaded Q-table with ", q_table.size(), " states from ", filename)
	
	return true

# Save Q-table to disk
func save_q_table() -> bool:
	var filename = _config.q_learning_table_filename
	if filename.is_empty():
		return false
	
	var save_data = {
		"q_table": q_table,
		"metrics": {
			"total_updates": total_updates,
			"total_explorations": total_explorations,
			"total_exploitations": total_exploitations,
			"states_discovered": states_discovered,
			"episode_count": episode_count,
			"epsilon": epsilon
		}
	}
	
	var json_string = JSON.stringify(save_data)
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if not file:
		if _debug_enabled:
			print("SimpleQLearning: Could not save Q-table to ", filename)
		return false
	
	file.store_string(json_string)
	file.close()
	
	if _debug_enabled:
		print("SimpleQLearning: Saved Q-table with ", q_table.size(), " states to ", filename)
	
	return true

# Start a new episode - reset episode-specific counters
func start_episode():
	episode_steps = 0
	episode_rewards = 0.0
	if _debug_enabled:
		print("SimpleQLearning: Starting episode #", episode_count + 1)

# End current episode and save Q-table if configured
func end_episode():
	episode_count += 1
	
	if _debug_enabled:
		print("SimpleQLearning: Episode #", episode_count, " completed")
		print("SimpleQLearning: Steps: ", episode_steps, ", Total reward: ", episode_rewards)
		print("SimpleQLearning: Q-table size: ", q_table.size(), " states")
		print("SimpleQLearning: Current epsilon: ", epsilon)
	
	# Save Q-table if configured
	if _config.q_learning_save_on_episode_end:
		save_q_table()

# Get debug statistics as a dictionary
func get_debug_stats() -> Dictionary:
	return {
		"q_table_size": q_table.size(),
		"unique_states": states_discovered,
		"updates": total_updates,
		"explorations": total_explorations,
		"exploitations": total_exploitations,
		"epsilon": epsilon,
		"episodes": episode_count,
		"episode_steps": episode_steps,
		"episode_rewards": episode_rewards
	}

# Decode an action index into its components
func decode_action(action_idx: int) -> Dictionary:
	# More sophisticated action space decoding
	# This helps with debugging by translating numeric actions to meaningful components
	
	var thrust_levels = [0, 1, 2, 3]  # 0=none, 1-3=increasing power
	var rotation_levels = [0, -1, -2, 1, 2]  # 0=none, negative=left, positive=right
	
	# Calculate components using integer division and modulo operations
	var thrust_idx = action_idx % 4
	var rotation_idx = (action_idx / 4) % 5
	var communicate = (action_idx / 20) % 2
	var replicate = (action_idx / 40) % 2
	var target = (action_idx / 80) % 3
	
	return {
		"thrust": thrust_levels[thrust_idx],
		"rotation": rotation_levels[rotation_idx],
		"communicate": communicate > 0,
		"replicate": replicate > 0,
		"target": target
	}
