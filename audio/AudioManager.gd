class_name AudioManager
extends Node

# --- Variables ---
var audio_pools: Dictionary = {}
var active_audio_sources: Array[AudioStreamPlayer2D] = [] # For non-looping one-shot sounds
var playing_sound_details: Dictionary = {} # player_node -> { "offset_db": float }

var master_volume: float = 1.0 # Linear volume (0.0 to 1.0)
var sfx_volume: float = 1.0    # Linear volume
var ambient_volume: float = 1.0 # Linear volume (can be used for other sound categories)

const AUDIO_SETTINGS_PATH = "user://audio_settings.cfg"

# --- Godot Lifecycle ---
func _ready() -> void:
	create_audio_pools()
	load_audio_settings()
	# Initial volume update based on loaded/default settings
	# update_all_volumes() # Called by set_..._volume methods, and load_audio_settings will trigger it.


# --- Initialization ---
func create_audio_pools() -> void:
	var sound_configs = {
		"thruster": {"file": "res://audio/placeholder.ogg", "count": 5},
		"mining_laser": {"file": "res://audio/placeholder.ogg", "count": 3},
		"communication": {"file": "res://audio/placeholder.ogg", "count": 2},
		"energy_critical": {"file": "res://audio/placeholder.ogg", "count": 1},
		"discovery": {"file": "res://audio/placeholder.ogg", "count": 1},
		"replication": {"file": "res://audio/placeholder.ogg", "count": 1},
		"explosion": {"file": "res://audio/placeholder.ogg", "count": 5}
	}

	for sound_type in sound_configs.keys():
		var config = sound_configs[sound_type]
		var pool_name: String = sound_type

		audio_pools[pool_name] = []

		# Check if audio file exists, skip if not
		if not FileAccess.file_exists(config.file):
			print("Warning: Audio file not found: ", config.file)
			continue
		
		var loaded_item = load(config.file)
		var audio_stream: AudioStream = null

		if loaded_item is AudioStream:
			audio_stream = loaded_item
		else:
			var type_info_str : String = "unknown or null"
			if loaded_item != null:
				type_info_str = loaded_item.get_class()
				var script_res = loaded_item.get_script()
				if script_res is Script and script_res.resource_path: # Check if script_res is valid Script object
					type_info_str += " (script: " + script_res.resource_path + ")"
			printerr("AudioManager: File '", config.file, "' for pool '", pool_name, "' loaded as '", type_info_str, "' instead of AudioStream. Skipping.")
			continue

		if not audio_stream: # Additional safeguard, though the above logic should cover it.
			printerr("AudioManager: AudioStream is null after type check for path: ", config.file, " for pool: ", pool_name, ". Skipping.")
			continue

		for i in range(config.count):
			var player := AudioStreamPlayer2D.new()
			player.name = "%s_Player_%d" % [pool_name, i + 1]
			player.stream = audio_stream
			add_child(player)
			audio_pools[pool_name].append(player)
			player.finished.connect(_on_audio_player_finished.bind(player))


func _on_audio_player_finished(player: AudioStreamPlayer2D) -> void:
	if active_audio_sources.has(player):
		active_audio_sources.erase(player)
	
	if playing_sound_details.has(player):
		playing_sound_details.erase(player)


# --- Sound Playback ---
func get_available_audio_player(pool_name: String) -> AudioStreamPlayer2D:
	if not audio_pools.has(pool_name):
		printerr("AudioManager: Audio pool not found: ", pool_name)
		return null

	var pool: Array = audio_pools[pool_name]
	for player_candidate in pool:
		if player_candidate is AudioStreamPlayer2D and not player_candidate.is_playing():
			return player_candidate
	
	# printerr("AudioManager: No available player in pool: ", pool_name) # Optional: for debugging
	return null


