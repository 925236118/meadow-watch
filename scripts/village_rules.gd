extends RefCounted
## Village simulation uses a separate saved RNG so rumours cannot reroll company/gift luck.
const MAX_STARS: int=5
const POINTS_PER_STAR: int=8
const MAX_BOND_POINTS: int=MAX_STARS*POINTS_PER_STAR
const FREE_TALKS_PER_DAY: int=3
const Dialogue=preload("res://scripts/villager_dialogue.gd")
const PEOPLE: Array[Dictionary]=[
	{"id":"elder","name":"王伯 · 村长","likes":["5","egg"],"dislikes":["ore"],"line":"把收成留一点给邻居，村子才会一直热闹。"},
	{"id":"lin","name":"小林 · 记者","likes":["fish","0"],"dislikes":["3"],"line":"一个线索不够，找到能互相印证的记录才有说服力。"},
	{"id":"he","name":"阿禾 · 菜农","likes":["1","3"],"dislikes":["fish"],"line":"我听到了些工程队的消息，记得看看信箱。"},
	{"id":"mei","name":"梅姨 · 店主","likes":["2","egg"],"dislikes":["ore"],"line":"行情会变，提前留货比临时着急更划算。"}
]
const EVENTS: Array[Dictionary]=[
	{"id":"mine_repair","name":"矿洞修缮","domain":"mine","detail":"矿洞暂停使用","closed":"mine"},
	{"id":"mine_rich","name":"新矿脉发现","domain":"mine","detail":"每次挖矿额外获得 2 块矿石","boost":"mine"},
	{"id":"pond_clean","name":"鱼塘清洁","domain":"fish","detail":"鱼塘暂停钓鱼","closed":"fish"},
	{"id":"fish_spawn","name":"鱼类繁殖","domain":"fish","detail":"每次钓鱼额外获得 2 条鱼","boost":"fish"},
	{"id":"seed_up","name":"种子涨价","domain":"seed","detail":"种子基础价格 +25%","factor":1.25},
	{"id":"seed_down","name":"种子降价","domain":"seed","detail":"种子基础价格 -20%","factor":0.8},
	{"id":"crop_up","name":"作物涨价","domain":"crop","detail":"作物售价 +20%","factor":1.2},
	{"id":"crop_down","name":"作物降价","domain":"crop","detail":"作物售价 -20%","factor":0.8}
]
const CARDS: Dictionary={"water_report":"河岸排污检测","work_contract":"矿洞用工合同","land_offer":"土地收购报价","discharge_photo":"夜间排放照片","wage_note":"工人的欠薪记录","valuation_sheet":"真实土地估价"}
const CHAINS: Array[Dictionary]=[
	{"id":"pollution","name":"排污与检测不符","cards":["water_report","discharge_photo"],"text":"排放照片和检测记录指向同一处非法排污口。"},
	{"id":"workers","name":"合同掩盖欠薪","cards":["work_contract","wage_note"],"text":"合同中的保障承诺与真实欠薪记录互相矛盾。"},
	{"id":"land","name":"压低土地估价","cards":["land_offer","valuation_sheet"],"text":"收购文书故意低报估价，帮助公司压价夺地。"}
]

static func make(day: int=1) -> Dictionary:
	var people: Dictionary={}
	for p: Dictionary in PEOPLE: people[p.id]={"points":0,"talk_day":0,"gift_day":0,"milestones":[]}
	return {"bond_version":2,"talk_count":0,"people":people,"mail":[],"next_mail":1,"active":[],"planned":[],"known":[],"next_event":1,"rumor_day":0,"guards":0,"request":{},"next_request":1,"cards":[],"chains":[],"rng":"851014","day":day}

static func _roll(s: RefCounted, low: int, high: int) -> int:
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=851014;rng.state=int(s.village.rng)
	var result: int=rng.randi_range(low,high);s.village.rng=str(rng.state)
	return result

static func mail(s: RefCounted, sender: String, title: String, body: String, kind: String="greeting", gift: Dictionary={}) -> void:
	s.village.mail.append({"id":int(s.village.next_mail),"day":s.day,"sender":sender,"title":title,"body":body,"kind":kind,"read":false,"claimed":false,"gift":gift.duplicate(true)})
	s.village.next_mail+=1

