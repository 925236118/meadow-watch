extends Control
## Fixed-camera diorama, drawn at an integer pixel scale.
signal plot_clicked(index: int)
signal tree_clicked(index: int)
signal place_clicked(place: String)
signal hovered(text: String)
signal hover_info(text: String, point: Vector2, available: bool)
var selected_seed: int = 0
var hover_active: bool = false
var state: RefCounted
var selected: int = -1
var tool: String = "auto"
var time: float = 0.0
var textures: Dictionary = {}
var pond_bank: StyleBoxTexture
const WALK_POINTS: Array[Vector2] = [Vector2(102,72),Vector2(102,112),Vector2(102,160),Vector2(142,160),Vector2(190,160)]
var actor_feet: Vector2 = Vector2(102,112)
var actor_node: int = 1
var actor_goal: int = 1
var actor_next: int = 1
var actor_wait: float = 2.0
var actor_direction: int = 0
var actor_walking: bool = false
var ambient_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const SCALE: float = 3.0
const FARM: Vector2 = Vector2(110,72)
const SPRITES: String = "res://assets/sprites/"
const POND: Rect2 = Rect2(12,96,80,64)
const MINE: Rect2 = Rect2(244,20,56,56)
const MAILBOX: Rect2 = Rect2(89,34,15,26)
const HOME: Rect2=Rect2(102,3,62,65)
const WoodenHouse=preload("res://scripts/wooden_house.gd")
const FOREST: Array[Vector2]=[Vector2(8,4),Vector2(41,10),Vector2(8,51),Vector2(44,52)]

func _ready() -> void:
	ambient_rng.randomize()
	mouse_entered.connect(func() -> void: hover_active=true)
	mouse_exited.connect(func() -> void:
		hover_active=false;selected=-1;mouse_default_cursor_shape=Control.CURSOR_ARROW
		hover_info.emit("",Vector2.ZERO,true))
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for pair: Array in [
		["grass","Tilesets/ground tiles/New tiles/Grass_tiles_v2.png"],
		["soil","Tilesets/ground tiles/Old tiles/Tilled_Dirt_v2.png"],
		["water","Tilesets/ground tiles/Water.png"],
		["stone_hill","Tilesets/ground tiles/New tiles/Stone_Ground_Hills_Tiles.png"],
		["water_props","Objects/Water Objects.png"],
		["trees","Objects/Trees, stumps and bushes.png"],
		["crops","Objects/Farming Plants.png"],
		["fences","Tilesets/Building parts/Fences.png"],
		["coop","Tilesets/Building parts/Animal Structures/Chikcen_Houses.png"],
		["chicken","Animals/Chicken/chicken default.png"],
		["rocks","Objects/Mushrooms, Flowers, Stones.png"],
		["player","Characters/Basic Charakter Spritesheet.png"],
		["mailbox","Tilesets/Building parts/Mailbox Animation Frames.png"],
		["house_roof","Tilesets/Building parts/Wooden_House_Roof_Tilset.png"],
		["house_walls","Tilesets/Building parts/Wooden_House_Walls_Tilset.png"]
	]: textures[pair[0]] = load(SPRITES+pair[1])
	pond_bank=StyleBoxTexture.new()
	pond_bank.texture=textures.grass
	pond_bank.region_rect=Rect2(0,0,48,48)
	pond_bank.texture_margin_left=7;pond_bank.texture_margin_right=7
	pond_bank.texture_margin_top=7;pond_bank.texture_margin_bottom=7
	pond_bank.draw_center=false
	_add_buildings()

func _add_buildings() -> void:
	WoodenHouse.create(self,Vector2(94,3),"Farmhouse")

func _process(delta: float) -> void:
	time += delta
	_advance_actor(delta)
	queue_redraw()

