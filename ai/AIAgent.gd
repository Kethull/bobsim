# AIAgent.gd
extends Node
class_name AIAgent

@export var use_external_ai: bool = true  # Use Python RL server vs built-in
@export var ai_server_url: String = "http://localhost:8000"
@export var update_frequency: float = 0.1  # AI decisions per second

@onready var q_learning: SimpleQLearning = SimpleQLearning.new()

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
    # Setup HTTP client for external AI
    if use_external_ai:
        http_request = HTTPRequest.new()
        add_child(http_request)
        http_request.request_completed.connect(_on_ai_response_received)
        http_request.timeout = 1.0  # 1 second timeout
    
    # Setup fallback Q-learning
    # q_learning is now initialized with @onready
    q_learning.action_space_size = 5  # Number of discrete actions
    add_child(q_learning)

func initialize(probe: Probe):
    parent_probe = probe
    episode_step = 0
    
    # Connect to probe signals for reward calculation
    probe.resource_discovered.connect(_on_resource_discovered)
    probe.energy_critical.connect(_on_energy_critical)

func update_step(delta: float):
    if not parent_probe or not parent_probe.is_alive:
        return
    
    action_timer += delta
    
    # Request new action at specified frequency
    if action_timer >= update_frequency:
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
        print("Failed to send AI request: ", error)
        # Fallback to built-in AI
        request_builtin_action()

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
    # Use simple Q-learning as fallback
    var state_hash = hash_observation(current_observation)
    var action_index = q_learning.get_action(state_hash)
    
    # Convert single action index to multi-dimensional action
    current_action = decode_action_index(action_index)
    apply_action(current_action)
    
    # Update Q-learning with previous experience
    if not last_state_hash.is_empty():
        var reward = calculate_reward()
        q_learning.update_q_value(last_state_hash, action_index, reward, state_hash)
        last_reward = reward
    
    last_state_hash = state_hash

func hash_observation(obs: Dictionary) -> String:
    # Create simple state hash for Q-learning
    var pos_hash = str(int(obs.position.x / 100)) + "," + str(int(obs.position.y / 100))
    var energy_hash = str(int(obs.energy_ratio * 10))
    var resource_hash = ""
    
    if obs.has("nearby_resources") and obs.nearby_resources.size() > 0:
        var closest = obs.nearby_resources[0]
        resource_hash = str(int(closest.distance / 50))
    
    return pos_hash + "_" + energy_hash + "_" + resource_hash

func decode_action_index(index: int) -> Array:
    # Convert single action index to multi-dimensional action array
    # This is a simplified mapping - real implementation would be more sophisticated
    match index:
        0: return [0, 0, 0, 0, 0]  # No action
        1: return [1, 0, 0, 0, 0]  # Thrust forward
        2: return [0, 1, 0, 0, 0]  # Rotate left
        3: return [0, 2, 0, 0, 0]  # Rotate right
        4: return [0, 0, 0, 0, 1]  # Target closest resource
        _: return [0, 0, 0, 0, 0]

func _on_ai_response_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
    if response_code == 200:
        var json = JSON.new()
        var parse_result = json.parse(body.get_string_from_utf8())
        
        if parse_result == OK and json.data.has("action"):
            current_action = json.data.action
            apply_action(current_action)
            action_received.emit(current_action)
        else:
            print("Failed to parse AI response")
            request_builtin_action()  # Fallback
    else:
        print("AI server error: ", response_code)
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