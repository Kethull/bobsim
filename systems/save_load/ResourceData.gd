extends Resource
class_name ResourceData

@export var id: String = ""
@export var resource_type: String = "unknown"  # e.g., "IronOre", "CopperVein", "Helium3Gas"
@export var position: Vector2 = Vector2.ZERO
@export var current_yield: float = 1000.0  # How much is left to mine
@export var max_yield: float = 1000.0    # Initial or maximum amount
@export var richness: float = 1.0         # Affects mining speed or amount per cycle
@export var depleted: bool = false

func _init(p_id: String = "", p_type: String = "unknown", p_pos: Vector2 = Vector2.ZERO, p_yield: float = 1000.0):
    id = p_id
    resource_type = p_type
    position = p_pos
    current_yield = p_yield
    max_yield = p_yield
    depleted = (current_yield <= 0)

func extract_resource(amount: float) -> float:
    if depleted:
        return 0.0
    
    var extracted_amount = min(amount, current_yield)
    current_yield -= extracted_amount
    
    if current_yield <= 0:
        current_yield = 0.0
        depleted = true
        # Consider emitting a signal here if the resource node itself should react,
        # e.g., signal resource_depleted(id)
        
    return extracted_amount

func is_depleted() -> bool:
    return depleted

func get_percentage_remaining() -> float:
    if max_yield == 0:
        return 0.0 if depleted else 100.0 # Avoid division by zero
    return (current_yield / max_yield) * 100.0