func _advance_actor(delta: float) -> void:
	if actor_wait>0:
		actor_wait-=delta;actor_walking=false
		return
	if actor_node==actor_goal and not actor_walking:
		var options: Array[int]=[]
		for i: int in range(WALK_POINTS.size()):
			if i!=actor_node: options.append(i)
		actor_goal=options[ambient_rng.randi_range(0,options.size()-1)]
		actor_next=actor_node+(1 if actor_goal>actor_node else -1)
	var destination: Vector2=WALK_POINTS[actor_next]
	var direction: Vector2=destination-actor_feet
	actor_direction=(3 if direction.x>0 else 2) if absf(direction.x)>absf(direction.y) else (0 if direction.y>0 else 1)
	actor_walking=true
	actor_feet=actor_feet.move_toward(destination,18.0*delta)
	if actor_feet==destination:
		actor_node=actor_next
		if actor_node==actor_goal:
			actor_walking=false;actor_wait=ambient_rng.randf_range(2.0,4.0)
		else: actor_next=actor_node+(1 if actor_goal>actor_node else -1)

func sprite(key: String, pos: Vector2, region: Rect2, tint: Color = Color.WHITE, scale_factor: float = SCALE) -> void:
	draw_texture_rect_region(textures[key], Rect2(pos*SCALE, region.size*scale_factor),region,tint)

