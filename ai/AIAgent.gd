# AIAgent.gd
extends Node
class_name AIAgent

# Use configuration values instead of hardcoded exports
var use_external_ai: bool = false  # Will be set from GameConfiguration
var ai_server_url: String = "http://localhost:8000"
var update_frequency: float = 0.1  # AI decisions per second

# Request state management
var is_http_request_pending: bool = false
var pending_request_timer: float = 0.0

@onready var q_learning: SimpleQLearning = SimpleQLearning.new()
@onready var config = ConfigManager.config
@onready var debug_visualizer: AIDebugVisualizer

var parent_probe: Probe
var http_request: HTTPRequest
var current_observation: Dictionary
var current_action: Array = [0, 0, 0, 0, 0]  # [thrust, torque, communicate, replicate, target]
var last_reward: float = 0.0
var episode_step: int = 0
var current_rotation_direction: int = 0  # -1, 0, 1 for left, none, right

# Built-in simple RL for fallback
var last_state_hash: String = ""

# Action smoothing
var action_timer: float = 0.0
var pending_action: bool = false

signal action_received(action: Array)
signal reward_calculated(reward: float)

func _ready():
	# Load configuration values
	use_external_ai = config.use_external_ai
	update_frequency = config.ai_update_interval_sec
	
	# Setup HTTP client for external AI
	if use_external_ai:
		http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.request_completed.connect(_on_ai_response_received)
		http_request.timeout = config.ai_request_timeout
		
		if config.ai_debug_logging:
			print("AIAgent: External AI enabled with timeout: ", config.ai_request_timeout)
	
	# Setup enhanced Q-learning and debug visualizer
	setup_debug_visualizer()
	q_learning.action_space_size = 20  # Expanded action space to support more complex behaviors
	add_child(q_learning)
	
	# Initialize Q-learning with a new episode
	if not use_external_ai:
		q_learning.start_episode()
		if config.ai_debug_logging:
			print("AIAgent: Started new Q-learning episode")

func initialize(probe: Probe):
	parent_probe = probe
	episode_step = 0
	
	# Signal end of episode to Q-learning system when probe is destroyed
	probe.probe_destroyed.connect(_on_probe_destroyed)
	
	# Connect to probe signals for reward calculation
	probe.resource_discovered.connect(_on_resource_discovered)
	probe.energy_critical.connect(_on_energy_critical)
	
	# Initialize debug visualizer if it exists
	if debug_visualizer:
		debug_visualizer.initialize(self, probe)

func update_step(delta: float):
	if not parent_probe or not parent_probe.is_alive:
		return
	
	action_timer += delta
	
	# Handle timeout for pending HTTP requests
	if is_http_request_pending:
		pending_request_timer += delta
		if pending_request_timer >= config.ai_request_timeout:
			_handle_http_timeout()
	
	# Request new action at specified frequency, only if no request is pending
	if action_timer >= update_frequency and not is_http_request_pending:
		action_timer = 0.0
		request_action()

func request_action():
	current_observation = parent_probe.get_observation_data()
	episode_step += 1
	
	if use_external_ai and http_request:
		request_external_action()
	else:
		request_builtin_action()