static func unread(s: RefCounted) -> int:
	var result: int=0
	for letter: Dictionary in s.village.mail:
		if not letter.read: result+=1
	return result

static func forecast(day: int) -> String:
	return "小雨" if day%4==0 else "晴天"

static func initialize(s: RefCounted) -> void:
	mail(s,"王伯","欢迎回到麦野","信箱就在小屋旁。这里会收到问候、请求、感谢和提前预告行情的信件。未来两天的天气可以在主界面查看。")
	_request(s)
	_plan(s,maxi(4,s.day+2))
	_reveal(s,"阿禾",true)

static func _request(s: RefCounted) -> void:
	var npc: int=_roll(s,0,PEOPLE.size()-1)
	var options: Array[String]=["egg","fish","ore","0","5"]
	var key: String=options[_roll(s,0,options.size()-1)]
	var reward: String=["seeds","evidence","guard"][_roll(s,0,2)]
	s.village.request={"id":int(s.village.next_request),"npc":PEOPLE[npc].id,"sender":PEOPLE[npc].name,"key":key,"count":2,"deadline":s.day+3,"done":false,"reward":reward}
	s.village.next_request+=1
	mail(s,PEOPLE[npc].name,"邻里互助：需要一点物资",request_body(s.item_name(key),s.day+3),"request")

static func request_body(item: String, deadline: int) -> String:
	var reason: String={"鸡蛋":"明早家里来客人，我想做些蛋饼。","鲜鱼":"今晚想炖锅鱼汤，家里还缺些鲜鱼。","矿石":"旧工具磨损得厉害，想找点矿石修一修。","胡萝卜":"准备煮一锅蔬菜汤，正好缺点胡萝卜。","小麦":"家里的面粉快见底了，想再磨一点。"}.get(item,"家里有点事，想请你搭把手。")
	return reason+"\n\n你方便在第 %d 天结束前，帮我捎来两份%s吗？\n\n田里忙的话也别勉强，下次见面再聊。"%[deadline,item]

static func _plan(s: RefCounted, start: int) -> void:
	if start>25: return
	var occupied: Array=[]
	for item: Dictionary in s.village.active+s.village.planned:
		if item.start<=start and item.finish>=start: occupied.append(item)
	if occupied.size()>=2: return
	var available: Array[int]=[]
	for i: int in range(EVENTS.size()):
		var valid: bool=true
		for item: Dictionary in s.village.active+s.village.planned:
			if item.finish>=start and item.start<=start+2 and item.domain==EVENTS[i].domain: valid=false
		if valid: available.append(i)
	if available.is_empty(): return
	var event: Dictionary=EVENTS[available[_roll(s,0,available.size()-1)]].duplicate(true)
	event["uid"]=int(s.village.next_event);s.village.next_event+=1
	event["start"]=start;event["finish"]=mini(25,start+_roll(s,1,3)-1)
	# Reserve every day in the interval, not only the starting day.
	for day: int in range(event.start,event.finish+1):
		var count: int=0
		for item: Dictionary in s.village.active+s.village.planned:
			if item.start<=day and item.finish>=day: count+=1
		if count>=2: return
	s.village.planned.append(event)

static func next_unknown(s: RefCounted) -> Dictionary:
	for e: Dictionary in s.village.planned:
		if e.start>s.day and not s.village.known.has(e.uid): return e
	return {}

static func _reveal(s: RefCounted, sender: String, required: bool=false) -> bool:
	var e: Dictionary=next_unknown(s)
	if e.is_empty(): return false
	if not required and _roll(s,0,1)==0: return false
	s.village.known.append(e.uid)
	mail(s,sender,"小道消息："+e.name,"第 %d 天起将发生「%s」，持续到第 %d 天（%d 天）。\n\n%s。这个消息已记入预告，可以提前安排农事。"%[e.start,e.name,e.finish,e.finish-e.start+1,e.detail],"rumor")
	return true

