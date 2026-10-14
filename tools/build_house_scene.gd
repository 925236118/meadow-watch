extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/tilesets")
	var tiles: TileSet=TileSet.new();tiles.tile_size=Vector2i(16,16)
	for i: int in range(3):
		var atlas: TileSetAtlasSource=TileSetAtlasSource.new()
		atlas.texture=load("res://assets/sprites/Tilesets/Building parts/Wooden_House_%s_Tilset.png"%(["Roof","Walls","Roof"][i]))
		atlas.texture_region_size=Vector2i(16,8 if i==2 else 16)
		for y: int in range(atlas.texture.get_height()/atlas.texture_region_size.y):
			for x: int in range(atlas.texture.get_width()/16):
				atlas.create_tile(Vector2i(x,y))
				if i==2: atlas.get_tile_data(Vector2i(x,y),0).texture_origin=Vector2i(0,4)
		tiles.add_source(atlas,i)
	ResourceSaver.save(tiles,"res://assets/tilesets/wooden_house.tres")
	var house: Node2D=Node2D.new();house.name="WoodenHouse"
	for name: String in ["Walls","Roof","RoofTrim","Details"]:
		var layer: TileMapLayer=TileMapLayer.new();house.add_child(layer);layer.owner=house
		layer.name=name;layer.tile_set=tiles;layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		layer.collision_enabled=false;layer.navigation_enabled=false
	var walls: TileMapLayer=house.get_node("Walls")
	var roof: TileMapLayer=house.get_node("Roof")
	var trim: TileMapLayer=house.get_node("RoofTrim")
	var details: TileMapLayer=house.get_node("Details")
	for col: int in range(5):
		var x: int=0 if col==0 else (2 if col==4 else 1)
		for row: int in range(2):
			walls.set_cell(Vector2i(col,row+2),1,Vector2i(x,row+1))
			roof.set_cell(Vector2i(col,row),0,Vector2i(x,row))
		trim.set_cell(Vector2i(col,2),2,Vector2i(x,4))
	for x: int in range(2):
		for y: int in range(2): details.set_cell(Vector2i(x+1,y+2),1,Vector2i(x+3,y))
	details.set_cell(Vector2i(3,3),1,Vector2i(3,2))
	var packed: PackedScene=PackedScene.new();packed.pack(house)
	ResourceSaver.save(packed,"res://scenes/wooden_house.tscn")
	house.free();quit()
