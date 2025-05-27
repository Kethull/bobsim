extends Node
class_name SimpleQLearning

# Simple Q-Learning implementation for fallback

var q_table: Dictionary = {}
var learning_rate: float = 0.1
var discount_factor: float = 0.95
var epsilon: float = 0.1
var epsilon_decay: float = 0.995
var min_epsilon: float = 0.01
var action_space_size: int = 5

func _ready():
	# Decay epsilon over time
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_decay_epsilon)
	add_child(timer)
	timer.start()

func _decay_epsilon():
	epsilon = max(min_epsilon, epsilon * epsilon_decay)

func get_action(state: String) -> int:
	if randf() < epsilon:
		return randi() % action_space_size  # Explore
	else:
		return get_best_action(state)  # Exploit

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

func get_max_q_value(state: String) -> float:
	if not q_table.has(state):
		initialize_state(state)
	
	var max_value = q_table[state][0]
	for i in range(1, action_space_size):
		max_value = max(max_value, q_table[state][i])
	
	return max_value

func update_q_value(state: String, action: int, reward: float, next_state: String):
	if not q_table.has(state):
		initialize_state(state)
	
	var current_q = q_table[state][action]
	var max_next_q = get_max_q_value(next_state)
	var new_q = current_q + learning_rate * (reward + discount_factor * max_next_q - current_q)
	q_table[state][action] = new_q

func initialize_state(state: String):
	q_table[state] = []
	for i in range(action_space_size):
		q_table[state].append(0.0)