static func advance(s: RefCounted) -> void:
	if s.village.day!=s.day: s.village.talk_count=0
	s.village.day=s.day
	var remaining: Array=[]
	for e: Dictionary in s.village.active:
		if e.finish>=s.day: remaining.append(e)
	s.village.active=remaining
	remaining=[]
	for e: Dictionary in s.village.planned:
		if e.start==s.day:
			s.village.active.append(e)
			mail(s,"村庄公告",e.name+"开始了",e.detail+"，将持续到第 %d 天结束。"%e.finish,"event")
		elif e.start>s.day: remaining.append(e)
	s.village.planned=remaining
	_plan(s,s.day+2)
	var request: Dictionary=s.village.request
	if request.is_empty() or s.day>request.deadline:
		if not request.is_empty() and not request.done: mail(s,request.sender,"请求暂时结束","先前的请求已经过期，别着急，之后还有互相帮助的机会。")
		_request(s)
	if s.day%3==0: mail(s,PEOPLE[_roll(s,0,3)].name,"路过田野的问候","最近忙不忙？再忙也记得吃一顿热饭。等你有空，来村口聊聊吧。")
	_reveal(s,PEOPLE[_roll(s,0,3)].name)

static func closed(s: RefCounted, place: String) -> bool:
	for e: Dictionary in s.village.active:
		if e.get("closed","")==place: return true
	return false

static func boost(s: RefCounted, place: String) -> int:
	for e: Dictionary in s.village.active:
		if e.get("boost","")==place: return 2
	return 0

static func factor(s: RefCounted, domain: String) -> float:
	for e: Dictionary in s.village.active:
		if e.domain==domain: return float(e.get("factor",1.0))
	return 1.0

static func summary(s: RefCounted) -> String:
	var text: String=""
	for e: Dictionary in s.village.active: text+="%s（余 %d 天）\n"%[e.name,e.finish-s.day+1]
	return text.trim_suffix("\n")

static func preview(s: RefCounted) -> String:
	var text: String=""
	for e: Dictionary in s.village.planned:
		if s.village.known.has(e.uid): text+="第%d天：%s，%d天\n"%[e.start,e.name,e.finish-e.start+1]
	return text.trim_suffix("\n")

static func _bond(s: RefCounted, id: String, delta: int) -> void:
	var person: Dictionary=s.village.people[id]
	person.points=clampi(int(person.points)+delta,0,MAX_BOND_POINTS)
	for stars: int in range(1,MAX_STARS+1):
		if person.points>=stars*POINTS_PER_STAR and not person.milestones.has(stars):
			person.milestones.append(stars)
			var gift: Dictionary={}
			if stars==3: gift={"type":"seeds","crop":_roll(s,0,7),"count":3}
			elif stars==4: gift={"type":"guard","count":1}
			elif stars==5: gift={"type":"evidence","count":1}
			var name: String=""
			var person_index: int=0
			for i: int in range(PEOPLE.size()):
				if PEOPLE[i].id==id: name=PEOPLE[i].name;person_index=i
			mail(s,name,"我们已经有 %d 星的交情了"%stars,Dialogue.milestone(person_index,stars),"friendship",gift)

static func free_talks(s: RefCounted) -> int:
	return maxi(0,FREE_TALKS_PER_DAY-int(s.village.talk_count))

static func talk_cost(s: RefCounted) -> int:
	return 0 if free_talks(s)>0 else 1

static func talk(s: RefCounted, index: int) -> bool:
	if index<0 or index>=PEOPLE.size() or not s.outcome.is_empty(): return false
	var p: Dictionary=PEOPLE[index];var progress: Dictionary=s.village.people[p.id]
	var cost: int=talk_cost(s)
	if cost>0:
		if not s._pay("talk"): return false
	else: s._checkpoint("免费村民对话")
	s.village.talk_count+=1
	var gain: bool=progress.talk_day!=s.day
	if gain: progress.talk_day=s.day;_bond(s,p.id,2)
	var learned: bool=_reveal(s,p.name,true)
	var bond_text: String="好感 +0.25 星。" if gain else "今天已通过对话增加过好感，本次不再增加。"
	var cost_text: String="本次免费；今日还剩 %d 次免费对话。"%free_talks(s) if cost==0 else "本次消耗 1 AP。"
	s.story.emit(p.name,Dialogue.line(s,index)+"\n\n"+bond_text+"\n"+cost_text+("\n听到一条新消息，已经寄到信箱。" if learned else ""))
	return s._done("与%s对话：%s%s"%[p.name,cost_text,bond_text])