func text_at(text: String, pos: Vector2, color: Color = Color("f7edd4"), size: int = 16) -> void:
	draw_string(font,pos*SCALE+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("3f573e"))
	draw_string(font,pos*SCALE,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw() -> void:
	if textures.is_empty() or state == null: return
	draw_rect(Rect2(0,0,960,552),Color("bfd975"))
	# Grass atlas has a full opaque decorative strip in the last two rows.
	for y: int in range(12):
		for x: int in range(20):
			sprite("grass", Vector2(x*16,y*16),Rect2((x*7+y*3)%4*16,80,16,8 if y==11 else 16))
	# Paths connect home, cultivated plots, the animal yard and river.
	for x: int in range(2,19):
		for y: int in [9,10]:
			sprite("soil",Vector2(x*16,y*16),Rect2((x%3)*16,80,16,16),Color("f8edcc"))
	for y: int in range(2,10): sprite("soil",Vector2(94,y*16),Rect2(16,80,16,16))
	_draw_pond()
	# Timber cottage assembled from the supplied building tiles.
	sprite("mailbox",Vector2(83,12),Rect2(0,48,32,48))
	var unread: int=state.Village.unread(state)
	if unread>0:
		draw_circle(Vector2(97,32)*SCALE,9,Color("b36a51"))
		text_at(str(unread),Vector2(95,34),Color("fff2c9"),12)
	sprite("trees",Vector2(167,17),Rect2(48,0,32,32))
	sprite("trees",Vector2(202,14),Rect2(80,0,32,32))
	sprite("coop",Vector2(245,95),Rect2(144,80,48,48))
	var frame: int = int(time*2)%4
	for i: int in range(state.chickens):
		sprite("chicken",Vector2(246+i%2*25+sin(time+i)*2,132+i/2*16+cos(time+i)*2),Rect2(frame*16,(i%2)*32,16,16))
	# A rocky hill with a visible timber-supported entrance, not a loose rock pile.
	_draw_mine()
	draw_rect(Rect2(852,15,62,52),Color("6f8372"))
	draw_rect(Rect2(864,0,12,32),Color("6f8372"))
	draw_rect(Rect2(895,3,10,24),Color("6f8372"))
	for x: int in [860,881,902]: draw_rect(Rect2(x,36,9,9),Color("a2b393"))
	for i: int in range(4):
		draw_circle(Vector2(870+sin(time+i)*8,14+fmod(time*3+i*5,14)),6+i,Color(0.6,0.65,0.56,0.12))
	# Border foliage, flowers, fences and a stationary farm keeper.
	for pos: Vector2 in [Vector2(285,47),Vector2(10,151),Vector2(70,152),Vector2(212,144),Vector2(283,152)]:
		sprite("trees",pos,Rect2(16,0,32,32))
	for i: int in range(FOREST.size()):
		var pos: Vector2=FOREST[i]
		if state.day>=state.tree_ready_days[i]: sprite("trees",pos,Rect2(16,0,32,32))
		else:
			sprite("trees",pos+Vector2(8,16),Rect2(0,96,16,16))
			text_at("%d天"%(state.tree_ready_days[i]-state.day),pos+Vector2(5,29),Color("eee3b8"),13)
	for pos: Vector2 in [Vector2(65,88),Vector2(218,69),Vector2(227,153),Vector2(57,146),Vector2(32,88)]:
		sprite("rocks",pos,Rect2(0,48,16,16))
	for i: int in range(7):
		var atlas_x: int=16 if i==0 else (48 if i==6 else 32)
		sprite("fences",Vector2(105+i*16,139),Rect2(atlas_x,16,16,16))
	# 24 individually clickable plots, with growth and irrigation indicators.
	for i: int in range(24):
		var p: Dictionary = state.plots[i]
		var pos: Vector2 = FARM+Vector2(i%6*16,i/6*16)
		if p.tilled:
			sprite("soil",pos,Rect2(16,16,16,16),Color("c1a887") if state.is_moist(p) else Color.WHITE)
			draw_rect(Rect2(pos*SCALE+Vector2(3,3),Vector2(42,42)),Color(0.48,0.32,0.18,0.13),false,1)
		else:
			draw_rect(Rect2(pos*SCALE+Vector2(3,3),Vector2(42,42)),Color(0.4,0.56,0.22,0.3),false,1)
		if p.crop >= 0:
			var crop: Dictionary = state.CROPS[p.crop]
			var stage: int = mini(4, int(float(p.growth)/state.growth_target(p)*3)+1) if p.growth > 0 else 0
			if p.get("regrowing",false): stage=mini(4,2+int(float(p.growth)/state.growth_target(p)*2))
			if p.crop != 2: stage = mini(stage,3)
			if p.crop==2 and stage>=3:
				sprite("crops",pos-Vector2(0,16),Rect2(stage*16,0,16,32))
			else: sprite("crops",pos,Rect2(stage*16,crop.row*16,16,16))
			if p.growth >= state.growth_target(p):
				draw_circle(pos*SCALE+Vector2(39,8),3+sin(time*3),Color("fff2a1"))
			elif state.is_moist(p):
				draw_circle(pos*SCALE+Vector2(39,39),3,Color("7fc9c5"))
		if i == selected:
			draw_rect(Rect2(pos*SCALE,Vector2(48,48)),Color("fff4bd"),false,3)
	if state.scarecrow:
		draw_line(Vector2(656,235),Vector2(656,300),Color("815f43"),5)
		draw_line(Vector2(630,266),Vector2(682,266),Color("815f43"),5)
		draw_circle(Vector2(656,243),12,Color("eed38f"))
	var actor_frame: int=int(time*6)%4 if actor_walking else 0
	sprite("player",actor_feet.round()-Vector2(24,32),Rect2(actor_frame*48,actor_direction*48,48,48))
	text_at("木材林 · 砍伐",Vector2(13,87),Color("f7edd4"),14)
	text_at("田园小屋 · 烹饪",Vector2(101,12))
	text_at("旧矿洞 · 挖矿",Vector2(236,17))
	text_at("河岸 · 钓鱼",Vector2(22,93))
	text_at("动物小院 · %d/4 只"%state.chickens,Vector2(234,86))
	text_at("村口 · 前往村庄 →",Vector2(112,183))
	if state.weather == "小雨":
		draw_rect(Rect2(0,0,960,552),Color(0.2,0.38,0.42,0.10))
		for i: int in range(50):
			var rain: Vector2 = Vector2((i*83)%960,fmod(time*220+i*43,552))
			draw_line(rain,rain+Vector2(-4,12),Color(0.78,0.89,0.84,0.4),1)

func _draw_pond() -> void:
	var inside: Rect2=POND.grow(-5)
	var water_frame: int=int(time*3)%4
	# Each tile shares an animation phase, including cropped edge tiles.
	for y: int in range(4):
		for x: int in range(5):
			var pos: Vector2=inside.position+Vector2(x*16,y*16)
			var width: float=minf(16,inside.end.x-pos.x)
			var height: float=minf(16,inside.end.y-pos.y)
			if width>0 and height>0:
				sprite("water",pos,Rect2(water_frame*16,0,width,height))
	# Draw the atlas shoreline in local pixels so its seven-pixel bank is scaled 3x.
	draw_set_transform(Vector2.ZERO,0,Vector2(SCALE,SCALE))
	draw_style_box(pond_bank,POND)
	draw_set_transform(Vector2.ZERO)
	sprite("water_props",Vector2(20,103),Rect2(128,0,16,16))
	sprite("water_props",Vector2(65,135),Rect2(144,0,16,16))
	sprite("water_props",Vector2(73,101),Rect2(0,0,16,16))

func _draw_mine() -> void:
	sprite("stone_hill",MINE.position,Rect2(0,0,48,48))
	# Pixel-stepped arch lies inside the stone hillside; timber and rails lead to it.
	var mouth: Vector2=Vector2(258,39)
	draw_set_transform(Vector2.ZERO,0,Vector2(SCALE,SCALE))
	draw_rect(Rect2(mouth+Vector2(4,0),Vector2(18,4)),Color("475b52"))
	draw_rect(Rect2(mouth+Vector2(1,4),Vector2(24,26)),Color("35493f"))
	draw_rect(Rect2(mouth+Vector2(5,6),Vector2(16,25)),Color("172d29"))
	draw_rect(Rect2(mouth+Vector2(-1,5),Vector2(4,27)),Color("9e7955"))
	draw_rect(Rect2(mouth+Vector2(23,5),Vector2(4,27)),Color("9e7955"))
	draw_rect(Rect2(mouth+Vector2(-2,3),Vector2(30,4)),Color("d0a878"))
	draw_rect(Rect2(mouth+Vector2(0,4),Vector2(26,1)),Color("e5c99a"))
	for x: int in [7,19]:
		draw_rect(Rect2(mouth+Vector2(x,25),Vector2(2,11)),Color("899787"))
	for y: int in [27,31,35]:
		draw_rect(Rect2(mouth+Vector2(5,y),Vector2(18,2)),Color("856a50"))
	if state.event=="封锁矿洞":
		draw_rect(Rect2(mouth+Vector2(-2,16),Vector2(30,5)),Color("dcaf71"))
		for x: int in range(0,28,8): draw_rect(Rect2(mouth+Vector2(x,16),Vector2(3,5)),Color("a15c4a"))
	draw_set_transform(Vector2.ZERO)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		hover_active=true
		update_hover(e.position)
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = e.position/SCALE
		var tile: int = _plot_at(p)
		var tree: int=_tree_at(p)
		if tile >= 0: plot_clicked.emit(tile)
		elif tree>=0: tree_clicked.emit(tree)
		elif POND.has_point(p): place_clicked.emit("fish")
		elif MINE.has_point(p): place_clicked.emit("mine")
		elif MAILBOX.has_point(p): place_clicked.emit("mailbox")
		elif HOME.has_point(p): place_clicked.emit("cook")
		elif Rect2(235,82,78,80).has_point(p): place_clicked.emit("feed")
		elif p.y > 158: place_clicked.emit("village")
		accept_event()

func update_hover(point: Vector2) -> void:
	if not hover_active: return
	var p: Vector2=point/SCALE
	selected=_plot_at(p)
	var action: String=""
	var title: String=""
	var extra: String=""
	var reason: String=""
	var tree: int=_tree_at(p)
	if tree>=0:
		action="chop";title="木材林 · 砍伐";extra="获得木材 ×3 · 用于升级 / 出售"
		if state.day<state.tree_ready_days[tree]: reason="正在恢复，第 %d 天可再次砍伐"%state.tree_ready_days[tree]
	elif selected>=0:
		action=state.suggest_action(selected) if tool=="auto" else tool
		var tile: Dictionary=state.plots[selected]
		title="农田 · "+{"till":"开垦","plant":"播种","water":"浇水","harvest":"收获"}.get(action,action)
		if tile.crop>=0:
			var crop: Dictionary=state.CROPS[tile.crop]
			extra="%s · %s %d/%d 天 · %s"%[crop.name,"再熟" if tile.get("regrowing",false) else "生长",tile.growth,state.growth_target(tile),"湿润" if state.is_moist(tile) else "需浇水"]
			if crop.get("moisture_days",1)>1: extra+="（可保湿两天）"
		match action:
			"till":
				if tile.tilled: reason="已经开垦，请播种或照料作物"
			"plant":
				extra="%s种子 ×1（持有 %d）"%[state.CROPS[selected_seed].name,state.seeds[selected_seed]]
				if not tile.tilled: reason="需要先开垦土地"
				elif tile.crop>=0: reason="已有作物，请先收获"
				elif state.seeds[selected_seed]<=0: reason="种子不足，去杂货铺补充"
			"water":
				if tile.crop<0: reason="这里没有作物，请先播种"
				elif state.is_moist(tile): reason="土壤仍湿润，今天不用浇水"
				elif tile.growth>=state.growth_target(tile): reason="已经成熟，请收获"
			"harvest":
				if tile.crop<0: reason="这里没有可收获的作物"
				elif tile.growth<state.growth_target(tile): reason="尚未成熟，浇水后跨天生长"
	elif POND.has_point(p):
		action="fish";title="水塘 · 钓鱼";extra="材料：无需材料"
		if state.Village.closed(state,"fish"): reason="鱼塘正在清洁，日期见信箱"
		elif state.Village.boost(state,"fish")>0: extra+=" · 繁殖期产量 +2"
	elif MINE.has_point(p):
		action="mine";title="矿洞 · 挖矿";extra="材料：无需材料"
		if state.event=="封锁矿洞": reason="矿洞已封锁，先调查矿洞线索"
		elif state.Village.closed(state,"mine"): reason="矿洞正在修缮，日期见信箱"
		elif state.Village.boost(state,"mine")>0: extra+=" · 新矿脉产量 +2"
	elif MAILBOX.has_point(p):
		action="mailbox";title="信箱 · 阅读信件";extra="未读 %d 封 · 阅读 0 AP"%state.Village.unread(state)
	elif HOME.has_point(p):
		action="cook";title="田园小屋 · 烹饪"
		extra="材料：鲜鱼 ×1 或同种作物 ×2"
		var ingredient: bool=state.inventory.fish>0
		for i: int in range(state.CROPS.size()): ingredient=ingredient or state.inventory[str(i)]>=2
		if state.cooked: reason="今天已经烹饪过"
		elif not ingredient: reason="食材不足（鲜鱼持有 %d）"%state.inventory.fish
	elif Rect2(235,82,78,80).has_point(p):
		action="feed";title="动物小院 · 饲养";extra="饲料费：4 金币（持有 %d）"%state.gold
		if state.chickens==0:
			action="chickens";title="动物小院 · 购买小鸡";extra="当前 0/4 只 · 点击打开小鸡商店"
		elif state.fed: reason="今天已经喂养并收集鸡蛋"
		elif state.gold<4: reason="金币不足以购买饲料"
	elif p.y>158:
		action="villagers";title="村口 · 村民与互助";extra="打开村民面板：0 AP\n全村前三次聊天免费，每人每天一次对话好感"
	if action.is_empty():
		mouse_default_cursor_shape=Control.CURSOR_ARROW
		hover_info.emit("",point,true);return
	if not state.outcome.is_empty(): reason="故事已结束"
	elif action not in ["investigate","villagers","mailbox"] and state.ap<state.cost(action):
		reason="AP 不足，可用 Ctrl+Z 撤回"
	var text: String=title+"\n"
	if action not in ["investigate","villagers","mailbox"]: text+="消耗：%d AP（当前 %d / %d）\n"%[state.cost(action),state.ap,state.max_ap]
	if extra.is_empty(): extra="材料：无需材料"
	text+=extra+"\n"+("点击执行" if reason.is_empty() else reason)
	mouse_default_cursor_shape=(Control.CURSOR_CROSS if selected>=0 else Control.CURSOR_POINTING_HAND) if reason.is_empty() else Control.CURSOR_FORBIDDEN
	hovered.emit(title)
	hover_info.emit(text,point,reason.is_empty())

func _tree_at(p: Vector2) -> int:
	for i: int in range(FOREST.size()):
		if Rect2(FOREST[i],Vector2(32,32)).has_point(p): return i
	return -1

func _plot_at(p: Vector2) -> int:
	if not Rect2(FARM,Vector2(96,64)).has_point(p): return -1
	var tile: Vector2i = Vector2i((p-FARM)/16)
	return tile.y*6+tile.x
