extends Control
const State = preload("res://scripts/farm_state.gd")
const View = preload("res://scripts/farm_view.gd")
const FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const ICONS: Texture2D = preload("res://assets/ui/UI Sprites/Icons/All Icons.png")
const CROP_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/Farming Plants items.png")
const TOOL_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/tools and meterials.png")
const ALL_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/All items.png")
const FISH_ICON: Texture2D = preload("res://assets/icons/fishing.svg")
const FISH_ITEM: Texture2D = preload("res://assets/icons/fish.svg")
const COOK_ICON: Texture2D = preload("res://assets/icons/cooking.svg")
const BAG_ICON: Texture2D = preload("res://assets/icons/backpack.svg")
const Village=preload("res://scripts/village_rules.gd")
var state: RefCounted = State.new()
var farm: Control
var village_map: Control
var current_map: String="farm"
var map_button: Button
var village_bar: Control
var focus_person: int=-1
var hud: Label
var status: Label
var hint: Label
var news: Label
var progress: ProgressBar
var order_labels: Array[Label] = []
var order_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var activity_buttons: Array[Button] = []
var selected_tool: String = "auto"
var selected_seed: int = 0
var modal: Control
var modal_title: Label
var modal_body: Control
var shade: ColorRect
var current_menu: String = ""
var music: AudioStreamPlayer
var effect: AudioStreamPlayer
var muted: bool = false
var capture: bool = false
var testing: bool = false
var undo_button: Button
var modal_undo_button: Button
var seed_label: Label
var seed_button: Button
var hover_panel: Panel
var shop_tab: String = "seeds"
var selected_person: int=0
var selected_mail: int=-1
var weather_label: Label
var event_label: Label
var mail_button: Button
var hover_label: Label

func _ready() -> void:
	get_tree().auto_accept_quit=false
	capture = OS.get_cmdline_user_args().has("--capture")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()
	state.changed.connect(_refresh)
	state.message.connect(_message)
	state.story.connect(_story)
	_refresh()
	music=AudioStreamPlayer.new(); add_child(music)
	music.stream=load("res://assets/audio/meadow.wav"); music.volume_db=-22
	if not testing and not capture: music.play()
	music.finished.connect(func() -> void: music.play())
	effect=AudioStreamPlayer.new(); add_child(effect)
	effect.stream=load("res://assets/audio/action.wav"); effect.volume_db=-15
	if capture: _capture.call_deferred()
	else:
		_story("麦野守望 · 春天的第一封信", "你继承了村外的小农场。黎明工业想买下整片土地，你拒绝了。\n\n村长：别急，先把日子过好。每天有 10 点行动力，收获、钓鱼、交付订单都能帮你站稳脚跟。\n\n小林：从第 4 天起留意异常，在第 25 天结束前收集 20 份证据，公开真相。\n\n先试试：直接点击闪光的胡萝卜 → 去订单板看看。\n\n作物需要浇水，并在结束一天时生长。每晚维护费 8 金币。")

func _panel(rect: Rect2, parent: Node=self, color: String="243e32") -> Panel:
	var p: Panel=Panel.new(); parent.add_child(p);p.position=rect.position;p.size=rect.size
	var s: StyleBoxFlat=StyleBoxFlat.new();s.bg_color=Color(color);s.border_color=Color("61745a");s.set_border_width_all(1);s.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel",s);return p

func _label(text: String, rect: Rect2, parent: Node=self, font_size: int=17, color: String="ecedd5") -> Label:
	var l: Label=Label.new();parent.add_child(l);l.position=rect.position;l.size=rect.size;l.text=text
	l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",Color(color));l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, rect: Rect2, callback: Callable, parent: Node=self) -> Button:
	var b: Button=Button.new();parent.add_child(b);b.position=rect.position;b.size=rect.size;b.text=text;b.pressed.connect(callback)
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;return b

