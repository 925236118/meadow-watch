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
	check(visible_text.contains("当前金币：90") and visible_text.contains("当前矿石：0") and visible_text.contains("持有 2 颗"),"shop displays holdings")
	game._shop_page("tools");await process_frame
	var tool_text: String=""
	for card: Node in game.modal_body.get_children():
		for child: Node in card.get_children():
			if child is Label or child is Button: tool_text+=child.text+"\n"
	check(tool_text.contains("20 金币 + 3 矿石") and tool_text.contains("当前：") and tool_text.contains("升级后："),"tool page compares current and upgraded effects")
	game._shop_page("seeds")
	game._buy(0);await process_frame
	check(game.state.gold==75 and game.state.seeds[0]==5 and game.current_menu=="shop","shop purchase refreshes holdings")
	game.modal_undo_button.pressed.emit();await process_frame
	check(game.state.gold==90 and game.state.seeds[0]==2 and game.current_menu=="shop","modal undo restores purchase and keeps shop open")
	game._close()
	game._seed(5)
	check(game.seed_label.text.contains("小麦") and game.seed_button.text.contains("1 颗"),"selected seed always visible after switching")
	game._on_plot(3)
	check(game.seed_label.text.contains("剩余 0 颗"),"planting refreshes visible seed count")
	game._undo()
	check(game.seed_label.text.contains("剩余 1 颗"),"undo refreshes visible seed count")
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
	check(game.hover_label.text.contains("购买小鸡") and game.hover_label.text.contains("0/4"),"empty animal yard guides purchase without AP cost")
	game.farm.hover_active=false;game.hover_panel.hide()
	check(game.weather_label.text.contains("明日 晴天") and game.mail_button.text.contains("未读 3"),"HUD shows two-day weather and unread letters")
	game.farm.hover_active=true;game.farm.update_hover(Vector2(288,132))
	check(game.hover_label.text.contains("信箱") and game.hover_label.text.contains("0 AP"),"physical mailbox has free interaction tooltip")
	game.farm.hover_active=false;game.hover_panel.hide()
	for kind: String in ["seeds","bag","shop","investigate","gifts","expose","rest","mailbox","villagers","person","requests","chains","options"]:
		game._menu(kind);await process_frame
		check(game.shade.visible and game.modal_body.get_child_count()>0,"menu renders: "+kind)
	# Clicking a modal-covered plot must not consume AP.
	var before: int=game.state.ap
	Input.parse_input_event(click);await process_frame
	check(game.state.ap==before,"modal intercepts farm clicks")
	game._menu("villagers");game._village_action("talk",0)
	check(game.current_menu=="story" and game.state.village.people.elder.points==2,"village conversation opens dialogue and adds affection")
	var talk_ap: int=game.state.ap
	game._menu("villagers");game._village_action("talk",0)
	check(game.state.ap==talk_ap and game.state.village.people.elder.points==2 and game.state.village.talk_count==2,"UI repeated conversation uses free quota without gaining affection again")
	game._menu("villagers");game._village_action("talk",0)
	game._menu("villagers");game._village_action("talk",0)
	check(game.state.ap==talk_ap-1 and game.state.village.people.elder.points==2,"UI fourth conversation costs one AP and does not farm affection")
	check(game._stars(40)=="★★★★★" and game._stars(0)=="☆☆☆☆☆","affection UI renders exactly five stars")
	game._menu("person");game.state.inventory.egg=1;game._village_action("gift",0,"egg")
	check(game.current_menu=="person" and game.state.village.people.elder.points==6,"gift menu refreshes affection and stays open")
	game.modal_undo_button.pressed.emit();await process_frame
	check(game.state.village.people.elder.points==2 and game.state.inventory.egg==1,"village modal undo restores gift and affection")
	game._open_letter(1)
	check(game.current_menu=="mailbox" and game.state.village.mail[0].read,"selecting letter updates read status and renders detail")
	game._shop_page("rumors")
	check(game.current_menu=="shop" and game.shop_tab=="rumors","rumor shop page renders")
	game._close();game._on_place("fish");game._deliver(0)
	check(game.state.delivered,"UI activity plus order delivery works")
	game._menu("rest");game._rest();await process_frame
	check(game.state.day==2 and game.state.ap==10,"rest dialog advances turn")
	game.state.evidence=20;game._expose(0);await process_frame
	check(game.shade.visible and game.state.outcome=="good_media","ending appears in UI")
	game.music.stop();game.effect.stop();game.queue_free();await process_frame
	print("[RESULT] UI smoke failures: %d"%failures)
	quit(0 if failures==0 else 1)
