extends Control
const State = preload("res://scripts/farm_state.gd")
const View = preload("res://scripts/farm_view.gd")
const FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const ICONS: Texture2D = preload("res://assets/ui/UI Sprites/Icons/All Icons.png")
const CROP_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/Farming Plants items.png")
const TOOL_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/tools and meterials.png")
const ALL_ITEMS: Texture2D = preload("res://assets/sprites/Objects/Items/All items.png")
const FISH_ICON: Texture2D = preload("res://assets/icons/fishing.svg")
const COOK_ICON: Texture2D = preload("res://assets/icons/cooking.svg")
const BAG_ICON: Texture2D = preload("res://assets/icons/backpack.svg")
var state: RefCounted = State.new()
var farm: Control
var hud: Label
var status: Label
var hint: Label
var news: Label
var progress: ProgressBar
var order_labels: Array[Label] = []
var order_buttons: Array[Button] = []
var tool_buttons: Array[Button] = []
var activity_buttons: Array[Button] = []
var selected_tool: String = "till"
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
		_story("麦野守望 · 春天的第一封信", "你继承了村外的小农场。黎明工业想买下整片土地，你拒绝了。\n\n村长：别急，先把日子过好。每天有 10 点行动力，收获、钓鱼、交付订单都能帮你站稳脚跟。\n\n小林：从第 4 天起留意异常，在第 25 天结束前收集 20 份证据，公开真相。\n\n先试试：选择「收获」→ 点击闪光的胡萝卜 → 去订单板看看。\n\n作物需要浇水，并在结束一天时生长。每晚维护费 8 金币。")

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
	hud=_label("",Rect2(495,36,730,45),self,23,"f2dfad")
	_icon(Vector2(458,46),Rect2(16,96,16,16))
	_button("菜单",Rect2(1292,34,112,46),func() -> void: _menu("options"))
	undo_button=_button("撤回",Rect2(1145,34,132,46),_undo)
	undo_button.tooltip_text="撤回当天上一步成功操作 · Ctrl+Z"
	_panel(Rect2(30,155,980,574),self,"6a8456")
	farm=View.new();add_child(farm);farm.position=Vector2(40,166);farm.size=Vector2(960,552);farm.state=state
	farm.plot_clicked.connect(_on_plot);farm.place_clicked.connect(_on_place)
	farm.hovered.connect(func(text: String) -> void: hint.text=text)
	farm.hover_info.connect(_show_hover)
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
	news=_label("",Rect2(1058,511,320,117),self,16,"bfc9a9");news.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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

func _refresh() -> void:
	farm.selected_seed=selected_seed
	farm.update_hover(farm.get_local_mouse_position())
	for b: Button in [undo_button,modal_undo_button]:
		b.disabled=not state.can_undo()
		b.text="撤回 (%d)" % state.undo_history.size()
	hud.text="第 %02d 天    %s    金币 %d    AP %d / 10" % [state.day,state.weather,state.gold,state.ap]
	progress.value=state.evidence
	news.text="证据 %d / 20 · 声望 %d\n距离收购：%d 天\n%s\n连续未交付：%d / 5 天" % [state.evidence,state.reputation,maxi(0,26-state.day),"今日干扰："+state.event if not state.event.is_empty() else ("教学期 · 暂无公司干扰" if state.day<4 else "今日干扰已解除"),state.missed]
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
	var item_row: int=state.CROPS[selected_seed].row+1
	seed_button.icon=_atlas(CROP_ITEMS,Rect2(16,item_row*16,16,16))
	tool_buttons[1].icon=_atlas(CROP_ITEMS,Rect2(0,item_row*16,16,16))
	seed_button.tooltip_text="点击切换种子"
	for i: int in range(4):
		activity_buttons[i].text=["钓鱼","挖矿","烹饪","饲养"][i]+"\n%d AP" % state.cost(["fish","mine","cook","feed"][i])
	farm.queue_redraw()

func _message(text: String) -> void:
	status.text=text

func _sound() -> void:
	if not muted and not testing and not capture: effect.pitch_scale=randf_range(0.95,1.1);effect.play()