func _icon(pos: Vector2, region: Rect2, parent: Node=self) -> void:
	var icon: TextureRect=TextureRect.new();parent.add_child(icon);icon.position=pos;icon.size=Vector2(28,28)
	var atlas: AtlasTexture=AtlasTexture.new();atlas.atlas=ICONS;atlas.region=region;icon.texture=atlas
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _atlas(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture=AtlasTexture.new();atlas.atlas=sheet;atlas.region=region
	return atlas

func _toolbar_icon(button: Button, icon: Texture2D) -> void:
	button.icon=icon
	button.expand_icon=true
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
	button.add_theme_constant_override("icon_max_width",24)
	button.add_theme_constant_override("h_separation",2)
	button.add_theme_font_size_override("font_size",14)
	button.position.y=777;button.size.y=86

func _build() -> void:
	var bg: ColorRect=ColorRect.new();add_child(bg);bg.color=Color("14271f");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_label("MEADOW WATCH",Rect2(32,18,330,26),self,16,"adbd90")
	_label("麦野守望",Rect2(30,45,350,56),self,37,"f3e6be")
	_label("春日农场 / 守住土地，也守住日常",Rect2(33,105,550,28),self,17,"a7b69a")
	weather_label=_label("",Rect2(495,105,525,35),self,17,"d7d9ac")
	mail_button=_button("信箱",Rect2(1034,102,174,41),func() -> void: _menu("mailbox"))
	map_button=_button("去村庄 →",Rect2(1220,102,184,41),func() -> void: _switch_map("village" if current_map=="farm" else "farm"))
	hud=_label("",Rect2(495,36,730,45),self,23,"f2dfad")
	_icon(Vector2(458,46),Rect2(16,96,16,16))
	_button("菜单",Rect2(1292,34,112,46),func() -> void: _menu("options"))
	undo_button=_button("撤回",Rect2(1145,34,132,46),_undo)
	undo_button.tooltip_text="撤回当天上一步成功操作 · Ctrl+Z"
	_panel(Rect2(30,155,980,574),self,"6a8456")
	farm=View.new();add_child(farm);farm.position=Vector2(40,166);farm.size=Vector2(960,552);farm.state=state
	farm.plot_clicked.connect(_on_plot);farm.place_clicked.connect(_on_place)
	farm.tree_clicked.connect(_on_tree)
	farm.hovered.connect(func(text: String) -> void: hint.text=text)
	farm.hover_info.connect(_show_hover)
	village_map=load("res://scenes/village.tscn").instantiate();village_map.state=state
	add_child(village_map);village_map.position=farm.position;village_map.hide()
	village_map.place_clicked.connect(_on_place);village_map.person_clicked.connect(_open_person)
	village_map.hover_info.connect(_show_hover)
	hint=_label("",Rect2(42,727,968,31),self,16,"bccca3")
	hint.size.x=625
	seed_label=_label("",Rect2(680,732,325,30),self,17,"f3dfb0")
	seed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	# Right-hand journal: orders, pressure and story goal remain visible together.
	_panel(Rect2(1034,155,370,574))
	_icon(Vector2(1056,174),Rect2(0,16,16,16))
	_label("今天的订单",Rect2(1092,170,280,36),self,23,"f3dfb0")
	for i: int in range(2):
		order_labels.append(_label("",Rect2(1058,222+i*106,322,68),self,16))
		order_buttons.append(_button("交付",Rect2(1252,284+i*106,126,37),_deliver.bind(i)))
	_label("土地守望",Rect2(1058,438,312,36),self,23,"f3dfb0")
	progress=ProgressBar.new();add_child(progress);progress.position=Vector2(1058,487);progress.size=Vector2(320,18);progress.max_value=20;progress.show_percentage=false
	var fill: StyleBoxFlat=StyleBoxFlat.new();fill.bg_color=Color("c6d38a");fill.set_corner_radius_all(5)
	var back: StyleBoxFlat=StyleBoxFlat.new();back.bg_color=Color("14271f");back.set_corner_radius_all(5)
	progress.add_theme_stylebox_override("fill",fill);progress.add_theme_stylebox_override("background",back)
	news=_label("",Rect2(1058,511,320,83),self,14,"bfc9a9");news.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	event_label=_label("",Rect2(1058,600,320,44),self,14,"d5c69f")
	_button("调查 / 证据册",Rect2(1058,652,174,46),func() -> void: _menu("investigate"))
	_button("公开真相",Rect2(1244,652,136,46),func() -> void: _menu("expose"))
	# Action toolbar: plot tools are selected; location activities run immediately.
	_panel(Rect2(30,773,1374,95),self,"2c4434")
	var names: Array[String]=["开垦","播种","浇水","收获"]
	var actions: Array[String]=["till","plant","water","harvest"]
	for i: int in range(4):
		var b: Button=_button(names[i]+"\n%d AP" % state.cost(actions[i]),Rect2(43+i*100,786,91,66),_select_tool.bind(actions[i]))
		tool_buttons.append(b)
		_toolbar_icon(b,_atlas(TOOL_ITEMS,Rect2(32,0,16,16)) if i==0 else (_atlas(CROP_ITEMS,Rect2(0,32,16,16)) if i==1 else (_atlas(TOOL_ITEMS,Rect2(0,0,16,16)) if i==2 else _atlas(CROP_ITEMS,Rect2(16,16,16,16)))))
	seed_button=_button("种子",Rect2(446,786,76,66),func() -> void: _menu("seeds"))
	seed_button.add_theme_font_size_override("font_size",15)
	_toolbar_icon(seed_button,_atlas(CROP_ITEMS,Rect2(16,32,16,16)))
	for i: int in range(4):
		var action: String=["fish","mine","cook","feed"][i]
		activity_buttons.append(_button(["钓鱼","挖矿","烹饪","饲养"][i]+"\n%d AP" % state.cost(action),Rect2(540+i*100,786,91,66),_activity.bind(action)))
		_toolbar_icon(activity_buttons[i],[FISH_ICON,_atlas(TOOL_ITEMS,Rect2(16,0,16,16)),COOK_ICON,_atlas(ALL_ITEMS,Rect2(48,176,16,16))][i])
	var bag_button: Button=_button("背包",Rect2(948,786,91,66),func() -> void: _menu("bag"))
	_toolbar_icon(bag_button,BAG_ICON)
	var shop_button: Button=_button("杂货铺",Rect2(1048,786,91,66),func() -> void: _menu("shop"))
	_toolbar_icon(shop_button,_atlas(ICONS,Rect2(32,96,16,16)))
	var rest_button: Button=_button("结束今天 →",Rect2(1160,786,224,66),func() -> void: _menu("rest"))
	rest_button.theme_type_variation=&"PrimaryButton"
	village_bar=Control.new();add_child(village_bar);village_bar.position=Vector2(43,786);village_bar.size=Vector2(888,66);village_bar.hide()
	for i: int in range(4):
		var kind: String=["villagers","requests","noticeboard","mailbox"][i]
		_button(["村民名单","邻里互助","公告栏","信箱"][i],Rect2(i*224,0,211,66),func() -> void: _menu(kind),village_bar)
	status=_label("春天来了。先收获一株成熟的胡萝卜吧。",Rect2(34,869,1340,28),self,16,"d7d0ad")
	# Modal layer consumes pointer input so clicks never reach farmland underneath.
	shade=ColorRect.new();add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.04,0.08,0.05,0.78);shade.visible=false
	modal=_panel(Rect2(280,139,880,622),shade,"283e31")
	modal_title=_label("",Rect2(30,21,620,50),modal,27,"f2dfb0")
	modal_undo_button=_button("撤回",Rect2(651,20,127,46),_undo,modal)
	_button("×",Rect2(792,20,56,46),_close,modal)
	modal_body=Control.new();modal.add_child(modal_body);modal_body.position=Vector2(30,91);modal_body.size=Vector2(820,506)
	hover_panel=_panel(Rect2(0,0,390,148),self,"1c3429")
	hover_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hover_label=_label("",Rect2(16,10,358,130),hover_panel,17)
	hover_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hover_panel.hide()

func _show_hover(text: String, point: Vector2, available: bool) -> void:
	if hover_panel==null: return
	if text.is_empty() or shade.visible:
		hover_panel.hide();return
	hover_label.text=text
	hover_label.add_theme_color_override("font_color",Color("f2dfb0") if available else Color("edb49b"))
	var pos: Vector2=farm.position+point+Vector2(24,24)
	if pos.x+hover_panel.size.x>size.x-12: pos.x=farm.position.x+point.x-hover_panel.size.x-20
	if pos.y+hover_panel.size.y>size.y-12: pos.y=farm.position.y+point.y-hover_panel.size.y-20
	hover_panel.position=pos.clamp(Vector2(12,12),size-hover_panel.size-Vector2(12,12))
	hover_panel.show()
	if selected_tool=="auto" and farm.selected>=0:
		var action: String=state.suggest_action(farm.selected)
		for i: int in range(4):
			tool_buttons[i].theme_type_variation=&"SelectedTool" if ["till","plant","water","harvest"][i]==action else &""

func _refresh() -> void:
	farm.selected_seed=selected_seed
	farm.update_hover(farm.get_local_mouse_position())
	for b: Button in [undo_button,modal_undo_button]:
		b.disabled=not state.can_undo()
		b.text="撤回 (%d)" % state.undo_history.size()
	hud.text="第 %02d 天    %s    金币 %d    AP %d / %d" % [state.day,state.weather,state.gold,state.ap,state.max_ap]
	weather_label.text="天气预报 · 明日 %s / 后天 %s"%[Village.forecast(state.day+1),Village.forecast(state.day+2)]
	mail_button.text="信箱 · 未读 %d"%Village.unread(state)
	progress.value=state.evidence
	news.text="证据 %d/20 · 声望 %d · 保护 %d\n收购期限：%d 天\n公司：%s\n连续未交付：%d/5 天"%[state.evidence,state.reputation,state.village.guards,maxi(0,26-state.day),state.event if not state.event.is_empty() else "暂无干扰",state.missed]
	event_label.text=Village.summary(state)
	if event_label.text.is_empty(): event_label.text="村庄事件：暂无 · 预告见信箱"
	for i: int in range(2):
		var o: Dictionary=state.orders[i]
		order_labels[i].text="%s\n%s ×%d   →   %d 金币 +1 声望" % [o.client,state.item_name(o.key),o.count,o.reward]
		order_buttons[i].text="已交付 ✓" if o.done else "交付 (%d/%d)" % [state.inventory[o.key],o.count]
		order_buttons[i].disabled=o.done or state.inventory[o.key]<o.count or not state.outcome.is_empty()
	for i: int in range(4):
		var action: String=["till","plant","water","harvest"][i]
		tool_buttons[i].theme_type_variation=&"SelectedTool" if selected_tool==action else &""
		tool_buttons[i].text=("● " if selected_tool==action else "")+["开垦","播种","浇水","收获"][i]+"\n%d AP" % state.cost(action)
	tool_buttons[1].tooltip_text="当前种子：%s · 剩余 %d" % [state.CROPS[selected_seed].name,state.seeds[selected_seed]]
	seed_label.text="当前种子：%s · 剩余 %d 颗" % [state.CROPS[selected_seed].name,state.seeds[selected_seed]]
	seed_button.text="%s\n%d 颗" % [state.CROPS[selected_seed].name,state.seeds[selected_seed]]
	var item_row: int=state.CROPS[selected_seed].row
	seed_button.icon=_atlas(CROP_ITEMS,Rect2(16,item_row*16,16,16))
	tool_buttons[1].icon=_atlas(CROP_ITEMS,Rect2(0,item_row*16,16,16))
	seed_button.tooltip_text="点击切换种子"
	for i: int in range(4):
		activity_buttons[i].text=["钓鱼","挖矿","烹饪","饲养"][i]+"\n%d AP" % state.cost(["fish","mine","cook","feed"][i])
	farm.queue_redraw()
	if village_map!=null: village_map.queue_redraw()

