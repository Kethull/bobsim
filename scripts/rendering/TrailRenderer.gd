extends Node2D
class_name TrailRenderer

var trail_points: Array[Vector2] = []
var trail_color: Color = Color(0.5, 0.5, 0.5, 0.7) # Default color
var trail_width: float = 1.0
var max_points: int = -1 # Optional: if set, limits points similar to CelestialBody/Probe logic

func _init(p_max_points: int = -1, p_color: Color = Color(0.5, 0.5, 0.5, 0.7), p_width: float = 1.0):
    max_points = p_max_points
    trail_color = p_color
    trail_width = p_width

func update_trail(points: Array[Vector2]):
    trail_points = points.duplicate() # Use a copy to avoid modification issues if original is changed elsewhere
    if max_points > 0 and trail_points.size() > max_points:
        trail_points = trail_points.slice(trail_points.size() - max_points) # Keep only the last max_points
    queue_redraw()

func clear_trail():
    trail_points.clear()
    queue_redraw()

func set_trail_properties(p_color: Color, p_width: float, p_max_points: int = -1):
    trail_color = p_color
    trail_width = p_width
    if p_max_points != -1:
        max_points = p_max_points
    queue_redraw()

func _draw():
    if trail_points.size() < 2:
        return

    for i in range(trail_points.size() - 1):
        var p1 = trail_points[i]
        var p2 = trail_points[i+1]
        
        # Calculate alpha based on segment position (older segments are more transparent)
        # This makes the trail fade out at its start.
        var alpha_ratio = float(i + 1) / float(trail_points.size()) # Ranges from near 0 to 1
        var segment_color = Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha_ratio)
        
        draw_line(p1, p2, segment_color, trail_width, true) # Antialiased line