static func gift(s: RefCounted, index: int, key: String) -> bool:
	if index<0 or index>=PEOPLE.size() or not s.outcome.is_empty(): return false
	if not s.inventory.has(key) or key=="meal": return false
	var p: Dictionary=PEOPLE[index];var progress: Dictionary=s.village.people[p.id]
	if progress.gift_day==s.day: return s._deny("今天已经送过这位村民礼物。")
	if s.inventory[key]<=0: return s._deny("背包里没有这件礼物。")
	s._checkpoint("赠送村民礼物");s.inventory[key]-=1;progress.gift_day=s.day
	var delta: int=4 if p.likes.has(key) else (-2 if p.dislikes.has(key) else 2)
	_bond(s,p.id,delta)
	if delta==4:
		mail(s,p.name,"谢谢你记得我的喜好","收到%s很开心！有空来聊聊，我也会留意对农场有用的消息。"%s.item_name(key),"thanks")
		_reveal(s,p.name,true)
	return s._done("赠出%s ×1，%s的好感%s。"%[s.item_name(key),p.name,"+0.5 星" if delta==4 else ("-0.25 星" if delta<0 else "+0.25 星")])

static func complete_request(s: RefCounted) -> bool:
	var r: Dictionary=s.village.request
	if not s.outcome.is_empty() or r.is_empty() or r.done or s.day>r.deadline: return s._deny("当前没有可完成的互助请求。")
	if s.inventory[r.key]<r.count: return s._deny("还缺少请求所需物资。")
	s._checkpoint("完成村民互助");s.inventory[r.key]-=r.count;r.done=true
	_bond(s,r.npc,4);s.reputation+=1
	var gift: Dictionary={"type":r.reward,"count":2 if r.reward=="evidence" else (3 if r.reward=="seeds" else 1),"crop":_roll(s,0,7)}
	mail(s,r.sender,"感谢你的帮助 · 附件待领取","你送来的物资正好解了燃眉之急。我把一点谢礼放在信里，祝农场顺利！","thanks",gift)
	return s._done("完成互助，声望 +1、好感 +0.5 星；感谢信已寄到。")

static func read_mail(s: RefCounted, id: int) -> bool:
	for letter: Dictionary in s.village.mail:
		if letter.id==id and not letter.read:
			s._checkpoint("阅读信件");letter.read=true;return s._done("已阅读「%s」。"%letter.title)
	return false

static func collect_mail(s: RefCounted, id: int) -> bool:
	if not s.outcome.is_empty(): return false
	for letter: Dictionary in s.village.mail:
		if letter.id!=id: continue
		if letter.claimed or letter.gift.is_empty(): return s._deny("没有可领取的附件。")
		s._checkpoint("领取信件附件");letter.claimed=true;letter.read=true
		var gift: Dictionary=letter.gift
		match gift.type:
			"seeds": s.seeds[int(gift.crop)]+=int(gift.count)
			"evidence":
				s.evidence=mini(20,s.evidence+int(gift.count));add_card(s,["discharge_photo","wage_note","valuation_sheet"][int(letter.id)%3])
			"guard": s.village.guards+=int(gift.count)
		return s._done("附件已领取："+gift_text(s,gift))
	return false

static func gift_text(s: RefCounted, gift: Dictionary) -> String:
	if gift.is_empty(): return "无附件"
	match gift.type:
		"seeds": return "%s种子 ×%d"%[s.CROPS[int(gift.crop)].name,gift.count]
		"evidence": return "证据 +%d"%gift.count
	return "抵挡农场破坏 ×%d"%gift.count

static func buy_rumor(s: RefCounted) -> bool:
	if not s.outcome.is_empty(): return false
	if s.village.rumor_day==s.day: return s._deny("今天已经购买过一条小道消息。")
	if next_unknown(s).is_empty(): return s._deny("目前没有新的提前消息。")
	var price: int=s.shop_price(12)
	if s.gold<price: return s._deny("购买消息需要 %d 金币。"%price)
	s._checkpoint("购买小道消息");s.gold-=price;s.village.rumor_day=s.day
	_reveal(s,"梅姨 · 商店消息",true)
	return s._done("消息已经寄到信箱，今天不能重复购买。")