func _message(text: String) -> void:
	status.text=text

func _sound() -> void:
	if not muted and not testing and not capture: effect.pitch_scale=randf_range(0.95,1.1);effect.play()

func _select_tool(action: String) -> void:
	selected_tool=action;farm.tool=action;_refresh()
	status.text="手动%s（仅下一次）。之后恢复智能农事。当前种子：%s。" % [{"till":"锄头","plant":"播种","water":"洒水壶","harvest":"收获"}[action],state.CROPS[selected_seed].name]

func _on_plot(index: int) -> void:
	var action: String=state.suggest_action(index) if selected_tool=="auto" else selected_tool
	var done: bool=state.plot_action(index,action,selected_seed)
	selected_tool="auto";farm.tool="auto";_refresh()
	if done: _sound();_autosave()

func _on_tree(index: int) -> void:
	if state.act("chop",index): _sound();_autosave()

func _on_place(place: String) -> void:
	if place in ["farm","village"]: _switch_map(place)
	elif place in ["investigate","mailbox","villagers","shop","noticeboard","tavern"]: _menu(place)
	else: _activity(place)

func _activity(action: String) -> void:
	if action=="feed" and state.chickens==0: _shop_page("animals");return
	if state.act(action): _sound();_autosave()

func _switch_map(destination: String) -> void:
	_close();current_map=destination
	farm.visible=destination=="farm";village_map.visible=destination=="village"
	farm.hover_active=false;village_map.hover_active=false;hover_panel.hide()
	for b: Button in tool_buttons+activity_buttons: b.visible=destination=="farm"
	seed_button.visible=destination=="farm";seed_label.visible=destination=="farm"
	village_bar.visible=destination=="village"
	map_button.text="返回农场 →" if destination=="village" else "去村庄 →"
	hint.text="点击村民聊天、赠礼；也可用村民名单快速找到他们。" if destination=="village" else "点击地块耕作，左上树林可砍伐；村口通往村庄。"
	status.text="来到村庄。切换场景不消耗 AP。" if destination=="village" else "回到农场。切换场景不消耗 AP。"
	_refresh()

func _open_person(index: int) -> void:
	focus_person=index;_menu("neighbor")

func _deliver(index: int) -> void:
	if state.deliver(index): _sound();_autosave()

func _autosave() -> void:
	if testing or capture: return
	var old_text: String=status.text
	if state.save_game(): status.text=old_text

func _clear_modal() -> void:
	hover_panel.hide()
	modal.position.y=139;modal.size.y=622;modal_body.size.y=506
	for child: Node in modal_body.get_children():
		modal_body.remove_child(child);child.queue_free()

func _close() -> void:
	shade.hide();current_menu=""
	village_map.paused=false

func _story(title: String, text: String) -> void:
	_clear_modal();current_menu="story";shade.show();modal_title.text=title
	village_map.paused=true
	var l: Label=_label(text,Rect2(10,0,795,412),modal_body,20);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button("开始新的守望" if not state.outcome.is_empty() else "继续 →",Rect2(552,433,248,55),func() -> void:
		if not state.outcome.is_empty(): _new_game()
		else: _close(),modal_body)

func _menu(kind: String) -> void:
	_clear_modal();current_menu=kind;shade.show()
	village_map.paused=true
	match kind:
		"seeds":
			modal_title.text="种子袋 · 选择下一次播种的作物"
			_label("浇水后结束一天才会生长；小雨会自动灌溉。",Rect2(0,0,800,35),modal_body,17,"bfcea7")
			for i: int in range(8):
				var crop: Dictionary=state.CROPS[i]
				_button("%s%s · 剩余 %d 颗\n%s" % ["● " if i==selected_seed else "",crop.name,state.seeds[i],state.crop_cycle_text(i)],Rect2(i%2*411,48+i/2*98,398,86),_seed.bind(i),modal_body)
		"bag":
			_build_bag()
		"shop":
			_build_shop()
		"mailbox": _build_mailbox()
		"villagers": _build_villagers()
		"person": _build_person()
		"requests": _build_requests()
		"chains": _build_chains()
		"neighbor": _build_neighbor()
		"noticeboard": _build_noticeboard()
		"tavern": _build_tavern()
		"investigate":
			modal_title.text="小林的证据册 · %d / 20" % state.evidence
			_label("每处每天一次 · 消耗 4 AP · 第 11 天起证据产出增加",Rect2(0,0,800,32),modal_body,17,"bfcea7")
			for i: int in range(3):
				var b: Button=_button(state.CLUES[i]+(" · 今日已调查" if state.investigated.has(i) else " · 调查 →"),Rect2(0,44+i*58,802,49),_investigate.bind(i),modal_body)
				b.disabled=state.investigated.has(i) or not state.outcome.is_empty()
			_button("赠礼换线索",Rect2(0,225,391,48),func() -> void: _menu("gifts"),modal_body)
			_button("关联证据 · 拼合真相",Rect2(411,225,391,48),func() -> void: _menu("chains"),modal_body)
			var scroll: ScrollContainer=ScrollContainer.new();modal_body.add_child(scroll);scroll.position=Vector2(0,291);scroll.size=Vector2(802,196)
			var list: VBoxContainer=VBoxContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var entries: Array=state.archive.duplicate();entries.reverse()
			if entries.is_empty(): entries.append("暂无记录。河岸、矿洞和村口都值得调查。")
			for entry: String in entries:
				var l: Label=Label.new();list.add_child(l);l.text=entry;l.custom_minimum_size.x=765;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",16)
		"gifts":
			modal_title.text="村民赠礼 · 获取调查线索"
			var chance: int=state.gift_chance()
			_label("今日尝试 %d / 3 · %s\n每次赠出 1 份物资，0 AP；成功获得 %d 份证据。\n声望加成 +%d 个百分点；成功后当天停止。"%[state.gift_attempts,"今日已成功" if state.gift_success else "下一次成功率 %d%%"%chance,3 if state.day>=11 else 2,state.reputation],Rect2(0,0,810,103),modal_body,18,"f2dfb0")
			var keys: Array[String]=["0","1","2","3","4","5","6","7","egg","fish","ore"]
			for i: int in range(keys.size()):
				var key: String=keys[i]
				var b: Button=_button("%s ×%d · 赠出 1"%[state.item_name(key),state.inventory[key]],Rect2(i%3*273,122+i/3*71,260,59),_donate.bind(key),modal_body)
				b.icon=_item_texture(key);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",22);b.add_theme_font_size_override("font_size",16)
				b.disabled=state.inventory[key]<=0 or state.gift_success or state.gift_attempts>=3 or not state.outcome.is_empty()
			_button("返回证据册",Rect2(0,433,806,50),func() -> void: _menu("investigate"),modal_body)
		"expose":
			modal_title.text="让真相被看见"
			var l: Label=_label("收集 20 份证据后，选择你希望争取的结局。\n当前：%d / 20 份。\n\n曝光会结束当前故事。" % state.evidence,Rect2(0,0,800,170),modal_body,21);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			for i: int in range(3):
				var b: Button=_button(["向媒体曝光 · 小林公开报道","向监管部门举报 · 调查污染与违规","与公司谈判 · 保留土地、接受和解"][i],Rect2(0,208+i*81,802,64),_expose.bind(i),modal_body)
				b.disabled=state.evidence<20 or not state.outcome.is_empty()
		"rest":
			modal_title.text="收起工具，明天再见"
			var dry: int=0
			for p: Dictionary in state.plots:
				if p.crop>=0 and not state.is_moist(p) and p.growth<state.growth_target(p): dry+=1
			_label("今天还剩 %d AP。\n\n未浇水的生长中作物：%d 株\n今日订单：%s\n夜间维护：8 金币\n\n结束后恢复至 %d AP，已浇水的作物生长一天。" % [state.ap,dry,"至少已交付 1 份" if state.delivered else "尚未交付",state.max_ap],Rect2(0,0,800,330),modal_body,22)
			_button("再忙一会儿",Rect2(0,409,382,60),_close,modal_body)
			_button("结束今天 →",Rect2(414,409,388,60),_rest,modal_body)
		"options":
			modal_title.text="麦野守望 · 菜单"
			for i: int in range(4):
				_button(["保存进度","读取存档","重新开始","打开存档目录"][i],Rect2(i%2*411,i/2*83,398,65),[_save,_load,_confirm_new,_open_save_folder][i],modal_body)
			_button("音效与音乐："+("关闭" if muted else "开启"),Rect2(0,184,398,60),_toggle_sound,modal_body)
			_button("玩法说明",Rect2(411,184,398,60),_help,modal_body)
			_label("目标：25 天内集齐 20 份证据并主动曝光。\n基础每日 10 AP；商店可提升上限，维护费 8 金币。\n金币不足 / 连续 5 天无订单 / 收购到期会失败。\n自动存档会在每次成功行动后更新；新游戏不会立即覆盖旧档。\n\n美术：Sprout Lands · Cup Nooble\n引擎：Godot 4.7.2 · 音乐与音效：程序合成\nEsc 关闭窗口 · 1–4 切换工具 · F5 保存 · F9 读取",Rect2(0,267,815,221),modal_body,17,"bfcea7")

