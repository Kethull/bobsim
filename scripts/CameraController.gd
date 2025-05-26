# CameraController.gd
class_name CameraController
extends Node

## Emitted when the actively followed target changes.
signal follow_target_changed(new_target: Node2D)

## Exports
@export var camera_node: Camera2D:
	set(value):
		camera_node = value
		if camera_node and Engine.is_editor_hint():
			pass # Editor-specific updates if needed
		elif camera_node:
			# Initial setup when game runs and camera_node is assigned
			_current_target_zoom_value = camera_node.zoom
			if not is_instance_valid(_current_follow_target):
				_target_destination_position = camera_node.global_position
			# Ensure input processing is enabled if camera is set
			set_process_unhandled_input(true)
			set_process(true)


@export_group("Following")
@export var follow_speed: float = 5.0 # Speed for lerping to target position
@export var target_switch_speed: float = 4.0 # Speed for interpolating camera position when switching targets

@export_group("Zoom")
@export var min_zoom_level: float = 0.25
@export var max_zoom_level: float = 4.0
@export var zoom_speed: float = 6.0 # Speed for lerping zoom value
@export var zoom_increment_wheel: float = 0.1 # Amount to change zoom per mouse wheel step
@export var zoom_increment_keys: float = 0.2 # Amount to change zoom per key press (for zoom_in/zoom_out actions)

@export_group("Shake")
@export var default_shake_duration: float = 0.25
@export var default_shake_strength: float = 15.0

## Private Variables
# Target
var _current_follow_target: Node2D = null
var _target_destination_position: Vector2 = Vector2.ZERO # The position camera ultimately wants to reach
var _is_switching_target: bool = false # True if camera is currently interpolating to a new target's view
var _previous_target_position_on_switch: Vector2 = Vector2.ZERO # Camera's global_position when a switch started
var _switch_interpolation_alpha: float = 0.0 # Interpolation factor (0 to 1) for target switching

# Probe List (for focus_next_probe, focus_previous_probe style cycling)
var _known_targets: Array[Node2D] = []
var _current_target_list_index: int = -1 # Index in _known_targets for current cycle selection

# Zoom
var _current_target_zoom_value: Vector2 = Vector2.ONE # The zoom value camera wants to reach

# Shake
var _shake_active: bool = false
var _shake_timer: float = 0.0
var _shake_current_strength: float = 0.0
var _shake_rng := RandomNumberGenerator.new()

const DEFAULT_CAMERA_POSITION: Vector2 = Vector2.ZERO