func request_external_action():
	# Check if a request is already pending
	if is_http_request_pending:
		if config.ai_debug_logging:
			print("AIAgent: HTTP request already in progress, using built-in AI instead")
		request_builtin_action()
		return
	
	# Prepare observation data for external AI
	var observation_array = flatten_observation(current_observation)
	
	var request_data = {
		"observation": observation_array,
		"probe_id": parent_probe.probe_id,
		"episode_step": episode_step,
		"last_reward": last_reward
	}
	
	var json_string = JSON.stringify(request_data)
	var headers = ["Content-Type: application/json"]
	
	# Make async request to AI server
	var error = http_request.request(ai_server_url + "/predict", headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		if config.ai_debug_logging:
			print("AIAgent: Failed to send AI request: ", error)
		# Fallback to built-in AI
		request_builtin_action()
	else:
		# Set pending state and reset timer
		is_http_request_pending = true
		pending_request_timer = 0.0
		
		if config.ai_debug_logging:
			print("AIAgent: External AI request sent successfully")

func flatten_observation(obs: Dictionary) -> Array:
	# Convert complex observation dictionary to flat array for RL model
	var flat_obs = []
	
	# Probe state (7 values)
	flat_obs.append(obs.position.x / 10000.0)  # Normalized position
	flat_obs.append(obs.position.y / 10000.0)
	flat_obs.append(obs.velocity.x / 1000.0)   # Normalized velocity
	flat_obs.append(obs.velocity.y / 1000.0)
	flat_obs.append(obs.rotation / (2 * PI))   # Normalized rotation
	flat_obs.append(obs.angular_velocity / PI) # Normalized angular velocity
	flat_obs.append(obs.energy_ratio)          # Already normalized
	
	# Resource observations (3 resources × 4 values = 12 values)
	var resources = obs.get("nearby_resources", [])
	for i in range(3):  # Fixed number for consistent observation space
		if i < resources.size():
			var resource = resources[i]
			flat_obs.append(resource.position.x / 10000.0)
			flat_obs.append(resource.position.y / 10000.0)
			flat_obs.append(resource.distance / 1000.0)
			flat_obs.append(resource.amount / 20000.0)
		else:
			flat_obs.append_array([0.0, 0.0, 0.0, 0.0])  # Padding
	
	# Celestial bodies (2 bodies × 3 values = 6 values)
	var celestial_bodies = obs.get("nearby_celestial_bodies", [])
	for i in range(2):
		if i < celestial_bodies.size():
			var body = celestial_bodies[i]
			flat_obs.append(body.distance / 10000.0)
			flat_obs.append(body.gravity_influence * 1000.0)  # Scale up small values
			flat_obs.append(body.mass / 1e24)  # Normalize mass
		else:
			flat_obs.append_array([0.0, 0.0, 0.0])
	
	# Ensure exact size matches config
	while flat_obs.size() < ConfigManager.config.observation_space_size:
		flat_obs.append(0.0)
	flat_obs = flat_obs.slice(0, ConfigManager.config.observation_space_size)
	
	return flat_obs

func request_builtin_action():
	# Use enhanced Q-learning implementation
	var state_hash = hash_observation(current_observation)
	var action_index = q_learning.get_action(state_hash)
	
	# Convert single action index to multi-dimensional action using the expanded action space
	current_action = decode_action_index(action_index)
	apply_action(current_action)
	
	# Update Q-learning with previous experience
	if not last_state_hash.is_empty():
		var reward = calculate_reward()
		q_learning.update_q_value(last_state_hash, action_index, reward, state_hash)
		last_reward = reward
		
		# Log rewards at regular intervals if debug logging enabled
		if config.ai_debug_logging and episode_step % 100 == 0:
			var stats = q_learning.get_debug_stats()
			print("AIAgent: Step ", episode_step,
				  ", Reward: ", reward,
				  ", Epsilon: ", stats.epsilon,
				  ", Q-table size: ", stats.q_table_size)
		
		# Update debug visualizer with reward
		if debug_visualizer and debug_visualizer.enabled:
			debug_visualizer._on_reward_calculated(reward)
	
	last_state_hash = state_hash
	
	# Emit signal for any observers
	action_received.emit(current_action)
	reward_calculated.emit(last_reward)

func hash_observation(obs: Dictionary) -> String:
	# Create more detailed state hash for Q-learning
	# This improves state representation by capturing more relevant information
	
	# Position (discretized to grid)
	var pos_hash = str(int(obs.position.x / 100)) + "," + str(int(obs.position.y / 100))
	
	# Energy level (10 buckets)
	var energy_hash = str(int(obs.energy_ratio * 10))
	
	# Mining status
	var mining_hash = "M" if parent_probe and parent_probe.is_mining else "N"
	
	# Resource information
	var resource_hash = ""
	if obs.has("nearby_resources") and obs.nearby_resources.size() > 0:
		var closest = obs.nearby_resources[0]
		
		# Distance bucketed by 50 units
		var dist_bucket = int(closest.distance / 50)
		
		# Amount bucketed by 5000 units
		var amount_bucket = int(closest.amount / 5000)
		
		resource_hash = str(dist_bucket) + "_" + str(amount_bucket)
	else:
		resource_hash = "none"
	
	# Combine all components
	return pos_hash + "_" + energy_hash + "_" + mining_hash + "_" + resource_hash

func decode_action_index(index: int) -> Array:
	# Convert single action index to multi-dimensional action array
	# Using the expanded 20-action space from SimpleQLearning
	
	# Get detailed action breakdown from Q-learning
	var action_components = q_learning.decode_action(index)
	
	# Create action array:
	# [thrust_level, torque_level, communicate, replicate, target_resource]
	var action = [
		action_components.thrust,                # Thrust levels: 0-3
		abs(action_components.rotation) * (1 if action_components.rotation >= 0 else 2),  # Convert rotation to torque level
		1 if action_components.communicate else 0,  # Communication flag
		1 if action_components.replicate else 0,    # Replication flag
		action_components.target                    # Target selection
	]
	
	# Debug logging
	if config.ai_debug_logging and episode_step % 100 == 0:
		print("AIAgent: Action decoded: ", action, " from index ", index)
		print("AIAgent: Components: thrust=", action_components.thrust,
			  ", rotation=", action_components.rotation,
			  ", communicate=", action_components.communicate,
			  ", replicate=", action_components.replicate,
			  ", target=", action_components.target)
	
	# Update debug visualizer
	if debug_visualizer and debug_visualizer.enabled:
		var is_random = q_learning.total_explorations > q_learning.total_exploitations * 0.8
		debug_visualizer.update_action_display(index, action, is_random)
	
	return action

func _on_ai_response_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	# Reset pending state
	is_http_request_pending = false
	pending_request_timer = 0.0
	
	if response_code == 200:
		var json_string = body.get_string_from_utf8()
		
		# Use Godot 4's JSON parsing with improved error handling
		var json_result = JSON.parse_string(json_string)
		
		if json_result == null:
			if config.ai_debug_logging:
				push_error("AIAgent: AI response JSON parsing failed: Invalid JSON format")
			request_builtin_action()  # Fallback
			return
			
		if not json_result is Dictionary:
			if config.ai_debug_logging:
				push_error("AIAgent: AI response JSON parsing failed: Result is not a Dictionary")
			request_builtin_action()  # Fallback
			return
			
		if not json_result.has("action"):
			if config.ai_debug_logging:
				push_error("AIAgent: AI response JSON parsing failed: Missing 'action' field")
			request_builtin_action()  # Fallback
			return
			
		# Successfully parsed response
		current_action = json_result.action
		apply_action(current_action)
		action_received.emit(current_action)
		
		if config.ai_debug_logging:
			print("AIAgent: Successfully received and applied action from external AI")
	else:
		if config.ai_debug_logging:
			push_error("AIAgent: AI server error: " + str(response_code))
		request_builtin_action()  # Fallback

func apply_action(action: Array):
	if not parent_probe or not parent_probe.is_alive:
		return
	
	# action = [thrust_level, torque_level, communicate, replicate, target_resource]
	
	# Apply thrust action
	var thrust_level = action[0] if action.size() > 0 else 0
	if thrust_level > 0 and thrust_level < ConfigManager.config.thrust_force_magnitudes.size():
		parent_probe.current_thrust_level = thrust_level
		parent_probe.is_thrusting = true
	else:
		parent_probe.current_thrust_level = 0
		parent_probe.is_thrusting = false
	
	# Apply rotation action
	var torque_level = action[1] if action.size() > 1 else 0
	if torque_level > 0 and torque_level < ConfigManager.config.torque_magnitudes.size():
		parent_probe.current_torque_level = torque_level
		current_rotation_direction = 1 if torque_level % 2 == 1 else -1  # Odd = right, even = left
	else:
		parent_probe.current_torque_level = 0
		current_rotation_direction = 0
	
	# Apply communication action
	var communicate = action[2] if action.size() > 2 else 0
	if communicate > 0:
		# Find nearest probe and send communication
		var nearby_probes = current_observation.get("nearby_probes", [])
		if nearby_probes.size() > 0:
			var target_probe = nearby_probes[0]
			parent_probe.send_communication(target_probe.position, "resource_location")
	
	# Apply replication action
	var replicate = action[3] if action.size() > 3 else 0
	if replicate > 0:
		parent_probe.attempt_replication()
	
	# Apply targeting action
	var target_action = action[4] if action.size() > 4 else 0
	if target_action > 0:
		var nearby_resources = current_observation.get("nearby_resources", [])
		var target_index = (target_action - 1) % max(1, nearby_resources.size())
		if target_index < nearby_resources.size():
			parent_probe.current_target_id = target_index
			parent_probe.target_resource_idx = target_index

func calculate_reward() -> float:
	if not parent_probe:
		return 0.0
	
	var reward = 0.0
	var config_rewards = ConfigManager.config.reward_factors
	
	# Stay alive bonus
	if parent_probe.is_alive:
		reward += config_rewards.get("stay_alive", 0.02)
	
	# Energy level rewards/penalties
	var energy_ratio = parent_probe.current_energy / parent_probe.max_energy
	if energy_ratio > 0.75:
		reward += config_rewards.get("high_energy", 0.1)
	elif energy_ratio < 0.25:
		reward -= 0.1  # Low energy penalty
	elif energy_ratio < 0.1:
		reward -= 0.3  # Critical energy penalty
	
	# Mining reward
	if parent_probe.is_mining:
		reward += config_rewards.get("mining", 0.05)
	
	# Proximity to target resource reward
	if parent_probe.target_resource_idx >= 0:
		var nearby_resources = current_observation.get("nearby_resources", [])
		if parent_probe.target_resource_idx < nearby_resources.size():
			var target_resource = nearby_resources[parent_probe.target_resource_idx]
			var distance = target_resource.distance
			var proximity_reward = config_rewards.get("proximity", 1.95) * exp(-distance / 100.0)
			reward += proximity_reward
	
	# Efficiency penalties
	if parent_probe.is_thrusting and parent_probe.current_thrust_level > 0:
		# Small penalty for fuel consumption
		reward -= 0.001 * parent_probe.current_thrust_level
	
	return reward

func _on_resource_discovered(probe: Probe, resource_position: Vector2, amount: float):
	# Bonus reward for discovering new resources
	last_reward += 0.5 * (amount / 20000.0)  # Scale by resource size

func _on_energy_critical(probe: Probe, energy_level: float):
	# Penalty for reaching critical energy
	last_reward -= 0.2

# Simple Q-Learning implementation for fallback is now in ai/SimpleQLearning.gd

# Handle timeout for pending HTTP requests
func _handle_http_timeout():
	if is_http_request_pending:
		if config.ai_debug_logging:
			print("AIAgent: HTTP request timed out after ", config.ai_request_timeout, " seconds")
		
		# Reset the pending state
		is_http_request_pending = false
		pending_request_timer = 0.0
		
		# Fallback to built-in AI
		request_builtin_action()
		
		# If we still have an active request, cancel it
		if http_request and http_request.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
			http_request.cancel_request()

# Handle episode end when probe is destroyed
func _on_probe_destroyed(probe: Probe):
	if not use_external_ai and q_learning:
		q_learning.end_episode()
		if config.ai_debug_logging:
			print("AIAgent: Ended Q-learning episode due to probe destruction")
			
			# Print final statistics
			var stats = q_learning.get_debug_stats()
			print("AIAgent: Episode stats - Steps: ", stats.episode_steps,
				  ", Total reward: ", stats.episode_rewards,
				  ", Q-table size: ", stats.q_table_size)

# Create and setup the debug visualizer
func setup_debug_visualizer():
	if config.ai_show_debug_visuals:
		debug_visualizer = AIDebugVisualizer.new()
		add_child(debug_visualizer)
		
		# Connect signals
		debug_visualizer.ai_debug_log.connect(_on_debug_log)
		debug_visualizer.request_camera_focus.connect(_on_request_camera_focus)
		debug_visualizer.toggle_hud_visibility.connect(_on_toggle_hud_visibility)
		
		if config.ai_debug_logging:
			print("AIAgent: Debug visualizer created with enhanced features")

# Handle debug log messages
func _on_debug_log(message: String, level: String):
	if config.ai_debug_logging:
		# We could forward these to a central logging system
		# For now, they're already printed by the visualizer
		pass

# Toggle debug visualization
func toggle_debug_visualizer(enabled: bool):
	if debug_visualizer:
		debug_visualizer.set_debug_visibility(enabled)
		
		if config.ai_debug_logging:
			print("AIAgent: Debug visualizer " + ("enabled" if enabled else "disabled"))

# Handle camera focus requests from the debug visualizer
func _on_request_camera_focus(position: Vector2, zoom_level: float):
	# Find camera controller in the scene
	var camera_controller = _find_camera_controller()
	if camera_controller:
		# Set the camera to focus on this probe
		camera_controller.set_follow_target(parent_probe, true)
		camera_controller.set_zoom_level(zoom_level, true)
		
		if config.ai_debug_logging:
			print("AIAgent: Camera focus requested on probe with zoom level: ", zoom_level)

# Handle HUD visibility toggle
func _on_toggle_hud_visibility():
	# This could be extended to toggle other HUD elements in the game
	if config.ai_debug_logging:
		print("AIAgent: HUD visibility toggled")

# Helper to find the camera controller in the scene
func _find_camera_controller() -> CameraController:
	# Try to find camera controller at root level
	var camera_controllers = get_tree().get_nodes_in_group("camera_controllers")
	if camera_controllers.size() > 0:
		return camera_controllers[0]
	
	# Try to find by class name
	var nodes = get_tree().get_nodes_in_group("camera_controllers")
	for node in nodes:
		if node is CameraController:
			return node
	
	# If none found, look for it in the scene tree
	var root = get_tree().root
	for child in root.get_children():
		if child is CameraController:
			return child
		var potential = _find_camera_controller_recursive(child)
		if potential:
			return potential
	
	if config.ai_debug_logging:
		print("AIAgent: Could not find camera controller in scene")
	return null

# Recursive helper to find camera controller
func _find_camera_controller_recursive(node: Node) -> CameraController:
	if node is CameraController:
		return node
	
	for child in node.get_children():
		var result = _find_camera_controller_recursive(child)
		if result:
			return result
	
	return null