func _item_texture(key: String) -> Texture2D:
	if key.is_valid_int(): return _atlas(CROP_ITEMS,Rect2(16,state.CROPS[int(key)].row*16,16,16))
	match key:
		"fish": return FISH_ITEM
		"ore": return _atlas(TOOL_ITEMS,Rect2(48,32,16,16))
		"wood": return _atlas(TOOL_ITEMS,Rect2(0,32,16,16))
		"egg": return _atlas(ALL_ITEMS,Rect2(48,176,16,16))
	return COOK_ICON

func _item_picture(key: String, pos: Vector2, parent: Node, dimensions: Vector2=Vector2(32,32)) -> void:
	var icon: TextureRect=TextureRect.new();parent.add_child(icon)
	icon.position=pos;icon.size=dimensions;icon.texture=_item_texture(key)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _inventory_card(key: String, rect: Rect2) -> void:
	var card: Panel=_panel(rect,modal_body,"324e3b")
	_item_picture(key,Vector2((rect.size.x-32)/2,10),card)
	var name_label: Label=_label(state.item_name(key),Rect2(0,45,rect.size.x,24),card,15)
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var count: Label=_label("× %d"%state.inventory[key],Rect2(0,70,rect.size.x,25),card,19,"f2dfb0")
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var price: int=state.selling_price(key)
	var b: Button=_button("出售 %d金"%price if rect.size.x<120 else "出售 1 份 · %d 金币"%price,Rect2(6,rect.size.y-48,rect.size.x-12,40),_bag_action.bind(key),card)
	b.tooltip_text="出售 1 份%s，获得 %d 金币"%[state.item_name(key),price]
	b.add_theme_font_size_override("font_size",14)
	b.disabled=state.inventory[key]<=0 or not state.outcome.is_empty()

func _build_bag() -> void:
	modal.position.y=119;modal.size.y=662;modal_body.size.y=546
	modal_title.text="背包 · 分类物资"
	_label("作物 · 出售按钮标注每份实际售价"+("（市场打压 -30%）" if state.event=="市场打压" else ""),Rect2(0,0,806,30),modal_body,20,"f2dfb0")
	for i: int in range(8): _inventory_card(str(i),Rect2(i*102,36,96,154))
	_label("鸡蛋 / 鲜鱼 / 矿石 / 木材",Rect2(0,202,800,30),modal_body,21,"f2dfb0")
	for i: int in range(4): _inventory_card(["egg","fish","ore","wood"][i],Rect2(i*205,239,193,150))
	_label("食物 · 当前 AP %d / %d"%[state.ap,state.max_ap],Rect2(0,401,800,30),modal_body,21,"f2dfb0")
	var food: Panel=_panel(Rect2(0,439,806,82),modal_body,"324e3b")
	_item_picture("meal",Vector2(18,22),food,Vector2(38,38))
	_label("田园热饭 × %d"%state.inventory.meal,Rect2(72,10,260,30),food,20)
	_label("每份恢复 5 AP（不超过上限）",Rect2(72,43,430,25),food,16,"bfcea7")
	var eat: Button=_button("食用 · +5 AP",Rect2(572,17,218,50),func() -> void: _bag_action("meal"),food)
	eat.disabled=state.inventory.meal<=0 or state.ap>=state.max_ap or not state.outcome.is_empty()

func _shop_page(page: String) -> void:
	shop_tab=page;_menu("shop")

func _shop_purchase(kind: String) -> void:
	var ok: bool=state.buy_capacity() if kind=="capacity" else (state.buy_chicken() if kind=="chicken" else state.buy_meal())
	if ok: _sound();_autosave()
	_menu("shop")

func _donate(key: String) -> void:
	if state.donate(key):
		_sound();_autosave()
		if not state.gift_success: _menu("gifts")