func _ready() -> void:
	if not is_instance_valid(camera_node):
		printerr("CameraController: Camera2D node not assigned in _ready! Disabling controller.")
		set_process_unhandled_input(false)
		set_process(false)
		return

	_target_destination_position = camera_node.global_position
	_current_target_zoom_value = camera_node.zoom
	_shake_rng.randomize()

	# Ensure input actions for zoom keys exist (user can map them in Project Settings)
	if not InputMap.has_action("zoom_in"):
		InputMap.add_action("zoom_in")
		# Example: InputMap.action_add_event("zoom_in", InputEventKey.new(KEY_PLUS))
	if not InputMap.has_action("zoom_out"):
		InputMap.add_action("zoom_out")
		# Example: InputMap.action_add_event("zoom_out", InputEventKey.new(KEY_MINUS))
	# "focus_next_probe" is assumed to be defined by the user.


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(camera_node):
		return

	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_zoom(-zoom_increment_wheel)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_zoom(zoom_increment_wheel)
				get_viewport().set_input_as_handled()

	# Zoom with keys
	if event.is_action_pressed("zoom_in"):
		_adjust_zoom(-zoom_increment_keys)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		_adjust_zoom(zoom_increment_keys)
		get_viewport().set_input_as_handled()

	# Switch target using "focus_next_probe"
	if event.is_action_pressed("focus_next_probe"):
		focus_next_known_target()
		get_viewport().set_input_as_handled()
	# Example for previous:
	# if event.is_action_pressed("focus_previous_probe"):
	# 	focus_previous_known_target()
	# 	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(camera_node):
		return

	# --- 1. Handle Target Invalidation ---
	if _current_follow_target != null and not is_instance_valid(_current_follow_target):
		var invalidated_target_name = "UNKNOWN"
		if _current_follow_target.has_method("get_name"): invalidated_target_name = _current_follow_target.name
		printerr("CameraController: Follow target '%s' became invalid." % invalidated_target_name)
		
		var invalidated_target_ref = _current_follow_target
		_current_follow_target = null # Stop trying to follow it
		_is_switching_target = false   # Cancel any ongoing switch to it

		# If it was in our known list, remove it
		var index_in_known_list = _known_targets.find(invalidated_target_ref)
		if index_in_known_list != -1:
			_known_targets.remove_at(index_in_known_list)
			# Adjust _current_target_list_index if it pointed to or after the removed item
			if _known_targets.is_empty():
				_current_target_list_index = -1
			elif index_in_known_list <= _current_target_list_index:
				_current_target_list_index = max(0, _current_target_list_index - 1)
				if _known_targets.is_empty(): _current_target_list_index = -1 # Safety for empty list

		# Attempt to switch to another known target if available
		if not _known_targets.is_empty():
			focus_next_known_target(true) # true to force re-evaluation
		
		# If still no valid target after attempts (focus_next_known_target might set one)
		if not is_instance_valid(_current_follow_target):
			_target_destination_position = camera_node.global_position # Become static at current view

	# --- 2. Determine Camera's Destination Position for this Frame ---
	var current_frame_target_position: Vector2
	if _is_switching_target:
		_switch_interpolation_alpha = clampf(_switch_interpolation_alpha + delta * target_switch_speed, 0.0, 1.0)
		
		var switch_destination_pos: Vector2
		if is_instance_valid(_current_follow_target):
			switch_destination_pos = _current_follow_target.global_position
		else: # Switching to a null target (i.e., becoming static)
			switch_destination_pos = _previous_target_position_on_switch # Aim to stop where the switch began
		
		current_frame_target_position = _previous_target_position_on_switch.lerp(switch_destination_pos, _switch_interpolation_alpha)
		
		if _switch_interpolation_alpha >= 1.0:
			_is_switching_target = false
			_target_destination_position = current_frame_target_position # Lock in the final position of the switch
	elif is_instance_valid(_current_follow_target):
		# Regular following, not in a switch-transition
		_target_destination_position = _current_follow_target.global_position
		current_frame_target_position = _target_destination_position
	else:
		# No target and not switching (static camera).
		# _target_destination_position holds the static position.
		current_frame_target_position = _target_destination_position

	# --- 3. Smoothly Move Camera Position ---
	camera_node.global_position = camera_node.global_position.lerp(current_frame_target_position, delta * follow_speed)

	# --- 4. Smoothly Adjust Zoom ---
	camera_node.zoom = camera_node.zoom.lerp(_current_target_zoom_value, delta * zoom_speed)

	# --- 5. Apply Shake ---
	if _shake_active:
		_shake_timer -= delta
		if _shake_timer <= 0:
			_shake_active = false
			camera_node.offset = Vector2.ZERO # Reset offset
		else:
			var offset_x = _shake_rng.randf_range(-_shake_current_strength, _shake_current_strength)
			var offset_y = _shake_rng.randf_range(-_shake_current_strength, _shake_current_strength)
			camera_node.offset = Vector2(offset_x, offset_y)
	elif camera_node.offset != Vector2.ZERO: # Ensure offset is reset if shake ended abruptly
		camera_node.offset = Vector2.ZERO


## Public API Methods
func set_follow_target(new_target: Node2D, smooth_transition: bool = true) -> void:
	"""
	Sets the camera's follow target.
	If smooth_transition is true, the camera will interpolate from its current
	view to the new target. Otherwise, it will attempt a more direct follow.
	Pass null to stop following and make the camera static.
	"""
	if not is_instance_valid(camera_node):
		printerr("CameraController: Camera not set, cannot set follow target.")
		return

	if new_target == _current_follow_target and is_instance_valid(new_target): # Check validity for new_target too
		return # Already following this valid target

	var old_target_ref = _current_follow_target # For signal
	
	if smooth_transition:
		_previous_target_position_on_switch = camera_node.global_position # Start transition from current camera view
		_current_follow_target = new_target # new_target can be null
		_is_switching_target = true
		_switch_interpolation_alpha = 0.0
		
		if not is_instance_valid(_current_follow_target): # If new_target is null (or invalid)
			# Aim to stop where the switch began, making camera static there.
			_target_destination_position = _previous_target_position_on_switch 
	else: # No smooth transition
		_current_follow_target = new_target
		_is_switching_target = false
		if is_instance_valid(_current_follow_target):
			_target_destination_position = _current_follow_target.global_position
			camera_node.global_position = _target_destination_position # Instant jump
		else: # New target is null or invalid, become static
			_target_destination_position = camera_node.global_position
			# camera_node.global_position = _target_destination_position # Already there if instant jump

	if old_target_ref != _current_follow_target:
		emit_signal("follow_target_changed", _current_follow_target)


func trigger_shake(duration: float = -1.0, strength: float = -1.0) -> void:
	"""Triggers a camera shake effect. Uses default values if parameters are negative."""
	if not is_instance_valid(camera_node):
		return
	_shake_active = true
	_shake_timer = default_shake_duration if duration < 0 else duration
	_shake_current_strength = default_shake_strength if strength < 0 else strength
	_shake_rng.randomize() # Ensure different shake pattern each time


func set_zoom_level(zoom_level: float, smooth: bool = true) -> void:
	"""Sets the camera zoom to a specific scalar value (e.g., 1.0 for normal)."""
	if not is_instance_valid(camera_node):
		return
	var new_zoom_scalar = clampf(zoom_level, min_zoom_level, max_zoom_level)
	_current_target_zoom_value = Vector2(new_zoom_scalar, new_zoom_scalar)
	if not smooth:
		camera_node.zoom = _current_target_zoom_value