static func drink(s: RefCounted) -> bool:
	if not s._pay("drink"): return false
	var pool: Array[int]=[0,1,2,3]
	var count: int=_roll(s,2,3)
	var names: PackedStringArray=[]
	var changes: PackedStringArray=[]
	var lines: PackedStringArray=[]
	for i: int in range(count):
		var chosen: int=_roll(s,0,pool.size()-1);var index: int=pool[chosen];pool.remove_at(chosen)
		var old_points: int=s.village.people[PEOPLE[index].id].points
		_bond(s,PEOPLE[index].id,2)
		names.append(PEOPLE[index].name.split(" · ")[0])
		var delta: int=int(s.village.people[PEOPLE[index].id].points)-old_points
		changes.append(names[-1]+(" +%s 星"%str(float(delta)/POINTS_PER_STAR) if delta>0 else " 已满 5 星"))
		lines.append(names[-1]+"："+Dialogue.line(s,index).split("\n\n")[0])
	if not _reveal(s,"酒馆里的闲谈",true):
		var event: Dictionary={}
		if not s.village.planned.is_empty(): event=s.village.planned[_roll(s,0,s.village.planned.size()-1)]
		elif not s.village.active.is_empty(): event=s.village.active[_roll(s,0,s.village.active.size()-1)]
		if not event.is_empty():
			mail(s,"酒馆里的闲谈","再聊起："+event.name,"邻桌也在说这件事：第 %d 天到第 %d 天，%s。\n\n%s。"%[event.start,event.finish,event.name,event.detail],"rumor")
		else:
			mail(s,"酒馆里的闲谈","听说接下来的天气","大家看着窗外商量明天的活：明日%s，后天%s。\n\n雨天能省些浇水的工夫，先把想做的事记下来吧。"%[forecast(s.day+1),forecast(s.day+2)],"rumor")
	var rumor: String=s.village.mail.back().title
	s.story.emit("酒馆 · 窗边的一桌", "你端着杯子坐下来，聊了一会儿村里的近况。\n\n"+"\n\n".join(lines)+"\n\n好感："+"、".join(changes)+"。\n消耗 1 AP；消息「%s」已经记到信箱。"%rumor)
	return s._done("酒馆闲聚：%s 好感 +0.25 星，听到一条消息。"%"、".join(names))

static func add_card(s: RefCounted, id: String) -> void:
	if CARDS.has(id) and not s.village.cards.has(id): s.village.cards.append(id)

static func connect_chain(s: RefCounted, index: int) -> bool:
	if index<0 or index>=CHAINS.size() or not s.outcome.is_empty(): return false
	var chain: Dictionary=CHAINS[index]
	if s.village.chains.has(chain.id): return s._deny("这条证据关联已经完成。")
	for card: String in chain.cards:
		if not s.village.cards.has(card): return s._deny("还缺少能互相印证的证据。")
	s._checkpoint("关联调查证据");s.village.chains.append(chain.id);s.evidence=mini(20,s.evidence+1)
	mail(s,"小林","证据链成立："+chain.name,chain.text+"\n\n关联奖励：证据 +1。","evidence")
	return s._done("关联成立：%s，证据 +1。"%chain.name)