func _build_shop() -> void:
	modal.position.y=99;modal.size.y=702;modal_body.size.y=586
	modal_title.text="杂货铺 · 声望 %d / 优惠 %d%%"%[state.reputation,mini(100,state.reputation)]
	_label("当前金币：%d   |   当前矿石：%d   |   木材：%d   |   AP：%d / %d"%[state.gold,state.inventory.ore,state.inventory.wood,state.ap,state.max_ap],Rect2(0,0,810,32),modal_body,17,"f2dfb0")
	for i: int in range(5):
		var page: String=["seeds","tools","energy","rumors","animals"][i]
		var b: Button=_button(["种子","农具升级","体力与食物","小道消息","购买小鸡"][i],Rect2(i*164,42,154,43),_shop_page.bind(page),modal_body)
		b.theme_type_variation=&"PrimaryButton" if page==shop_tab else &""
		b.add_theme_font_size_override("font_size",16)
	match shop_tab:
		"seeds":
			for i: int in range(8):
				var crop: Dictionary=state.CROPS[i]
				var b: Button=_button("%s · 持有 %d 颗 · ×3 / %d 金\n%s"%[crop.name,state.seeds[i],state.seed_price(i),state.crop_cycle_text(i)],Rect2(i%2*411,102+i/2*68,398,62),_buy.bind(i),modal_body)
				b.disabled=state.gold<state.seed_price(i) or not state.outcome.is_empty()
			_label("声望 %d · 商店优惠 %d%%。购买不消耗 AP。"%[state.reputation,mini(100,state.reputation)],Rect2(0,395,810,35),modal_body,17,"bfcea7")
		"tools":
			for i: int in range(4):
				var level: int=state.tools[i]
				var card: Panel=_panel(Rect2(i%2*411,103+i/2*174,398,160),modal_body,"324e3b")
				_label("%s · Lv.%d / 5"%[["锄头","洒水壶","鱼竿","镐子"][i],level],Rect2(14,9,370,30),card,21,"f2dfb0")
				_label("当前："+state.tool_effect(i),Rect2(14,45,370,25),card,16)
				_label("已达到最高等级" if level>=5 else "升级后："+state.tool_effect(i,level+1),Rect2(14,76,370,25),card,16,"c5d88b")
				var b: Button=_button("已满级" if level>=5 else "升级 · %d 金币 + %d 矿石 + %d 木材"%[state.shop_price(20*level),3*level,2*level],Rect2(12,112,374,40),_upgrade.bind(i),card)
				b.add_theme_font_size_override("font_size",16)
				b.add_theme_font_size_override("font_size",16)
				b.disabled=level>=5 or state.gold<state.shop_price(20*level) or state.inventory.ore<3*level or state.inventory.wood<2*level or not state.outcome.is_empty()
			_label("批量开垦 / 浇水：从点击格向右，限同一行。",Rect2(0,447,810,30),modal_body,17,"bfcea7")
			_button("稻草人 · 2 AP + %d 金币 + 2 矿石"%state.shop_price(25),Rect2(0,490,482,48),func() -> void:
				_activity("scarecrow");_menu("shop"),modal_body)
			_button("安慰动物 · 2 AP",Rect2(501,490,305,48),func() -> void:
				_activity("comfort");_menu("shop"),modal_body)
		"energy":
			var capacity: Panel=_panel(Rect2(0,103,398,248),modal_body,"324e3b")
			_label("永久提升 AP 上限",Rect2(16,14,368,34),capacity,23,"f2dfb0")
			_label("当前上限：%d / %d\n每次 +2，当前 AP 也 +2\n以后每天恢复至新上限"%[state.max_ap,state.MAX_AP_LIMIT],Rect2(16,62,365,99),capacity,18)
			var b: Button=_button("已达到上限" if state.max_ap>=state.MAX_AP_LIMIT else "购买 +2 上限 · %d 金币"%state.capacity_price(),Rect2(14,184,370,48),_shop_purchase.bind("capacity"),capacity)
			b.disabled=state.max_ap>=state.MAX_AP_LIMIT or state.gold<state.capacity_price() or not state.outcome.is_empty()
			var food: Panel=_panel(Rect2(411,103,398,248),modal_body,"324e3b")
			_item_picture("meal",Vector2(16,16),food)
			_label("田园热饭 · +5 AP",Rect2(62,14,322,34),food,22,"f2dfb0")
			_label("持有 %d 份\n购买后在背包中食用\n可反复购买，不超过 AP 上限"%state.inventory.meal,Rect2(16,62,365,99),food,18)
			b=_button("购买 1 份 · %d 金币"%state.shop_price(state.MEAL_PRICE),Rect2(14,184,370,48),_shop_purchase.bind("meal"),food)
			b.disabled=state.gold<state.shop_price(state.MEAL_PRICE) or not state.outcome.is_empty()
			_label("上限基础价 100 起，每次加价 50；最高 30 AP。\n声望 %d · 优惠 %d%%；金币向上取整，最低 1 金币。"%[state.reputation,mini(100,state.reputation)],Rect2(0,378,810,86),modal_body,19,"bfcea7")
			_button("打开背包 · 食用热饭",Rect2(0,485,806,52),func() -> void: _menu("bag"),modal_body)
		"rumors":
			_label("提前知道变化，给农场留出准备时间",Rect2(0,106,810,36),modal_body,23,"f2dfb0")
			var bought: bool=state.village.rumor_day==state.day
			var b: Button=_button("今日已购买" if bought else "购买一条消息 · %d 金币（每天限 1 条）"%state.shop_price(12),Rect2(0,158,806,55),func() -> void: _village_action("buy_rumor"),modal_body)
			b.disabled=bought or Village.next_unknown(state).is_empty() or state.gold<state.shop_price(12) or not state.outcome.is_empty()
			var preview: String=Village.preview(state)
			var l: Label=_label("已经听到的预告：\n"+(preview if not preview.is_empty() else "暂无。可以与村民对话或等待来信。")+"\n\n当前事件：\n"+(Village.summary(state) if not state.village.active.is_empty() else "暂无"),Rect2(0,238,806,228),modal_body,19,"bfcea7")
			l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			_button("去信箱阅读",Rect2(0,492,806,50),func() -> void: _menu("mailbox"),modal_body)
		"animals":
			_label("动物小院 · 小鸡 %d / 4 只"%state.chickens,Rect2(0,110,806,42),modal_body,26,"f2dfb0")
			_wrapped("先购买小鸡，再喂养收蛋。\n每只产 1 个蛋，最多养 4 只。\n整群每天喂养一次：3 AP + 4 金币，不随数量增加。\n噪声会减产，可在喂养前安慰动物。\n小鸡购买不消耗 AP，享受声望折扣。",Rect2(0,177,806,195),modal_body,21)
			var b: Button=_button("已达到 4 只上限" if state.chickens>=4 else "购买 1 只 · %d 金币"%state.shop_price(state.CHICKEN_PRICE),Rect2(0,401,806,58),_shop_purchase.bind("chicken"),modal_body)
			b.disabled=state.chickens>=4 or state.gold<state.shop_price(state.CHICKEN_PRICE) or not state.outcome.is_empty()
			b=_button("饲养整群 · 3 AP + 4 金币",Rect2(0,488,806,52),func() -> void: _activity("feed");_menu("shop"),modal_body)
			b.disabled=state.chickens==0 or state.fed or state.ap<3 or state.gold<4 or not state.outcome.is_empty()

func _build_neighbor() -> void:
	var index: int=maxi(0,focus_person)
	var p: Dictionary=Village.PEOPLE[index];var bond: Dictionary=state.village.people[p.id]
	modal_title.text=p.name+" · 路边相遇"
	_label(_stars(int(bond.points))+"  %s/5 星"%str(float(bond.points)/Village.POINTS_PER_STAR),Rect2(0,0,806,42),modal_body,25,"eac476")
	_wrapped(Village.Dialogue.line(state,index).split("\n\n")[0]+"\n\n喜欢：%s\n不喜欢：%s"%[_preference(p.likes),_preference(p.dislikes)],Rect2(0,68,806,147),modal_body,20)
	_wrapped("全村今日还剩 %d 次免费聊天。\n"%Village.free_talks(state)+("今日对话好感已获得，再聊不会增加好感。" if bond.talk_day==state.day else "今日首次对话，好感 +0.25 星。"),Rect2(0,227,806,73),modal_body,19)
	var cost: int=Village.talk_cost(state)
	var b: Button=_button("聊天 · 免费" if cost==0 else "聊天 · 1 AP",Rect2(0,322,398,58),_village_action.bind("talk",index),modal_body)
	b.disabled=state.ap<cost or not state.outcome.is_empty()
	b=_button("今日已赠礼" if bond.gift_day==state.day else "选择礼物",Rect2(411,322,398,58),_select_person.bind(index),modal_body)
	b.disabled=bond.gift_day==state.day or not state.outcome.is_empty()
	_button("查看邻里互助",Rect2(0,425,398,53),func() -> void: _menu("requests"),modal_body)
	_button("继续逛村庄",Rect2(411,425,398,53),_close,modal_body)

