extends SceneTree
var checks: int=0
var failures: int=0
var game: Control
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("[PASS] "+label)
	else: failures+=1;printerr("[FAIL] "+label)
func _initialize() -> void: run.call_deferred()
func click_at(point: Vector2) -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=point;event.global_position=point
	Input.parse_input_event(event)
func texts(node: Node) -> String:
	var result: String=""
	if node is Label or node is Button: result+=node.text+"\n"
	for child: Node in node.get_children(): result+=texts(child)
	return result
func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate();game.testing=true;root.add_child(game)
	await process_frame;game._close()
	var before: Dictionary=game.state.to_data()
	game.map_button.pressed.emit();await process_frame
	check(game.current_map=="village" and game.village_map.visible and not game.farm.visible and game.state.to_data()==before,"top button enters separate village scene without AP or state change")
	check(game.village_map.actors.size()==4 and game.village_bar.visible and not game.seed_button.visible,"village has four residents and its own shortcut bar")
	var tiled: bool=true
	for building: Node in [game.farm.get_node("Farmhouse"),game.village_map.get_node("Shop"),game.village_map.get_node("Tavern"),game.village_map.get_node("PostOffice")]:
		for part: String in ["Roof","Walls","Details"]:
			var layer: Node=building.get_node(part)
			tiled=tiled and layer is TileMapLayer and layer.get_used_cells().size()>0 and layer.tile_set!=null
	check(tiled,"houses actually use editable roof, wall and detail TileMapLayers")
	click_at(game.village_map.position+Vector2(272,107)*3);await process_frame
	check(game.current_menu=="tavern","physical tavern at marked location opens drinking interaction")
	var tavern_ap: int=game.state.ap
	game._village_action("drink")
	check(game.current_menu=="story" and game.state.ap==tavern_ap-1,"tavern button runs drinking action and shows encounter")
	game._close();game._undo();await process_frame
	check(game.state.to_data()==before,"tavern UI action undo restores complete farm state")
	var positions: Array=game.village_map.actors.duplicate(true)
	game.village_map.ambient_rng.seed=123
	for i: int in range(400): game.village_map._advance_villagers(0.1)
	check(game.village_map.actors!=positions and game.state.to_data()==before,"villagers walk independently without spending AP or rerolling game RNG")
	var feet: Vector2=game.village_map.actors[0].feet
	click_at(game.village_map.position+(feet-Vector2(0,11))*3);await process_frame
	check(game.current_menu=="neighbor" and game.focus_person==0 and game.village_map.paused,"actual resident click opens correct interaction and pauses walking")
	positions=game.village_map.actors.duplicate(true)
	game.village_map._process(2.0)
	check(game.village_map.actors==positions,"residents stay still while interaction modal is open")
	var count: int=game.state.village.talk_count
	game._village_action("talk",0)
	check(game.state.village.talk_count==count+1 and game.current_menu=="story" and game.state.village.people.elder.points==2,"village resident conversation uses existing free and affection rules")
	game._close();check(not game.village_map.paused,"closing dialogue resumes village movement")
	click_at(game.village_map.position+Vector2(156,40)*3);await process_frame
	check(game.current_menu=="noticeboard" and texts(game.modal_body).contains("天气"),"physical board opens weather, orders and mutual help")
	game._close();click_at(game.village_map.position+Vector2(257,40)*3);await process_frame
	check(game.current_menu=="shop","physical shop reuses existing store")
	game._shop_page("animals")
	check(texts(game.modal_body).contains("0 / 4") and texts(game.modal_body).contains("40 金币"),"chicken shop displays flock capacity and upfront price")
	game._shop_purchase("chicken")
	check(game.state.chickens==1 and game.state.gold==50 and game.current_menu=="shop","shop purchase refreshes owned chicken count")
	game.modal_undo_button.pressed.emit();await process_frame
	check(game.state.chickens==0 and game.state.gold==90 and game.current_menu=="shop","store undo restores purchased chicken and money")
	game._close();click_at(game.village_map.position+Vector2(50,40)*3);await process_frame
	check(game.current_menu=="mailbox","village post office opens existing mailbox")
	game._close();click_at(game.village_map.position+Vector2(33,160)*3);await process_frame
	check(game.current_map=="farm" and game.farm.visible and not game.village_bar.visible,"village exit restores farm scene and action toolbar")
	before=game.state.to_data();click_at(game.farm.position+Vector2(24,20)*3);await process_frame
	check(game.state.inventory.wood==3 and game.state.ap==8,"actual forest click chops one tree")
	game._undo();check(game.state.to_data()==before,"forest click is fully reversible")
	game.farm.hover_active=true;game.farm.update_hover(Vector2(24,20)*3)
	check(game.hover_label.text.contains("木材 ×3") and game.hover_label.text.contains("2 AP"),"forest hover shows AP cost and material yield")
	game._shop_page("tools")
	check(texts(game.modal_body).contains("3 矿石 + 2 木材") and texts(game.modal_body).contains("木材：0"),"upgrade page shows wood cost and holdings")
	game._menu("bag");check(texts(game.modal_body).contains("木材") and texts(game.modal_body).contains("6 金币"),"bag displays wood quantity, icon and sale price")
	game._close();game.state.ap=0;game._switch_map("village");game._switch_map("farm")
	check(game.state.ap==0 and game.current_map=="farm","map switching remains available with zero AP")
	game.music.stop();game.effect.stop();game.queue_free();await process_frame
	print("[RESULT] %d village scene checks, %d failures"%[checks,failures]);quit(1 if failures>0 else 0)