static func normalize(value: Variant) -> Variant:
	if value is float: return int(value) if value==floor(value) else value
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value: result[key]=normalize(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value: result.append(normalize(item))
		return result
	return value

static func migrate(value: Dictionary) -> Dictionary:
	var result: Dictionary=normalize(value)
	# Update the old mechanical request wording, preserving letter identity and flags.
	for letter: Dictionary in result.mail:
		if letter.kind=="request" and letter.body.contains("完成后会寄感谢信，可能附上"):
			var pattern: RegEx=RegEx.new()
			pattern.compile("请在第 (\\d+) 天结束前送来 (.+) ×2。")
			var found: RegExMatch=pattern.search(letter.body)
			if found!=null: letter.body=request_body(found.get_string(2),int(found.get_string(1)))
	if not result.has("talk_count"):
		result["talk_count"]=0
		for person: Dictionary in result.people.values():
			if person.talk_day==result.day: result.talk_count+=1
	if int(result.get("bond_version",1))==1:
		# Keep exact completion percentage: old 4 points/star becomes 8 points/star.
		# Migrate flags and letters without awarding or re-claiming attachments.
		for person: Dictionary in result.people.values():
			var converted: Array=[]
			for old_stars: int in person.milestones: converted.append(old_stars/2)
			person.milestones=converted
		for letter: Dictionary in result.mail:
			if letter.kind!="friendship": continue
			for old_stars: int in [2,4,6,8,10]:
				letter.title=letter.title.replace("我们已经有 %d 星的交情了"%old_stars,"我们已经有 %d 星的交情了"%(old_stars/2))
				letter.body=letter.body.replace("好感度：%d / 10 星。"%old_stars,"好感度：%d / 5 星。"%(old_stars/2))
		result.bond_version=2
	return result

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	var version: Variant=value.get("bond_version",1)
	if not number(version) or int(version) not in [1,2]: return false
	if not number(value.get("talk_count",0)) or value.get("talk_count",0)<0: return false
	var base: Dictionary=make()
	for key: String in base:
		if key in ["bond_version","talk_count"]: continue
		if not value.has(key): return false
		if key=="people" or key=="request":
			if not value[key] is Dictionary: return false
		elif base[key] is Array:
			if not value[key] is Array or value[key].size()>1000: return false
		elif base[key] is String:
			if not value[key] is String or not value[key].is_valid_int(): return false
		elif not number(value[key]) or value[key]<0: return false
	for p: Dictionary in PEOPLE:
		if not value.people.has(p.id) or not value.people[p.id] is Dictionary: return false
		var person: Dictionary=value.people[p.id]
		for key: String in ["points","talk_day","gift_day"]:
			if not person.has(key) or not number(person[key]) or person[key]<0: return false
		if person.points>MAX_BOND_POINTS or not person.get("milestones") is Array: return false
		for milestone: Variant in person.milestones:
			if not number(milestone): return false
			if int(version)==1 and int(milestone) not in [2,4,6,8,10]: return false
			if int(version)==2 and (milestone<1 or milestone>MAX_STARS): return false
	if value.active.size()>2: return false
	for e: Variant in value.active+value.planned:
		if not e is Dictionary: return false
		for key: String in ["id","name","domain","detail"]:
			if not e.get(key) is String: return false
		for key: String in ["uid","start","finish"]:
			if not number(e.get(key)) or e[key]<1: return false
		if e.finish<e.start or e.finish-e.start>2: return false
		if e.has("closed") and not e.closed is String: return false
		if e.has("boost") and not e.boost is String: return false
		if e.has("factor") and not (e.factor is float or e.factor is int): return false
	for letter: Variant in value.mail:
		if not letter is Dictionary: return false
		for key: String in ["sender","title","body","kind"]:
			if not letter.get(key) is String: return false
		if not number(letter.get("id")) or not number(letter.get("day")) or not letter.get("read") is bool or not letter.get("claimed") is bool or not letter.get("gift") is Dictionary: return false
		if not letter.gift.is_empty():
			if letter.gift.get("type") not in ["seeds","evidence","guard"] or not number(letter.gift.get("count")) or letter.gift.count<1: return false
			if letter.gift.type=="seeds" and (not number(letter.gift.get("crop")) or letter.gift.crop<0 or letter.gift.crop>7): return false
	if not value.request.is_empty():
		var r: Dictionary=value.request
		for key: String in ["npc","sender","key","reward"]:
			if not r.get(key) is String: return false
		if not value.people.has(r.npc) or r.key not in ["egg","fish","ore","0","5"] or r.reward not in ["seeds","evidence","guard"] or not r.get("done") is bool: return false
		for key: String in ["id","count","deadline"]:
			if not number(r.get(key)) or r[key]<1: return false
	for card: Variant in value.cards:
		if not card is String or not CARDS.has(card): return false
	for key: Variant in value.known:
		if not number(key): return false
	for key: Variant in value.chains:
		if key not in ["pollution","workers","land"]: return false
	return true

static func number(value: Variant) -> bool:
	return (value is int or value is float) and value==floor(float(value))
