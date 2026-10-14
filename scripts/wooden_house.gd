extends RefCounted
## Editable scene with atlas-backed walls, roof, trim and detail TileMapLayers.
static func create(parent: Node, pos: Vector2, node_name: String, tint: Color=Color.WHITE) -> Node2D:
	var house: Node2D=load("res://scenes/wooden_house.tscn").instantiate()
	house.name=node_name;house.position=pos*3.0;house.scale=Vector2(3,3);house.modulate=tint
	parent.add_child(house)
	return house
