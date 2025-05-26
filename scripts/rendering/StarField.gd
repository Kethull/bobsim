extends Node2D
class_name StarField

# Default values, can be overridden by constructor or properties
var world_width: float = Config.World.WIDTH_SIM # Match simulation world size for full coverage initially
var world_height: float = Config.World.HEIGHT_SIM
var num_stars_total: int = 500 # Total stars across all layers

var star_layers_config: Array = [
    {"speed_factor": 0.02, "base_brightness": 0.3, "size_px": 1.0, "count_ratio": 0.5, "color_tint": Color(0.8, 0.8, 1.0)}, # Faint, slow, bluish
    {"speed_factor": 0.05, "base_brightness": 0.5, "size_px": 1.2, "count_ratio": 0.3, "color_tint": Color(1.0, 1.0, 0.9)}, # Medium
    {"speed_factor": 0.10, "base_brightness": 0.8, "size_px": 1.5, "count_ratio": 0.2, "color_tint": Color(1.0, 0.95, 0.85)}  # Brighter, faster, yellowish
]

var star_layers_data: Array = [] # Will store Array[Dictionary] for each star

# The camera this starfield should follow for parallax effect.
# This needs to be set externally, e.g., from the Main scene.
var target_camera: Camera2D = null 
var last_camera_pos: Vector2 = Vector2.ZERO


func _init(p_world_width: float = -1, p_world_height: float = -1, p_star_count: int = -1):
    if p_world_width > 0: world_width = p_world_width
    if p_world_height > 0: world_height = p_world_height
    if p_star_count > 0: num_stars_total = p_star_count
    
    generate_all_star_layers()

func generate_all_star_layers():
    star_layers_data.clear()
    for layer_cfg in star_layers_config:
        var layer_stars_array: Array[Dictionary] = []
        var num_stars_in_layer = int(num_stars_total * layer_cfg.count_ratio)
        
        for _i in range(num_stars_in_layer):
            var star_data: Dictionary = {
                "initial_pos": Vector2(randf() * world_width, randf() * world_height), # Position within the 'world_width/height'
                "brightness_mod": randf_range(0.6, 1.0), # Individual brightness variation
                "twinkle_phase": randf() * TAU,
                "twinkle_speed": randf_range(0.5, 2.0), # Radians per second for twinkle
                "color_variation": randf_range(-0.1, 0.1) # Slight hue shift
            }
            layer_stars_array.append(star_data)
        star_layers_data.append({
            "stars": layer_stars_array,
            "config": layer_cfg
        })

func _process(delta):
    # If there's a target camera, we need to trigger a redraw when it moves.
    if is_instance_valid(target_camera):
        if target_camera.global_position != last_camera_pos:
            last_camera_pos = target_camera.global_position
            queue_redraw() # Redraw if camera moved
    else:
        # If no camera, maybe redraw periodically for twinkling if that's desired without parallax
        queue_redraw() # Or based on a timer for twinkling effect update

func _draw():
    var cam_center_offset = Vector2.ZERO
    var current_zoom = Vector2.ONE

    if is_instance_valid(target_camera):
        # Parallax is relative to camera's top-left, not its center, if we want stars to fill viewport
        # Or, more simply, treat camera_offset as the center of the view for parallax calculation.
        # The provided code uses camera_offset, which implies it's the center of the view.
        # Let's assume target_camera.global_position is the center of the view.
        cam_center_offset = target_camera.global_position
        current_zoom = target_camera.zoom
    
    var time_sec = Time.get_ticks_msec() / 1000.0

    for layer_data in star_layers_data:
        var stars_array: Array[Dictionary] = layer_data.stars
        var cfg: Dictionary = layer_data.config
        
        var speed_factor: float = cfg.speed_factor
        var base_brightness: float = cfg.base_brightness
        var size_px: float = cfg.size_px * (1.0 / current_zoom.x) # Scale star size with zoom
        size_px = max(0.5, size_px) # Ensure stars don't become too small or invisible
        var color_tint: Color = cfg.color_tint
        
        # Parallax shift: how much this layer moves opposite to camera movement
        # The origin for stars is (0,0) of the StarField node itself.
        # If StarField is at (0,0) in world, then parallax_origin is effectively cam_center_offset.
        # If StarField is, e.g., centered with the world, adjust accordingly.
        # For simplicity, assume StarField node is at (0,0) or its position is accounted for.
        var parallax_displacement = cam_center_offset * speed_factor

        for star_dict in stars_array:
            var initial_star_pos: Vector2 = star_dict.initial_pos
            
            # Calculate effective position with parallax
            # Stars are defined in a large 'world_width/height' area.
            # We need to wrap them around the viewport.
            # Viewport rect in global coords
            var viewport_rect = get_viewport_rect()
            var view_top_left_global = target_camera.get_screen_center_position() - viewport_rect.size * 0.5 * current_zoom
            
            # Position of the star relative to the StarField node's origin, after parallax
            var star_pos_relative_to_node = initial_star_pos - parallax_displacement
            
            # To make stars wrap around the viewport correctly:
            # We need the star's position in screen coordinates.
            # Global position of star = self.global_position + star_pos_relative_to_node
            # Screen position = (Global position of star - view_top_left_global) / current_zoom
            
            # Simpler approach: Assume stars are drawn relative to this Node2D's local coords.
            # The _draw() call is already in local coords.
            # So, star_pos_relative_to_node is what we draw at.
            # We need to ensure these local coordinates are wrapped if they go off-screen.
            # This requires knowing the screen size in local coordinates of this StarField node.
            
            # The original code's fmod logic is for a fixed screen size.
            # For a camera-following starfield, it's more about ensuring stars are always generated
            # in a region larger than the screen and that their parallax makes them appear correctly.
            # The fmod approach is simpler if the StarField node itself fills the screen and camera doesn't move it.
            # Given the `target_camera` reference, a true parallax effect is intended.

            # Let's use a simpler drawing for now, assuming stars are drawn at `star_pos_relative_to_node`
            # and rely on a large enough `world_width/height` and star density.
            # Proper wrapping for a moving camera is more complex.
            
            var screen_pos_to_draw = star_pos_relative_to_node # This is in StarField's local space

            var twinkle = (sin(time_sec * star_dict.twinkle_speed + star_dict.twinkle_phase) + 1.0) / 2.0 # 0 to 1
            var current_brightness = base_brightness * star_dict.brightness_mod * (0.7 + 0.3 * twinkle)
            
            if current_brightness < 0.05: continue # Too dim to draw

            var star_base_color = color_tint.lerp(Color.WHITE, star_dict.color_variation)
            var final_star_color = Color(
                star_base_color.r * current_brightness,
                star_base_color.g * current_brightness,
                star_base_color.b * current_brightness,
                clamp(current_brightness * 1.5, 0.5, 1.0) # Alpha also tied to brightness
            )
            
            if size_px <= 1.0:
                 draw_primitive([screen_pos_to_draw], [final_star_color], PackedVector2Array()) # Draw a single point
            else:
                 draw_circle(screen_pos_to_draw, size_px * 0.5, final_star_color) # Draw small circle for larger stars

func set_target_camera(camera: Camera2D):
    target_camera = camera
    if is_instance_valid(target_camera):
        last_camera_pos = target_camera.global_position
    queue_redraw()

# Call this if world dimensions change significantly to regenerate stars in new bounds
func update_world_dimensions(new_width: float, new_height: float):
    world_width = new_width
    world_height = new_height
    generate_all_star_layers()
    queue_redraw()