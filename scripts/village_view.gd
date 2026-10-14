extends "res://scripts/farm_view.gd"
## The village is a second map scene; movement never touches simulation RNG or AP.
signal person_clicked(index: int)
const ROUTE: Array[Vector2]=[Vector2(94,83),Vector2(156,83),Vector2(218,83),Vector2(218,139),Vector2(156,139),Vector2(94,139)]
const SHOP: Rect2=Rect2(234,13,55,60)
const POST: Rect2=Rect2(31,13,57,60)
const POST_BOX: Rect2=Rect2(83,57,14,22)
const POST_WALK: Rect2=Rect2(45,71,24,9)
const BOARD: Rect2=Rect2(139,25,35,34)
const EXIT: Rect2=Rect2(11,149,65,26)
const TAVERN: Rect2=Rect2(242,66,64,64)
const TINTS: Array[Color]=[Color("e8dca6"),Color("c4dde3"),Color("b7d5a0"),Color("ebc7ad")]
var actors: Array[Dictionary]=[]
var paused: bool=false
var hovered_person: int=-1
var post_box: Sprite2D

func _ready() -> void:
	super._ready()
	post_box=Sprite2D.new();add_child(post_box);post_box.name="PostBox"
	post_box.texture=textures.mailbox;post_box.centered=false
	post_box.region_enabled=true;post_box.region_rect=Rect2(0,48,32,48)
	post_box.position=Vector2(76,34)*SCALE;post_box.scale=Vector2(SCALE,SCALE)
	post_box.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;post_box.z_index=1
	for i: int in range(4):
		var node: int=i%ROUTE.size()
		actors.append({"feet":ROUTE[node],"node":node,"next":(node+1)%ROUTE.size(),"wait":float(i)*0.7,"direction":0,"walking":false})

func _add_buildings() -> void:
	WoodenHouse.create(self,Vector2(20,8),"PostOffice",Color("d7dfe5"))
	WoodenHouse.create(self,Vector2(222,8),"Shop",Color("f5d5a7"))
	WoodenHouse.create(self,Vector2(232,66),"Tavern",Color("e5c5b3"))

func _process(delta: float) -> void:
	if not visible: return
	time+=delta
	if not paused: _advance_villagers(delta)
	if hover_active and not paused: update_hover(get_local_mouse_position())
	queue_redraw()

func _advance_villagers(delta: float) -> void:
	for i: int in range(actors.size()):
		var a: Dictionary=actors[i]
		if a.wait>0: a.wait-=delta;a.walking=false;continue
		var goal: Vector2=ROUTE[int(a.next)]
		var offset: Vector2=goal-Vector2(a.feet)
		a.direction=(3 if offset.x>0 else 2) if absf(offset.x)>absf(offset.y) else (0 if offset.y>0 else 1)
		a.walking=true;a.feet=Vector2(a.feet).move_toward(goal,(12.0+i)*delta)
		if a.feet==goal:
			a.node=a.next;a.next=(int(a.node)+1)%ROUTE.size()
			a.wait=ambient_rng.randf_range(1.5,4.0);a.walking=false
			# Weather and local happenings change where villagers like to linger.
			if state.weather=="小雨" and a.node in [0,1,2]: a.wait+=5.0
			if not state.village.active.is_empty() and a.node==1: a.wait+=4.0

func _person_at(p: Vector2) -> int:
	for i: int in range(actors.size()-1,-1,-1):
		if Rect2(Vector2(actors[i].feet)-Vector2(8,19),Vector2(16,22)).has_point(p): return i
	return -1

