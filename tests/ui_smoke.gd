extends SceneTree
var failures: int=0
var game: Control

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, text: String) -> void:
	if not ok: failures+=1;printerr("[FAIL] "+text)
	else: print("[PASS] "+text)

func run() -> void:
	root.size=Vector2i(1440,900)
	game=load("res://scenes/main.tscn").instantiate();game.testing=true;root.add_child(game)
	await process_frame
	check(game.shade.visible,"intro dialog visible")
	game._close()
	# Dispatch actual keyboard and pointer events through Godot's input pipeline.
	var key: InputEventKey=InputEventKey.new();key.keycode=KEY_4;key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	check(game.selected_tool=="harvest","hotkey selects harvest tool")
	var click: InputEventMouseButton=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(391,406)
	click.global_position=click.position
	Input.parse_input_event(click)
	await process_frame
	check(game.state.inventory["0"]==2 and game.state.ap==8,"farm pointer event harvests mature crop")
	var undo_key: InputEventKey=InputEventKey.new();undo_key.keycode=KEY_Z;undo_key.ctrl_pressed=true;undo_key.pressed=true
	Input.parse_input_event(undo_key);await process_frame
	check(game.state.ap==10 and game.state.inventory["0"]==0,"Ctrl Z restores harvested crop and AP")
	Input.parse_input_event(click);await process_frame
	game._menu("shop")
	var visible_text: String=""
	for child: Node in game.modal_body.get_children():
		if child is Label or child is Button: visible_text+=child.text+"\n"
	check(visible_text.contains("当前金币：90") and visible_text.contains("当前矿石：0") and visible_text.contains("持有 5 颗") and visible_text.contains("20 金币 + 3 矿石"),"shop displays holdings and additive upgrade cost")
	game._buy(0);await process_frame
	check(game.state.gold==75 and game.state.seeds[0]==8 and game.current_menu=="shop","shop purchase refreshes holdings")
	game.modal_undo_button.pressed.emit();await process_frame
	check(game.state.gold==90 and game.state.seeds[0]==5 and game.current_menu=="shop","modal undo restores purchase and keeps shop open")
	game._close()
	game._seed(1)
	check(game.seed_label.text.contains("卷心菜") and game.seed_button.text.contains("5 颗"),"selected seed always visible after switching")
	game._on_plot(3)
	check(game.seed_label.text.contains("剩余 4 颗"),"planting refreshes visible seed count")
	game._undo()
	check(game.seed_label.text.contains("剩余 5 颗"),"undo refreshes visible seed count")
	var before_walk: Dictionary=game.state.to_data()
	var walk_ok: bool=true
	var stops: Dictionary={}
	game.farm.ambient_rng.seed=123
	for i: int in range(1200):
		game.farm._advance_actor(0.1)
		var feet: Vector2=game.farm.actor_feet
		walk_ok=walk_ok and (Rect2(94,32,16,145).has_point(feet) or Rect2(32,144,272,32).has_point(feet))
		stops[game.farm.actor_node]=true
	check(walk_ok and stops.size()>2 and game.state.to_data()==before_walk,"ambient character visits road positions without changing game state")
	game.farm.hover_active=true
	game.farm.update_hover(Vector2(120,375))
	check(game.hover_panel.visible and game.hover_label.text.contains("3 AP") and game.farm.mouse_default_cursor_shape==Control.CURSOR_POINTING_HAND,"pond hover shows cost and hand cursor")
	game.state.ap=1;game.farm.update_hover(Vector2(801,150))
	check(game.hover_label.text.contains("AP 不足") and game.farm.mouse_default_cursor_shape==Control.CURSOR_FORBIDDEN,"hover explains insufficient AP with forbidden cursor")
	game.state.ap=8;game.farm.update_hover(Vector2(360,120))
	check(game.hover_label.text.contains("鲜鱼 ×1") and game.hover_label.text.contains("同种作物 ×2") and game.hover_label.text.contains("2 AP"),"cooking hover explains ingredients")
	game.farm.update_hover(Vector2(801,357))
	check(game.hover_label.text.contains("4 金币"),"animal hover displays feed cost")
	game.farm.hover_active=false;game.hover_panel.hide()
	for kind: String in ["seeds","bag","shop","investigate","expose","rest","options"]:
		game._menu(kind);await process_frame
		check(game.shade.visible and game.modal_body.get_child_count()>0,"menu renders: "+kind)
	# Clicking a modal-covered plot must not consume AP.
	var before: int=game.state.ap
	Input.parse_input_event(click);await process_frame
	check(game.state.ap==before,"modal intercepts farm clicks")
	game._close();game._on_place("fish");game._deliver(0)
	check(game.state.delivered,"UI activity plus order delivery works")
	game._menu("rest");game._rest();await process_frame
	check(game.state.day==2 and game.state.ap==10,"rest dialog advances turn")
	game.state.evidence=20;game._expose(0);await process_frame
	check(game.shade.visible and game.state.outcome=="good_media","ending appears in UI")
	game.music.stop();game.effect.stop();game.queue_free();await process_frame
	print("[RESULT] UI smoke failures: %d"%failures)
	quit(0 if failures==0 else 1)