func play_sound_at_position(sound_name: String, position: Vector2, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player: AudioStreamPlayer2D = get_available_audio_player(sound_name)
	if player:
		if player.stream is AudioStreamOggVorbis:
			(player.stream as AudioStreamOggVorbis).loop = false
		
		player.global_position = position
		player.volume_db = linear_to_db(master_volume * sfx_volume) + volume_db_offset 
		player.pitch_scale = pitch_scale
		player.play()
		
		if not active_audio_sources.has(player):
			active_audio_sources.append(player)
		playing_sound_details[player] = {"offset_db": volume_db_offset}
	else:
		printerr("AudioManager: Could not play sound '", sound_name, "'. No available player.")


func play_looping_sound(sound_name: String, attached_node: Node, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	var player: AudioStreamPlayer2D = get_available_audio_player(sound_name)
	if player:
		if player.stream is AudioStreamOggVorbis:
			(player.stream as AudioStreamOggVorbis).loop = true
		# For other stream types, Godot 4 AudioStream has loop_mode if needed
		# elif player.stream and player.stream.has_method("set_loop_mode"):
		#    player.stream.set_loop_mode(AudioStream.LOOP_FORWARD)

		if player.get_parent() != attached_node:
			if player.get_parent():
				player.get_parent().remove_child(player)
			attached_node.add_child(player)
			player.position = Vector2.ZERO 

		player.volume_db = linear_to_db(master_volume * sfx_volume) + volume_db_offset
		player.pitch_scale = pitch_scale
		player.play()
		
		playing_sound_details[player] = {"offset_db": volume_db_offset}
		return player
	else:
		printerr("AudioManager: Could not play looping sound '", sound_name, "'. No available player.")
		return null


func stop_looping_sound(audio_player: AudioStreamPlayer2D) -> void:
	if is_instance_valid(audio_player):
		audio_player.stop()
		if playing_sound_details.has(audio_player):
			playing_sound_details.erase(audio_player)
		
		# Return to AudioManager's child hierarchy if it was moved
		if audio_player.get_parent() != self:
			if audio_player.get_parent():
				audio_player.get_parent().remove_child(audio_player)
			add_child(audio_player)
	else:
		printerr("AudioManager: Attempted to stop an invalid audio player instance.")


# --- Volume Control ---
func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	update_all_volumes()
	save_audio_settings()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	update_all_volumes()
	save_audio_settings()

func set_ambient_volume(volume: float) -> void:
	ambient_volume = clampf(volume, 0.0, 1.0)
	update_all_volumes() # This will affect sounds if ambient_volume is incorporated into their calculation
	save_audio_settings()

func update_all_volumes() -> void:
	var base_sfx_db = linear_to_db(master_volume * sfx_volume)
	# Consider master_volume * ambient_volume for ambient sounds if categorized

	# Create a copy of keys to iterate over, as dictionary might be modified by _on_audio_player_finished
	var players_to_update = playing_sound_details.keys()

	for player_node in players_to_update:
		if is_instance_valid(player_node) and playing_sound_details.has(player_node): # Check again if still valid and in dict
			var details = playing_sound_details[player_node]
			var offset_db: float = details.get("offset_db", 0.0)
			(player_node as AudioStreamPlayer2D).volume_db = base_sfx_db + offset_db
		elif playing_sound_details.has(player_node): # Was in dict but now invalid
			playing_sound_details.erase(player_node)


# --- Settings Persistence ---
func load_audio_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(AUDIO_SETTINGS_PATH)
	if err == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		ambient_volume = config.get_value("audio", "ambient_volume", 1.0)
	else:
		# File not found or error, use defaults and save a new one
		master_volume = 1.0
		sfx_volume = 1.0
		ambient_volume = 1.0
		# save_audio_settings() # Optionally save defaults immediately

	# Ensure volumes are clamped after loading
	master_volume = clampf(master_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	ambient_volume = clampf(ambient_volume, 0.0, 1.0)
	
	update_all_volumes() # Apply loaded/default settings to any playing sounds

func save_audio_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	
	var err = config.save(AUDIO_SETTINGS_PATH)
	if err != OK:
		printerr("AudioManager: Failed to save audio settings to ", AUDIO_SETTINGS_PATH, ". Error code: ", err)