func _draw() -> void:
	if textures.is_empty() or state==null: return
	draw_rect(Rect2(0,0,960,552),Color("bfd975"))
	for y: int in range(12):
		for x: int in range(20): sprite("grass",Vector2(x*16,y*16),Rect2((x*7+y*3)%4*16,80,16,8 if y==11 else 16))
	for x: int in range(2,19):
		for y: int in [5,8,9]: sprite("soil",Vector2(x*16,y*16),Rect2((x%3)*16,80,16,16),Color("f8edcc"))
	for x: int in [5,6,13,14]:
		for y: int in range(6,8): sprite("soil",Vector2(x*16,y*16),Rect2(16,80,16,16))
	# A clear entrance apron connects the post-office door to the main road.
	for x: int in range(2,6): sprite("soil",Vector2(x*16,72),Rect2((x%3)*16,80,16,8))
	for x: int in [45,57]: sprite("soil",Vector2(x,POST_WALK.position.y),Rect2(16,80,12,9))
	# Flower pots frame the doorway without crowding the walking route.
	for x: int in [37,73]:
		draw_rect(Rect2(Vector2(x,71)*SCALE,Vector2(6,3)*SCALE),Color("a87551"))
		draw_rect(Rect2(Vector2(x+1,69)*SCALE,Vector2(4,3)*SCALE),Color("89a05a"))
		draw_circle(Vector2(x+2,69)*SCALE,3,Color("f4d7a6"))
	# Village announcement board, bench and flower beds are drawn in pixel units.
	draw_set_transform(Vector2.ZERO,0,Vector2(SCALE,SCALE))
	draw_rect(Rect2(141,26,31,24),Color("9f7753"));draw_rect(Rect2(144,29,25,18),Color("e8d3a1"))
	for x: int in [145,166]: draw_rect(Rect2(x,49,2,10),Color("896348"))
	for x: int in [148,157,163]: draw_rect(Rect2(x,33,4,10),Color("fff0c6"))
	draw_rect(Rect2(136,106,39,5),Color("ac855c"))
	for x: int in [140,169]: draw_rect(Rect2(x,111,3,7),Color("896348"))
	draw_rect(Rect2(11,149,65,26),Color("c9ad79"));draw_rect(Rect2(13,151,61,22),Color("e3c997"))
	draw_set_transform(Vector2.ZERO)
	for pos: Vector2 in [Vector2(4,3),Vector2(279,4),Vector2(4,66),Vector2(283,63),Vector2(96,15),Vector2(186,12),Vector2(234,146),Vector2(282,150)]: sprite("trees",pos,Rect2(16,0,32,32))
	for pos: Vector2 in [Vector2(111,104),Vector2(183,105),Vector2(97,159),Vector2(178,161)]: sprite("rocks",pos,Rect2(16,32,16,16))
	text_at("村庄邮局 · 信箱",Vector2(22,13))
	text_at("杂货铺 · 买种子与小鸡",Vector2(222,13))
	text_at("公告栏 · 请求与预告",Vector2(122,20))
	text_at("酒馆 · 一杯闲聊",Vector2(241,140),Color("fff0c8"),15)
	text_at("← 返回农场",Vector2(15,165),Color("fff4d2"),17)
	# Draw in depth order so a villager in front covers the one behind.
	var order: Array[int]=[0,1,2,3]
	order.sort_custom(func(a: int,b: int) -> bool: return actors[a].feet.y<actors[b].feet.y)
	for i: int in order:
		var a: Dictionary=actors[i];var p: Dictionary=state.Village.PEOPLE[i]
		var feet: Vector2=Vector2(a.feet).round();var frame: int=int(time*6)%4 if a.walking else 0
		sprite("player",feet-Vector2(24,32),Rect2(frame*48,int(a.direction)*48,48,48),TINTS[i])
		var bond: Dictionary=state.village.people[p.id]
		var badge: String="♥" if bond.talk_day!=state.day else ""
		var request: Dictionary=state.village.request
		if not request.is_empty() and request.npc==p.id and not request.done: badge="!"
		if i==2 and not state.Village.next_unknown(state).is_empty(): badge="?"
		if not badge.is_empty(): text_at(badge,feet-Vector2(3,25),Color("ffefae"),18)
		text_at(p.name.split(" · ")[0],feet+Vector2(-10,10),Color("fff2d4"),14)
		if hovered_person==i: draw_arc(feet*SCALE,22,0,TAU,24,Color("fff0ac"),2)
	if state.weather=="小雨":
		draw_rect(Rect2(0,0,960,552),Color(0.2,0.38,0.42,0.10))
		for i: int in range(45):
			var rain: Vector2=Vector2((i*83)%960,fmod(time*220+i*43,552))
			draw_line(rain,rain+Vector2(-4,12),Color(0.78,0.89,0.84,0.4),1)

func _gui_input(e: InputEvent) -> void:
	if paused: return
	if e is InputEventMouseMotion: hover_active=true;update_hover(e.position)
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
		var p: Vector2=e.position/SCALE;var person: int=_person_at(p)
		if person>=0: person_clicked.emit(person)
		elif SHOP.has_point(p): place_clicked.emit("shop")
		elif POST.has_point(p) or POST_BOX.has_point(p) or POST_WALK.has_point(p): place_clicked.emit("mailbox")
		elif BOARD.has_point(p): place_clicked.emit("noticeboard")
		elif TAVERN.has_point(p): place_clicked.emit("tavern")
		elif EXIT.has_point(p): place_clicked.emit("farm")
		accept_event()

func update_hover(point: Vector2) -> void:
	if not hover_active or state==null: return
	var p: Vector2=point/SCALE;hovered_person=_person_at(p)
	var label: String=""
	if hovered_person>=0:
		var person: Dictionary=state.Village.PEOPLE[hovered_person]
		var bond: Dictionary=state.village.people[person.id]
		label=person.name+"\n点击打开对话、赠礼与互助\n聊天："+("免费" if state.Village.talk_cost(state)==0 else "1 AP")
		label+="\n"+("今天对话好感已获得" if bond.talk_day==state.day else "首次对话可获 +0.25 星")
	elif SHOP.has_point(p): label="杂货铺\n种子、农具、食物、小鸡与消息\n打开商店：0 AP"
	elif POST.has_point(p) or POST_BOX.has_point(p) or POST_WALK.has_point(p): label="村庄邮局\n信箱 · 未读 %d 封\n阅读信件和领取附件：0 AP"%state.Village.unread(state)
	elif BOARD.has_point(p): label="公告栏\n订单、互助、天气与事件预告\n查看：0 AP"
	elif TAVERN.has_point(p): label="村庄酒馆\n喝一杯：1 AP\n随机 2～3 位村民好感 +0.25 星\n听到一条小道消息，独立于首次对话"
	elif EXIT.has_point(p): label="返回农场\n场景切换：0 AP"
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if not label.is_empty() else Control.CURSOR_ARROW
	hover_info.emit(label,point,true)
