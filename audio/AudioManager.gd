# AudioManager.gd (AutoLoad)
class_name AudioManager
extends Node

var audio_pools: Dictionary = {}
var active_audio_sources: Array[AudioStreamPlayer2D] = []
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var ambient_volume: float = 0.7

func _ready():
    # Create audio pools for common sounds
    create_audio_pools()
    
    # Load settings
    load_audio_settings()

func create_audio_pools():
    var sound_configs = {
        "thruster": {"file": "res://audio/thruster_loop.ogg", "count": 20},
        "mining_laser": {"file": "res://audio/mining_laser.ogg", "count": 10},
        "communication": {"file": "res://audio/communication_beep.ogg", "count": 5},
        "energy_critical": {"file": "res://audio/energy_warning.ogg", "count": 5},
        "discovery": {"file": "res://audio/discovery_chime.ogg", "count": 8},
        "replication": {"file": "res://audio/replication_success.ogg", "count": 3},
        "explosion": {"file": "res://audio/explosion.ogg", "count": 5}
    }
    
    for sound_type in sound_configs:
        var config = sound_configs[sound_type]
        audio_pools[sound_type] = []
        
        var audio_stream = load(config.file)
        
        for i in range(config.count):
            var audio_player = AudioStreamPlayer2D.new()
            audio_player.stream = audio_stream
            audio_player.autoplay = false
            add_child(audio_player)
            audio_pools[sound_type].append(audio_player)

func play_sound_at_position(sound_type: String, position: Vector2, volume: float = 1.0, pitch: float = 1.0):
    var audio_player = get_available_audio_player(sound_type)
    if not audio_player:
        return
    
    audio_player.global_position = position
    audio_player.volume_db = linear_to_db(volume * sfx_volume * master_volume)
    audio_player.pitch_scale = pitch
    audio_player.play()
    
    if audio_player not in active_audio_sources:
        active_audio_sources.append(audio_player)
    
    # Auto-cleanup when finished
    if not audio_player.finished.is_connected(_on_audio_finished):
        audio_player.finished.connect(_on_audio_finished.bind(audio_player))

func get_available_audio_player(sound_type: String) -> AudioStreamPlayer2D:
    if not audio_pools.has(sound_type):
        return null
    
    var pool = audio_pools[sound_type]
    for player in pool:
        if not player.playing:
            return player
    
    # All players busy, return first one (will interrupt)
    return pool[0]

func play_looping_sound(sound_type: String, position: Vector2, volume: float = 1.0) -> AudioStreamPlayer2D:
    var audio_player = get_available_audio_player(sound_type)
    if not audio_player:
        return null
    
    audio_player.global_position = position
    audio_player.volume_db = linear_to_db(volume * sfx_volume * master_volume)
    
    # Enable looping if the stream supports it
    if audio_player.stream is AudioStreamOggVorbis:
        audio_player.stream.loop = true
    
    audio_player.play()
    
    if audio_player not in active_audio_sources:
        active_audio_sources.append(audio_player)
    
    return audio_player

func stop_looping_sound(audio_player: AudioStreamPlayer2D):
    if audio_player and audio_player.playing:
        audio_player.stop()
        active_audio_sources.erase(audio_player)

func _on_audio_finished(audio_player: AudioStreamPlayer2D):
    active_audio_sources.erase(audio_player)

func set_master_volume(volume: float):
    master_volume = clamp(volume, 0.0, 1.0)
    update_all_volumes()

func set_sfx_volume(volume: float):
    sfx_volume = clamp(volume, 0.0, 1.0)
    update_all_volumes()

func set_ambient_volume(volume: float):
    ambient_volume = clamp(volume, 0.0, 1.0)
    update_all_volumes()

func update_all_volumes():
    for player in active_audio_sources:
        if player and player.playing:
            player.volume_db = linear_to_db(sfx_volume * master_volume)

func load_audio_settings():
    var config_file = ConfigFile.new()
    if config_file.load("user://audio_settings.cfg") == OK:
        master_volume = config_file.get_value("audio", "master_volume", 1.0)
        sfx_volume = config_file.get_value("audio", "sfx_volume", 1.0)
        ambient_volume = config_file.get_value("audio", "ambient_volume", 0.7)

func save_audio_settings():
    var config_file = ConfigFile.new()
    config_file.set_value("audio", "master_volume", master_volume)
    config_file.set_value("audio", "sfx_volume", sfx_volume)
    config_file.set_value("audio", "ambient_volume", ambient_volume)
    config_file.save("user://audio_settings.cfg")