func _select_tool(action: String) -> void:
	selected_tool=action;farm.tool=action;_refresh()
	status.text="选择了%s。点击农田地块使用。当前种子：%s。" % [{"till":"锄头","plant":"播种","water":"洒水壶","harvest":"收获"}[action],state.CROPS[selected_seed].name]

func _on_plot(index: int) -> void:
	if state.plot_action(index,selected_tool,selected_seed): _sound();_autosave()

func _on_place(place: String) -> void:
	if place=="investigate": _menu(place)
	else: _activity(place)

func _activity(action: String) -> void:
	if state.act(action): _sound();_autosave()

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

func _story(title: String, text: String) -> void:
	_clear_modal();current_menu="story";shade.show();modal_title.text=title
	var l: Label=_label(text,Rect2(10,0,795,412),modal_body,20);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button("开始新的守望" if not state.outcome.is_empty() else "继续 →",Rect2(552,433,248,55),func() -> void:
		if not state.outcome.is_empty(): _new_game()
		else: _close(),modal_body)

func _menu(kind: String) -> void:
	_clear_modal();current_menu=kind;shade.show()
	match kind:
		"seeds":
			modal_title.text="种子袋 · 选择下一次播种的作物"
			_label("浇水后结束一天才会生长；小雨会自动灌溉。",Rect2(0,0,800,35),modal_body,17,"bfcea7")
			for i: int in range(8):
				var crop: Dictionary=state.CROPS[i]
				_button("%s%s\n%d 天成熟 · 剩余 %d 颗" % ["● " if i==selected_seed else "",crop.name,crop.days,state.seeds[i]],Rect2(i%2*411,48+i/2*98,398,86),_seed.bind(i),modal_body)
		"bag":
			modal_title.text="背包 · 收成与田园热饭"
			var keys: Array=["0","1","2","3","4","5","6","7","fish","ore","egg","meal"]
			for i: int in range(keys.size()):
				var key: String=keys[i]
				var pos: Vector2=Vector2(i%2*411,i/2*73)
				_label("%s ×%d" % [state.item_name(key),state.inventory[key]],Rect2(pos.x,pos.y+10,190,42),modal_body,18)
				_button("吃饭 +5 AP" if key=="meal" else "出售 1 份",Rect2(pos.x+200,pos.y+4,188,48),_bag_action.bind(key),modal_body)
			_label("出售不消耗 AP。市场打压时售价 -30%；鸡蛋基础价 16 金币。",Rect2(0,447,810,36),modal_body,16,"bfcea7")
		"shop":
			modal.position.y=99;modal.size.y=702;modal_body.size.y=586
			modal_title.text="杂货铺 · 种子与农具"
			_label("当前金币：%d    |    当前矿石：%d" % [state.gold,state.inventory.ore],Rect2(0,0,810,32),modal_body,20,"f2dfb0")
			for i: int in range(8):
				var crop: Dictionary=state.CROPS[i]
				var b: Button=_button("%s · 持有 %d 颗\n购买 ×3：%d 金币" % [crop.name,state.seeds[i],crop.seed*3],Rect2(i%2*411,39+i/2*68,398,62),_buy.bind(i),modal_body)
				b.disabled=state.gold<crop.seed*3 or not state.outcome.is_empty()
			_label("工具升级 · 共 5 级    |    当前矿石：%d" % state.inventory.ore,Rect2(0,316,800,31),modal_body,20,"f2dfb0")
			for i: int in range(4):
				var level: int=state.tools[i]
				var b: Button=_button("%s Lv.%d → %s\n%s" % [["锄头","洒水壶","鱼竿","镐子"][i],level,"满级" if level==5 else str(level+1),"已满级" if level==5 else "%d 金币 + %d 矿石" % [20*level,3*level]],Rect2(i%2*411,354+i/2*70,398,62),_upgrade.bind(i),modal_body)
				b.disabled=level>=5 or state.gold<20*level or state.inventory.ore<3*level or not state.outcome.is_empty()
			_label("洒水壶多浇邻格；鱼竿/镐子增产，3 级减少 AP。",Rect2(0,497,810,24),modal_body,15,"bfcea7")
			_button("稻草人 · 2 AP + 25 金币 + 2 矿石",Rect2(0,532,482,43),func() -> void:
				_activity("scarecrow");_menu("shop"),modal_body)
			_button("安慰动物 · 2 AP",Rect2(501,532,305,43),func() -> void:
				_activity("comfort");_menu("shop"),modal_body)
		"investigate":
			modal_title.text="小林的证据册 · %d / 20" % state.evidence
			_label("每处每天一次 · 消耗 4 AP · 第 11 天起证据产出增加",Rect2(0,0,800,32),modal_body,17,"bfcea7")
			for i: int in range(3):
				var b: Button=_button(state.CLUES[i]+(" · 今日已调查" if state.investigated.has(i) else " · 调查 →"),Rect2(0,44+i*58,802,49),_investigate.bind(i),modal_body)
				b.disabled=state.investigated.has(i) or not state.outcome.is_empty()
			var scroll: ScrollContainer=ScrollContainer.new();modal_body.add_child(scroll);scroll.position=Vector2(0,237);scroll.size=Vector2(802,250)
			var list: VBoxContainer=VBoxContainer.new();scroll.add_child(list);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var entries: Array=state.archive.duplicate();entries.reverse()
			if entries.is_empty(): entries.append("暂无记录。河岸、矿洞和村口都值得调查。")
			for entry: String in entries:
				var l: Label=Label.new();list.add_child(l);l.text=entry;l.custom_minimum_size.x=765;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",16)
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
				if p.crop>=0 and not p.water and p.growth<state.CROPS[p.crop].days: dry+=1
			_label("今天还剩 %d AP。\n\n未浇水的生长中作物：%d 株\n今日订单：%s\n夜间维护：8 金币\n\n结束后恢复 10 AP，已浇水的作物生长一天。" % [state.ap,dry,"至少已交付 1 份" if state.delivered else "尚未交付",],Rect2(0,0,800,330),modal_body,22)
			_button("再忙一会儿",Rect2(0,409,382,60),_close,modal_body)
			_button("结束今天 →",Rect2(414,409,388,60),_rest,modal_body)
		"options":
			modal_title.text="麦野守望 · 菜单"
			for i: int in range(4):
				_button(["保存进度","读取存档","重新开始","打开存档目录"][i],Rect2(i%2*411,i/2*83,398,65),[_save,_load,_confirm_new,_open_save_folder][i],modal_body)
			_button("音效与音乐："+("关闭" if muted else "开启"),Rect2(0,184,398,60),_toggle_sound,modal_body)
			_button("玩法说明",Rect2(411,184,398,60),_help,modal_body)
			_label("目标：25 天内集齐 20 份证据并主动曝光。\n每日 10 AP；维护费 8 金币。\n金币不足 / 连续 5 天无订单 / 收购到期会失败。\n自动存档会在每次成功行动后更新；新游戏不会立即覆盖旧档。\n\n美术：Sprout Lands · Cup Nooble\n引擎：Godot 4.7.2 · 音乐与音效：程序合成\nEsc 关闭窗口 · 1–4 切换工具 · F5 保存 · F9 读取",Rect2(0,267,815,221),modal_body,17,"bfcea7")

func _seed(index: int) -> void:
	selected_seed=index;_close();_select_tool("plant")

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
			if previous_menu in ["shop","bag","seeds","investigate","rest","expose","options"]: _menu(previous_menu)
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
	state.new_game();selected_tool="till";selected_seed=0;_close();_refresh();_help()

func _open_save_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://"))

func _toggle_sound() -> void:
	muted=not muted;music.stream_paused=muted;_menu("options")

func _help() -> void:
	_story("村长的田园手册", "① 选择工具，再点击地块：开垦 2 AP / 播种 1 AP / 浇水 1 AP / 收获 2 AP。种子袋可切换 8 种作物。\n\n② 点击河岸钓鱼、矿洞挖矿、小屋烹饪、小院饲养，也可使用下方按钮。背包中出售物资、食用热饭。\n\n③ 每天至少完成一个订单，夜间会扣 8 金币。未浇水的作物不生长，小雨会自动灌溉。\n\n④ 调查 4 AP，每处每天一次。集齐 20 份证据后点击「公开真相」。必须在第 25 天结束前完成。\n\n⑤ 工具最高 5 级。噪声中先安慰动物；封矿时调查矿洞；稻草人能保护收成。")

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