func _build_tavern() -> void:
	modal_title.text="村庄酒馆 · 窗边有空位"
	_wrapped("木桌上留着几个杯子，窗外能看见村里的路。\n有人刚收完菜，有人合上账本。坐下来，听听他们今天的事。",Rect2(0,0,806,137),modal_body,23,"ecedd5")
	_wrapped("喝一杯 · 1 AP\n随机与 2～3 位不同村民拉近关系，各 +0.25 星。\n独立于每日首次对话，不占免费聊天次数。\n每次听到一条小道消息，优先告诉你未知的预告；\n没有新预告时，会聊起已知消息或天气。",Rect2(0,168,806,176),modal_body,19)
	var b: Button=_button("坐下喝一杯 · 1 AP",Rect2(0,381,806,55),_village_action.bind("drink"),modal_body)
	b.disabled=state.ap<1 or not state.outcome.is_empty()
	_button("去信箱看消息",Rect2(0,452,398,45),func() -> void: _menu("mailbox"),modal_body)
	_button("回到村庄",Rect2(411,452,398,45),_close,modal_body)

func _build_noticeboard() -> void:
	_large_modal();modal_title.text="村庄公告栏 · 今天的安排"
	_label("天气 · 明日 %s / 后天 %s"%[Village.forecast(state.day+1),Village.forecast(state.day+2)],Rect2(0,0,806,36),modal_body,22,"f2dfb0")
	for i: int in range(2):
		var order: Dictionary=state.orders[i]
		var card: Panel=_panel(Rect2(i*411,55,398,127),modal_body,"324e3b")
		_label(order.client,Rect2(14,9,370,30),card,20,"f2dfb0")
		_label("%s ×%d · 持有 %d · 奖励 %d 金币"%[state.item_name(order.key),order.count,state.inventory[order.key],order.reward],Rect2(14,44,370,25),card,16)
		var b: Button=_button("已完成 ✓" if order.done else "交付订单",Rect2(14,79,370,36),func() -> void: _deliver(i);_menu("noticeboard"),card)
		b.disabled=order.done or state.inventory[order.key]<order.count or not state.outcome.is_empty()
	var request: Dictionary=state.village.request
	_wrapped("邻里互助："+("暂无" if request.is_empty() else "%s · %s ×%d · 第%d天截止 · %s"%[request.sender,state.item_name(request.key),request.count,request.deadline,"已完成" if request.done else "待交付"]),Rect2(0,206,806,38),modal_body,20)
	_button("邻里互助",Rect2(0,244,260,45),func() -> void: _menu("requests"),modal_body)
	_wrapped("当前事件：\n"+(Village.summary(state) if not state.village.active.is_empty() else "暂无")+"\n\n已经听到的预告：\n"+(Village.preview(state) if not Village.preview(state).is_empty() else "暂无，去与村民聊聊吧。"),Rect2(0,305,806,208),modal_body,19)
	_button("查看信箱",Rect2(0,531,398,45),func() -> void: _menu("mailbox"),modal_body)
	_button("村民名单",Rect2(411,531,398,45),func() -> void: _menu("villagers"),modal_body)

func _large_modal() -> void:
	modal.position.y=99;modal.size.y=702;modal_body.size.y=586

func _wrapped(text: String, rect: Rect2, parent: Node, font_size: int=18, color: String="bfcea7") -> Label:
	var label: Label=_label(text,rect,parent,font_size,color)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return label

func _open_letter(id: int) -> void:
	selected_mail=id
	if Village.read_mail(state,id): _autosave()
	_menu("mailbox")

func _build_mailbox() -> void:
	_large_modal();modal_title.text="信箱 · 未读 %d / 共 %d 封"%[Village.unread(state),state.village.mail.size()]
	var letters: Array=state.village.mail.duplicate();letters.reverse()
	var chosen: Dictionary={}
	for letter: Dictionary in letters:
		if letter.id==selected_mail: chosen=letter
	var scroll: ScrollContainer=ScrollContainer.new();modal_body.add_child(scroll)
	scroll.position=Vector2(0,0);scroll.size=Vector2(274,501)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer=VBoxContainer.new();scroll.add_child(list)
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	for letter: Dictionary in letters:
		var b: Button=Button.new();list.add_child(b)
		b.custom_minimum_size=Vector2(252,82);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.text="%s第 %d 天 · %s\n%s"%["● " if not letter.read else "",letter.day,letter.sender,letter.title]
		b.add_theme_font_size_override("font_size",16)
		b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text=letter.title;b.pressed.connect(_open_letter.bind(int(letter.id)))
		if letter.id==selected_mail: b.theme_type_variation=&"PrimaryButton"
	var paper: Panel=_panel(Rect2(288,0,518,501),modal_body,"324e3b")
	if chosen.is_empty():
		_wrapped("选择左侧信件阅读。\n\n村民会寄来问候、互助请求、感谢和小道消息。\n\n好感度最高 5 星，每升一星都会收到纪念信。附件需要手动领取。",Rect2(22,24,474,300),paper,20)
	else:
		_wrapped(chosen.title,Rect2(22,16,474,68),paper,23,"f2dfb0")
		_label("%s · 第 %d 天"%[chosen.sender,chosen.day],Rect2(22,91,474,30),paper,17)
		_wrapped(chosen.body,Rect2(22,139,474,240),paper,19,"eadfbf")
		_label("附件："+Village.gift_text(state,chosen.gift),Rect2(22,398,474,30),paper,18,"f2dfb0")
		var b: Button=_button("已领取 ✓" if chosen.claimed else "领取附件",Rect2(22,440,474,45),_village_action.bind("collect",int(chosen.id)),paper)
		b.disabled=chosen.claimed or chosen.gift.is_empty() or not state.outcome.is_empty()
	_button("村民互助",Rect2(0,524,260,48),func() -> void: _menu("requests"),modal_body)
	_button("村民与好感",Rect2(273,524,260,48),func() -> void: _menu("villagers"),modal_body)
	_button("天气与小道消息",Rect2(546,524,260,48),func() -> void: _shop_page("rumors"),modal_body)

func _stars(points: int) -> String:
	var full: int=points/Village.POINTS_PER_STAR
	return "★".repeat(full)+"☆".repeat(Village.MAX_STARS-full)

func _preference(keys: Array) -> String:
	var names: PackedStringArray=[]
	for key: String in keys: names.append(state.item_name(key))
	return "、".join(names)

func _select_person(index: int) -> void:
	selected_person=index;_menu("person")

