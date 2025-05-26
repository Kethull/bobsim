extends Resource
class_name PhysicsUtils

static func safe_divide(numerator: float, denominator: float, epsilon: float = 1e-12, default_value: float = 0.0) -> float:
    if abs(denominator) < epsilon:
        return default_value
    return numerator / denominator

static func normalize_vector(vector: Vector2, epsilon: float = 1e-12) -> Vector2:
    var length_sq = vector.length_squared()
    if length_sq < epsilon * epsilon: # Compare squared length to squared epsilon
        return Vector2.ZERO
    return vector / sqrt(length_sq)

# It's good practice to ensure Config is loaded if its constants are needed here.
# However, for these specific functions, Config is not directly used.
# If future utilities here need Config, ensure it's accessible.