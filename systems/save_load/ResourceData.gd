extends Resource
class_name ResourceData

@export var id: String = ""
@export var resource_type: String = "mineral"  # mineral, energy, rare_earth, water
@export var position: Vector2 = Vector2.ZERO
@export var current_amount: float = 1000.0  # How much is left to mine
@export var max_amount: float = 1000.0    # Initial or maximum amount
# Old field names were current_yield and max_yield
@export var regeneration_rate: float = 0.0  # How fast it regenerates
@export var harvest_difficulty: float = 1.0  # Affects mining speed/efficiency
@export var depleted: bool = false

func _init(p_id: String = "", p_type: String = "mineral", p_pos: Vector2 = Vector2.ZERO, p_amount: float = 1000.0):
    id = p_id
    resource_type = p_type
    position = p_pos
    current_amount = p_amount
    max_amount = p_amount
    depleted = (current_amount <= 0)

func extract_resource(amount: float) -> float:
    if depleted:
        return 0.0
    
    var extracted_amount = min(amount, current_amount)
    current_amount -= extracted_amount
    
    if current_amount <= 0:
        current_amount = 0.0
        depleted = true
        # Consider emitting a signal here if the resource node itself should react,
        # e.g., signal resource_depleted(id)
        
    return extracted_amount

func is_depleted() -> bool:
    return depleted

func get_percentage_remaining() -> float:
    if max_amount == 0:
        return 0.0 if depleted else 100.0 # Avoid division by zero
    return (current_amount / max_amount) * 100.0