func _build_villagers() -> void:
	_large_modal();modal_title.text="村口 · 村民与好感度"
	_wrapped("全村免费聊天还剩 %d/3 次，之后每次 1 AP，次数不限。\n每人每日首次对话 +0.25 星；赠礼每天一次，0 AP。"%Village.free_talks(state),Rect2(0,0,806,55),modal_body,17)
	for i: int in range(Village.PEOPLE.size()):
		var p: Dictionary=Village.PEOPLE[i];var bond: Dictionary=state.village.people[p.id]
		var card: Panel=_panel(Rect2(i%2*411,65+i/2*227,398,215),modal_body,"324e3b")
		_label(p.name,Rect2(14,9,370,31),card,23,"f2dfb0")
		_label(_stars(int(bond.points))+"  %s/%d"%[str(float(bond.points)/Village.POINTS_PER_STAR),Village.MAX_STARS],Rect2(14,45,370,30),card,19,"eac476")
		_wrapped("喜欢：%s\n不喜欢：%s"%[_preference(p.likes),_preference(p.dislikes)],Rect2(14,85,370,59),card,17)
		var cost: int=Village.talk_cost(state)
		var b: Button=_button(("闲聊" if bond.talk_day==state.day else "对话")+(" · 免费" if cost==0 else " · 1 AP"),Rect2(14,157,177,45),_village_action.bind("talk",i),card)
		b.tooltip_text="今日对话好感已增加，仍可聊天。" if bond.talk_day==state.day else "今日首次对话，好感 +0.25 星。"
		b.disabled=state.ap<cost or not state.outcome.is_empty()
		b=_button("今日已赠礼" if bond.gift_day==state.day else "选择礼物",Rect2(204,157,177,45),_select_person.bind(i),card)
		b.disabled=bond.gift_day==state.day or not state.outcome.is_empty()
	_button("特殊请求 · 村民互助",Rect2(0,522,398,48),func() -> void: _menu("requests"),modal_body)
	_button("信箱 · 好感里程碑来信",Rect2(411,522,398,48),func() -> void: _menu("mailbox"),modal_body)

func _build_person() -> void:
	_large_modal()
	var p: Dictionary=Village.PEOPLE[selected_person];var bond: Dictionary=state.village.people[p.id]
	modal_title.text=p.name+" · 选择礼物"
	_wrapped("%s  %s / %d 星\n喜欢：%s；不喜欢：%s\n喜欢 +0.5 星、普通 +0.25 星、不喜欢 -0.25 星；对话 +0.25 星。"%[_stars(int(bond.points)),str(float(bond.points)/Village.POINTS_PER_STAR),Village.MAX_STARS,_preference(p.likes),_preference(p.dislikes)],Rect2(0,0,806,112),modal_body,19,"f2dfb0")
	var keys: Array[String]=["0","1","2","3","4","5","6","7","egg","fish","ore"]
	for i: int in range(keys.size()):
		var key: String=keys[i]
		var effect: String="♥ 喜欢" if p.likes.has(key) else ("不喜欢" if p.dislikes.has(key) else "普通")
		var b: Button=_button("%s ×%d\n%s · 赠出 1"%[state.item_name(key),state.inventory[key],effect],Rect2(i%3*273,135+i/3*82,260,72),_village_action.bind("gift",selected_person,key),modal_body)
		b.icon=_item_texture(key);b.expand_icon=true;b.add_theme_constant_override("icon_max_width",26);b.add_theme_font_size_override("font_size",17)
		b.disabled=state.inventory[key]<=0 or bond.gift_day==state.day or not state.outcome.is_empty()
	_label("每升一星寄信；3 星种子、4 星保护、5 星证据。里程碑不重复。",Rect2(0,477,806,30),modal_body,17)
	_button("返回村口",Rect2(0,523,806,48),func() -> void: _menu("villagers"),modal_body)

func _build_requests() -> void:
	modal_title.text="邻里互助 · 特殊请求"
	var r: Dictionary=state.village.request
	if r.is_empty():
		_label("暂时没有请求。过几天再来看看吧。",Rect2(0,0,806,80),modal_body,22)
	else:
		_label(r.sender+" 的请求",Rect2(0,0,806,40),modal_body,25,"f2dfb0")
		_item_picture(r.key,Vector2(0,69),modal_body,Vector2(48,48))
		_label("需要 %s ×%d · 持有 %d"%[state.item_name(r.key),r.count,state.inventory[r.key]],Rect2(64,73,735,45),modal_body,23)
		_wrapped("截止：第 %d 天结束（今天第 %d 天）\n完成后：好感 +0.5 星、声望 +1。\n感谢信可能附上种子、证据或抵挡一次破坏的保护。\n附件会寄到信箱，请记得领取。"%[r.deadline,state.day],Rect2(0,147,806,172),modal_body,21)
		var b: Button=_button("已完成 · 感谢信已寄出" if r.done else "交付物资 · 0 AP",Rect2(0,334,806,56),_village_action.bind("request"),modal_body)
		b.disabled=r.done or state.inventory[r.key]<r.count or state.day>r.deadline or not state.outcome.is_empty()
	_button("返回村口",Rect2(0,437,398,48),func() -> void: _menu("villagers"),modal_body)
	_button("去信箱领取谢礼",Rect2(411,437,398,48),func() -> void: _menu("mailbox"),modal_body)

func _build_chains() -> void:
	_large_modal();modal_title.text="证据关联 · 拼合真相"
	_label("调查得到原始记录；赠礼线索 / 来信证据得到旁证。关联成功 +1 证据。",Rect2(0,0,810,31),modal_body,17)
	for i: int in range(Village.CHAINS.size()):
		var chain: Dictionary=Village.CHAINS[i]
		var card: Panel=_panel(Rect2(0,44+i*150,806,139),modal_body,"324e3b")
		_label(chain.name,Rect2(14,9,590,32),card,23,"f2dfb0")
		var available: bool=true
		var cards: String=""
		for id: String in chain.cards:
			var owned: bool=state.village.cards.has(id);available=available and owned
			cards+=("✓ " if owned else "缺少：")+Village.CARDS[id]+"\n"
		_label(cards.trim_suffix("\n"),Rect2(14,53,561,69),card,18)
		var linked: bool=state.village.chains.has(chain.id)
		var b: Button=_button("已关联 ✓" if linked else "关联 · +1 证据",Rect2(594,62,196,50),_village_action.bind("chain",i),card)
		b.disabled=linked or not available or not state.outcome.is_empty()
	_label("关联记录与奖励只结算一次；无需 AP。",Rect2(0,501,810,30),modal_body,18)
	_button("返回调查证据册",Rect2(0,539,806,40),func() -> void: _menu("investigate"),modal_body)

func _village_action(kind: String, index: int=-1, key: String="") -> void:
	var ok: bool=false
	var destination: String=current_menu
	match kind:
		"talk": ok=Village.talk(state,index)
		"gift": ok=Village.gift(state,index,key)
		"request": ok=Village.complete_request(state)
		"collect": ok=Village.collect_mail(state,index)
		"chain": ok=Village.connect_chain(state,index)
		"buy_rumor": ok=Village.buy_rumor(state)
		"drink": ok=Village.drink(state)
	if ok: _sound();_autosave()
	if kind=="drink" and ok:
		_large_modal();modal_body.get_child(0).size.y=493
		modal_body.get_child(0).add_theme_font_size_override("font_size",18)
		modal_body.get_child(1).position.y=523
	if kind not in ["talk","drink"] or not ok: _menu(destination)

func _seed(index: int) -> void:
	selected_seed=index;selected_tool="auto";farm.tool="auto";_close();_refresh()
	status.text="当前种子：%s。智能农事会按地块状态选择操作。"%state.CROPS[selected_seed].name

func _bag_action(key: String) -> void:
	if key=="meal": _activity("eat")
	elif state.sell(key): _sound();_autosave()
	_menu("bag")

func _buy(index: int) -> void:
	if state.buy_seed(index): _sound();_autosave()
	_menu("shop")

func _upgrade(index: int) -> void:
	if state.upgrade(index): _sound();_autosave()
	_menu("shop")

func _investigate(index: int) -> void:
	if state.act("investigate",index): _sound();_autosave()

func _expose(channel: int) -> void:
	if state.expose(channel): _sound();_autosave()