## Known Target List Management (for cycling focus)
func add_known_target(target: Node2D) -> void:
	"""Adds a target to the list of known targets for cycling focus."""
	if is_instance_valid(target) and not _known_targets.has(target):
		_known_targets.append(target)
		if _current_target_list_index == -1: # If no target was selected from list, select this one
			_current_target_list_index = _known_targets.size() - 1
			# Optionally, auto-follow if not following anything:
			# if not is_instance_valid(_current_follow_target):
			#    set_follow_target(target, true)


func remove_known_target(target: Node2D) -> void:
	"""Removes a target from the list of known targets."""
	var index = _known_targets.find(target)
	if index != -1:
		_known_targets.remove_at(index)
		
		if _known_targets.is_empty():
			_current_target_list_index = -1
		elif index < _current_target_list_index:
			_current_target_list_index -= 1
		elif index == _current_target_list_index:
			# Index pointed to removed. Clamp to new list bounds.
			_current_target_list_index = min(_current_target_list_index, _known_targets.size() - 1)
			if _known_targets.is_empty(): _current_target_list_index = -1


		# If the removed target was the one being actively followed (not just selected in list)
		if _current_follow_target == target:
			_current_follow_target = null # Stop following it
			_is_switching_target = false
			if not _known_targets.is_empty():
				# Try to switch to the target now at _current_target_list_index (if valid) or cycle
				if _current_target_list_index != -1 and is_instance_valid(_known_targets[_current_target_list_index]):
					set_follow_target(_known_targets[_current_target_list_index], true)
				else:
					focus_next_known_target(true) # Cycle to find a new valid one
			else:
				# List is empty, no target to switch to. Camera becomes static.
				_target_destination_position = camera_node.global_position


func focus_next_known_target(force_switch: bool = false) -> void:
	"""Switches focus to the next target in the known list."""
	_clean_known_targets_list()

	if _known_targets.is_empty():
		# printerr("CameraController: No valid known targets to focus on.")
		if not is_instance_valid(_current_follow_target): # If not following anything valid
			set_follow_target(null, true) # Ensure it becomes static smoothly
		return

	var num_targets = _known_targets.size()
	if _current_target_list_index == -1: # No current selection or selection became invalid
		_current_target_list_index = 0
	else:
		_current_target_list_index = (_current_target_list_index + 1) % num_targets
	
	var new_target_node: Node2D = _known_targets[_current_target_list_index]

	if new_target_node != _current_follow_target or force_switch:
		set_follow_target(new_target_node, true)


func focus_previous_known_target(force_switch: bool = false) -> void:
	"""Switches focus to the previous target in the known list."""
	_clean_known_targets_list()

	if _known_targets.is_empty():
		# printerr("CameraController: No valid known targets to focus on.")
		if not is_instance_valid(_current_follow_target):
			set_follow_target(null, true)
		return

	var num_targets = _known_targets.size()
	if _current_target_list_index == -1:
		_current_target_list_index = num_targets - 1 # Start from the end
	else:
		_current_target_list_index -= 1
		if _current_target_list_index < 0:
			_current_target_list_index = num_targets - 1
	
	var new_target_node: Node2D = _known_targets[_current_target_list_index]

	if new_target_node != _current_follow_target or force_switch:
		set_follow_target(new_target_node, true)

## Private Helper Methods
func _adjust_zoom(amount: float) -> void:
	if not is_instance_valid(camera_node):
		return
	var current_zoom_scalar = _current_target_zoom_value.x # Assuming x and y zoom are kept equal
	var new_zoom_scalar = clampf(current_zoom_scalar + amount, min_zoom_level, max_zoom_level)
	_current_target_zoom_value = Vector2(new_zoom_scalar, new_zoom_scalar)


func _clean_known_targets_list() -> void:
	"""Removes invalid instances from the _known_targets list and updates index."""
	var previously_selected_node: Node2D = null
	if _current_target_list_index != -1 and _current_target_list_index < _known_targets.size():
		if is_instance_valid(_known_targets[_current_target_list_index]):
			previously_selected_node = _known_targets[_current_target_list_index]

	var i = _known_targets.size() - 1
	while i >= 0:
		if not is_instance_valid(_known_targets[i]):
			_known_targets.remove_at(i)
		i -= 1
	
	# After cleaning, try to find the previously selected node again
	if is_instance_valid(previously_selected_node):
		_current_target_list_index = _known_targets.find(previously_selected_node)
	else: # Previous selection is gone or was never valid
		_current_target_list_index = -1

	if _known_targets.is_empty():
		_current_target_list_index = -1
	# If list is not empty and index is -1 (meaning prev selection lost or never existed),
	# it will be set to 0 by focus_next/previous logic if needed.