func _rest() -> void:
	_close()
	if state.next_day(): _sound();_autosave()

func _undo() -> void:
	var previous_menu: String=current_menu
	if state.undo():
		_sound();_autosave()
		if shade.visible:
			if previous_menu in ["shop","bag","seeds","investigate","gifts","rest","expose","options","mailbox","villagers","person","requests","chains","neighbor","noticeboard","tavern"]: _menu(previous_menu)
			else: _close()

func _save() -> void:
	state.save_game();_close()

func _load() -> void:
	if state.load_game():
		_close()
		if not state.outcome.is_empty(): _story("麦野守望 · 终章",state.ending_text())

func _confirm_new() -> void:
	_story("重新开始", "将从第 1 天开始新的守望。现有存档在下次成功行动后被覆盖。")
	_button("确定重新开始",Rect2(0,433,400,55),_new_game,modal_body)

func _new_game() -> void:
	state.new_game();selected_tool="auto";farm.tool="auto";selected_seed=0;_switch_map("farm");_refresh();_help()

func _open_save_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))

func _toggle_sound() -> void:
	muted=not muted;music.stream_paused=muted;_menu("options")

func _help() -> void:
	_story("村长的田园手册", "① 智能农事：空地播种、作物浇水、成熟收获。开垦 2 AP / 播种 0 AP / 浇水 1 AP / 收获 2 AP。玉米、黄瓜两天再熟，南瓜保湿两天。\n\n② 新农场仅有胡萝卜种子 2 颗、小麦 1 颗和三株起步作物。小院起初为空，小鸡每只基础价 40、最多 4 只；整群每天花 3 AP + 4 金币收蛋，每只产 1 个蛋。\n\n③ 左上角四棵树可以砍伐：2 AP 得 3 木材，三天后恢复。木材每份基础售价 6 金币；农具升级还需每级 2 倍的木材，商店会显示全部费用。背包出售物资，商店可买热饭与永久 AP 上限。\n\n④ 农场和村庄免费切换。村民会散步，点击后可聊天、赠礼；也可用村民名单快速查找。全村每天前三次聊天免费，之后每次 1 AP 不限次数；每人每日首次对话 +0.25 星。赠礼每日一次，喜欢 +0.5 星，普通 +0.25 星，不喜欢 -0.25 星。好感最高 5 星，每升一星寄信。酒馆每次 1 AP，随机 2～3 位村民最多 +0.25 星，并听到一条消息，独立于首次对话。\n\n⑤ 互助完成 +0.5 星并寄谢礼，附件要在信箱领取。3 星信件送种子，4 星送保护，5 星送证据。保护抵挡一次破坏。公告栏汇总订单、互助、天气和事件预告；商店每天可买一条消息。雨天自动浇水，事件可影响矿洞、鱼塘和行情。\n\n⑥ 维护费每天 8 金币，尽量每天交付订单。调查 4 AP；赠礼抽线索 0 AP，第三次必成；证据可以关联。25 天内集齐 20 证据后主动曝光。当日操作可撤回（Ctrl+Z），结束今天会清空撤回。金币不足、连续五天没交订单或收购到期会失败。")
	_large_modal()
	var label: Label=modal_body.get_child(0)
	modal_body.remove_child(label)
	var scroll: ScrollContainer=ScrollContainer.new();modal_body.add_child(scroll)
	scroll.position=Vector2(0,0);scroll.size=Vector2(806,491)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var column: VBoxContainer=VBoxContainer.new();scroll.add_child(column)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(label)
	label.custom_minimum_size=Vector2(770,0);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",17)
	modal_body.get_child(0).position.y=523

func _unhandled_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.keycode==KEY_ESCAPE:
		if shade.visible: _close()
		else: _menu("options")
	elif e.ctrl_pressed and e.keycode==KEY_Z: _undo()
	elif e.keycode==KEY_F5: state.save_game()
	elif e.keycode==KEY_F9: _load()
	elif not shade.visible and e.keycode>=KEY_1 and e.keycode<=KEY_4:
		_select_tool(["till","plant","water","harvest"][e.keycode-KEY_1])
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if not capture and not testing: state.save_game()
		_shutdown.call_deferred()

func _shutdown() -> void:
	music.stop();effect.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _capture() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gameplay.png")
	_switch_map("village")
	for i: int in range(90): village_map._advance_villagers(0.1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/village-map.png")
	_menu("tavern")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/tavern.png")
	var tavern_preview: Dictionary=state.to_data()
	_village_action("drink")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/tavern-chat.png")
	state._restore(tavern_preview);state.undo_history.clear();_refresh()
	_open_person(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/neighbor.png")
	_menu("noticeboard")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/noticeboard.png")
	_switch_map("farm")
	_shop_page("animals")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop-chickens.png")
	var resources_preview: Dictionary=state.to_data()
	state.chickens=4;state.inventory.wood=6;state.tree_ready_days[0]=state.day+3
	_close();_refresh()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/forest-chickens.png")
	state._restore(resources_preview);_refresh();_shop_page("seeds")
	_seed(1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/toolbar-cabbage.png")
	_seed(0)
	farm.hover_active=true;_select_tool("water")
	for target: Array in [["farm",Vector2(414,240)],["pond",Vector2(120,375)],["mine",Vector2(801,150)],["home",Vector2(360,120)],["animals",Vector2(801,357)]]:
		farm.update_hover(target[1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/hover-%s.png"%target[0])
	farm.hover_active=false;hover_panel.hide();_select_tool("till")
	_menu("shop")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop.png")
	_shop_page("tools")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop-tools.png")
	_shop_page("energy")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop-energy.png")
	_shop_page("seeds")
	state.act("fish");state.act("fish");state.act("investigate",0);_menu("shop")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop-ap-zero.png")
	state.undo();_menu("shop")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shop-after-undo.png")
	_menu("bag")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/bag.png")
	_menu("gifts")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gifts.png")
	var village_preview: Dictionary=state.to_data()
	Village._bond(state,"elder",8);Village._bond(state,"lin",17);Village._bond(state,"he",24);Village._bond(state,"mei",32)
	for kind: String in ["villagers","person","requests","chains"]:
		_menu(kind)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/%s.png"%kind)
	selected_mail=int(state.village.mail.back().id);_open_letter(selected_mail)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/mailbox.png")
	var friendship_mail: int=selected_mail
	for letter: Dictionary in state.village.mail:
		if letter.kind=="request":
			_open_letter(int(letter.id));break
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/request-letter.png")
	selected_mail=friendship_mail
	state.day=2;Village.advance(state);_shop_page("rumors")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/rumors.png")
	state._restore(village_preview);_refresh();_shop_page("seeds")
	var cycle_preview: Dictionary=state.to_data()
	state.plots[3]={"tilled":true,"crop":2,"growth":6,"water":false,"moisture":0,"regrowing":false}
	state.plots[4]={"tilled":true,"crop":7,"growth":1,"water":true,"moisture":1,"regrowing":true}
	state.plots[5]={"tilled":true,"crop":3,"growth":2,"water":false,"moisture":1,"regrowing":false}
	_close();selected_tool="auto";farm.tool="auto";_refresh()
	farm.hover_active=true;farm.update_hover(Vector2(600,240))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/crop-cycles.png")
	state._restore(cycle_preview);farm.hover_active=false;hover_panel.hide();_refresh()
	_help()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/help.png")
	_close();state.day=11;state.weather="小雨";state.event="污染水源";state.evidence=12
	_refresh()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/rain.png")
	state.evidence=20;state.expose(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/ending.png")
	get_tree().quit()
