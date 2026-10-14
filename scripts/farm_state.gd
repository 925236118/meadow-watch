extends RefCounted
## Pure turn simulation. UI observes changed; saves contain only data.
signal changed
signal message(text: String)
signal story(title: String, text: String)
const Village=preload("res://scripts/village_rules.gd")
var village: Dictionary = {}

const CROPS: Array[Dictionary] = [
	{"name":"胡萝卜", "row":2, "days":2, "price":16, "seed":5},
	{"name":"卷心菜", "row":7, "days":3, "price":23, "seed":7},
	{"name":"玉米", "row":1, "days":6, "price":32, "seed":8, "regrow":2},
	{"name":"南瓜", "row":9, "days":5, "price":31, "seed":10, "moisture_days":2},
	{"name":"茄子", "row":5, "days":3, "price":25, "seed":7},
	{"name":"小麦", "row":8, "days":2, "price":15, "seed":4},
	{"name":"芜菁", "row":10, "days":2, "price":18, "seed":5},
	{"name":"黄瓜", "row":14, "days":5, "price":26, "seed":7, "regrow":2}
]
const EVENTS: Array[String] = ["污染水源", "噪声扰民", "破坏作物", "封锁矿洞", "乌鸦袭击", "市场打压"]
const CLUES: Array[String] = ["河岸的排污记录", "矿洞里的违规合同", "村口的收购文件"]
const SAVE_PATH: String = "user://farm_save.json"
var day: int = 1
var ap: int = 10
var max_ap: int = 10
const MAX_AP_LIMIT: int = 30
const MEAL_PRICE: int = 35
const CHICKEN_PRICE: int=40
const MAX_CHICKENS: int=4
const INITIAL_SEEDS: Array[int]=[2,0,0,0,0,1,0,0]
const TREE_REGROW_DAYS: int=3
var chickens: int=0
var tree_ready_days: Array=[0,0,0,0]
var gold: int = 90
var reputation: int = 0
var evidence: int = 0
var missed: int = 0
var delivered: bool = false
var inventory: Dictionary = {}
var seeds: Array = []
var plots: Array = []
var tools: Array = [1,1,1,1]
var orders: Array = []
var investigated: Array = []
var archive: Array = []
var event: String = ""
var weather: String = "晴天"
var fed: bool = false
var cooked: bool = false
var comforted: bool = false
var scarecrow: bool = false
var outcome: String = ""
var gift_attempts: int = 0
var gift_success: bool = false
var undo_history: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	new_game()

func new_game() -> void:
	undo_history.clear();gift_attempts=0;gift_success=false
	rng.seed = 131026
	day = 1; max_ap = 10; ap = max_ap; gold = 90; reputation = 0; evidence = 0; missed = 0
	delivered = false; fed = false; cooked = false; comforted = false
	event = ""; weather = "晴天"; scarecrow = false; outcome = ""
	chickens=0;tree_ready_days=[0,0,0,0]
	inventory = {"fish":0, "ore":0, "egg":0, "meal":0,"wood":0}
	seeds = []; plots = []; tools = [1,1,1,1]; investigated = []; archive = []
	for i: int in range(CROPS.size()):
		inventory[str(i)] = 0
		seeds.append(INITIAL_SEEDS[i])
	for i: int in range(24):
		plots.append({"tilled": i < 6, "crop": -1, "growth": 0, "water": false, "moisture":0, "regrowing":false})
	plots[0] = {"tilled":true, "crop":0, "growth":2, "water":false,"moisture":0,"regrowing":false}
	plots[1] = {"tilled":true, "crop":0, "growth":1, "water":false,"moisture":0,"regrowing":false}
	plots[2] = {"tilled":true, "crop":1, "growth":1, "water":false,"moisture":0,"regrowing":false}
	_make_orders()
	village=Village.make(day);Village.initialize(self)
	changed.emit()

func cost(action: String) -> int:
	match action:
		"till": return maxi(1, 2 - int(tools[0]) / 3)
		"talk", "drink": return 1
		"plant": return 0
		"water": return 1
		"harvest": return 2
		"fish": return maxi(1, 3 - int(tools[2]) / 3)
		"mine": return maxi(1, 3 - int(tools[3]) / 3)
		"cook", "comfort", "repair", "scarecrow", "chop": return 2
		"feed": return 3
		"investigate": return 4
	return 0

func _deny(text: String) -> bool:
	message.emit(text)
	return false

func _pay(action: String) -> bool:
	if not outcome.is_empty(): return _deny("故事已经结束。可以开始新的守望。")
	if ap < cost(action): return _deny("行动点不足，可以撤回之前的操作，或吃热饭恢复 AP。")
	_checkpoint({"till":"开垦","plant":"播种","water":"浇水","harvest":"收获","fish":"钓鱼","mine":"挖矿","cook":"烹饪","feed":"饲养","comfort":"安慰动物","investigate":"调查","scarecrow":"建造稻草人","talk":"村民对话","chop":"砍伐树木","drink":"酒馆闲聚"}.get(action,action))
	ap -= cost(action)
	return true

func _done(text: String) -> bool:
	message.emit(text)
	changed.emit()
	return true

func growth_target(p: Dictionary) -> int:
	if p.crop<0: return 0
	return int(CROPS[p.crop].get("regrow",CROPS[p.crop].days)) if p.get("regrowing",false) else int(CROPS[p.crop].days)

func is_moist(p: Dictionary) -> bool:
	return p.water or int(p.get("moisture",0))>0

func _water_plot(p: Dictionary) -> void:
	p.water=true;p.moisture=int(CROPS[p.crop].get("moisture_days",1))

func crop_cycle_text(crop: int) -> String:
	var c: Dictionary=CROPS[crop]
	if c.has("regrow"): return "首熟 %d 天 · 采后每 %d 天再熟"%[c.days,c.regrow]
	if c.get("moisture_days",1)>1: return "%d 天成熟 · 浇一次生长两天"%c.days
	return "%d 天成熟 · 每天浇水"%c.days

func plot_action(index: int, action: String, crop: int = 0) -> bool:
	if index < 0 or index >= plots.size() or crop < 0 or crop >= CROPS.size(): return false
	var p: Dictionary = plots[index]
	match action:
		"till":
			if p.tilled: return _deny("这块土地已经开垦，可以播种了。")
			if not _pay(action): return false
			p.tilled = true
			for offset: int in range(1,int(tools[0])):
				var neighbor: int=index+offset
				if neighbor<plots.size() and neighbor/6==index/6: plots[neighbor].tilled=true
		"plant":
			if not p.tilled: return _deny("先用锄头开垦这块土地。")
			if p.crop >= 0: return _deny("这里已有作物。成熟后收获，再播种。")
			if seeds[crop] <= 0: return _deny("这种种子用完了，去杂货铺补充。")
			if not _pay(action): return false
			seeds[crop] -= 1; p.crop = crop; p.growth = 0; p.moisture=0; p.water=false; p.regrowing=false
			if weather=="小雨": _water_plot(p)
		"water":
			if p.crop < 0: return _deny("先播种，再给作物浇水。")
			if is_moist(p): return _deny("土壤仍然湿润，今天不需要浇水。")
			if p.growth >= growth_target(p): return _deny("作物已经成熟，可以收获。")
			if not _pay(action): return false
			_water_plot(p)
			# Higher watering-can levels irrigate adjacent planted tiles for the same AP.
			for offset: int in range(1, int(tools[1])):
				var neighbor: int = index + offset
				if neighbor < plots.size() and neighbor / 6 == index / 6 and plots[neighbor].crop >= 0:
					_water_plot(plots[neighbor])
		"harvest":
			if p.crop < 0: return _deny("这里还没有作物。")
			if p.growth < growth_target(p): return _deny("作物还未成熟。浇水后结束一天，才会生长。")
			if not _pay(action): return false
			var amount: int = 1 if event == "乌鸦袭击" and not scarecrow else 2
			inventory[str(p.crop)] += amount
			var crop_name: String = CROPS[p.crop].name
			var repeat: bool=int(CROPS[p.crop].get("regrow",0))>0
			p.growth=0; p.water=false; p.moisture=0; p.regrowing=repeat
			if not repeat: p.crop=-1
			elif weather=="小雨": _water_plot(p)
			return _done("收获 %s ×%d。%s" % [crop_name, amount,"植株保留，再浇水生长 2 天可继续采摘。" if repeat else "订单板和杂货铺都在等你。"])
		_: return false
	return _done({"till":"开垦了新土地。", "plant":"播下了%s。%s" % [CROPS[crop].name,"浇水一次可供两天生长。" if CROPS[crop].get("moisture_days",1)==2 else "记得浇水促进生长。"], "water":"清水渗入泥土。今晚作物会生长。"}[action])

func act(action: String, target: int = 0) -> bool:
	match action:
		"fish":
			if Village.closed(self,"fish"): return _deny("鱼塘正在清洁，请查看信箱中的预告和持续日期。")
			if not _pay(action): return false
			var amount: int = 1 + int(tools[2]) + Village.boost(self,"fish")
			if event == "污染水源": amount = maxi(1, amount / 2)
			inventory.fish += amount
			return _done("钓到鲜鱼 ×%d。%s" % [amount, "污染让鱼获减少了一半。" if event == "污染水源" else "河面仍然闪着光。"])
		"mine":
			if Village.closed(self,"mine"): return _deny("矿洞正在修缮，请查看信箱中的预告和持续日期。")
			if event == "封锁矿洞": return _deny("矿洞被封锁。调查矿洞线索可以解除封锁。")
			if not _pay(action): return false
			var amount: int = 1 + int(tools[3]) + Village.boost(self,"mine")
			inventory.ore += amount
			return _done("获得矿石 ×%d，可以在杂货铺升级工具。" % amount)
		"cook":
			if cooked: return _deny("今天的炉火已经熄了，明天再烹饪。")
			var ingredient: String = "fish" if inventory.fish > 0 else ""
			if ingredient.is_empty():
				for i: int in range(CROPS.size()):
					if inventory[str(i)] >= 2: ingredient = str(i); break
			if ingredient.is_empty(): return _deny("烹饪需要 1 条鱼或 2 份同种作物。")
			if not _pay(action): return false
			inventory[ingredient] -= 1 if ingredient == "fish" else 2
			inventory.meal += 1; cooked = true
			return _done("做成一份田园热饭。在背包中食用，恢复 5 AP。")
		"eat":
			if not outcome.is_empty(): return false
			if inventory.meal <= 0: return _deny("还没有热饭。先去小屋烹饪。")
			if ap >= max_ap: return _deny("行动点已经充足，热饭留到稍后吃。")
			_checkpoint("吃饭")
			inventory.meal -= 1; ap = mini(max_ap, ap + 5)
			return _done("热饭下肚，恢复最多 5 点行动力（上限 %d）。" % max_ap)
		"chop":
			if target<0 or target>=tree_ready_days.size(): return false
			if day<int(tree_ready_days[target]): return _deny("这棵树正在恢复，第 %d 天可再次砍伐。"%tree_ready_days[target])
			if not _pay(action): return false
			tree_ready_days[target]=day+TREE_REGROW_DAYS;inventory.wood+=3
			return _done("砍伐获得木材 ×3，第 %d 天恢复。木材可以出售或用于升级。"%tree_ready_days[target])
		"feed":
			if chickens==0: return _deny("小院还没有小鸡，请先在杂货铺购买。最多养 4 只。")
			if fed: return _deny("今天已经喂过动物并收集过鸡蛋。")
			if gold < 4: return _deny("饲料需要 4 金币。")
			if not _pay(action): return false
			gold -= 4; fed = true
			var amount: int = maxi(1,chickens/2) if event == "噪声扰民" and not comforted else chickens
			inventory.egg += amount
			return _done("喂养小鸡，收集鸡蛋 ×%d。" % amount)
		"comfort":
			if chickens==0: return _deny("还没有小鸡，不需要安慰动物。")
			if event != "噪声扰民" or comforted or fed: return _deny("只有噪声事件中、喂养之前才需要安慰动物。")
			if not _pay(action): return false
			comforted = true
			return _done("小鸡安静下来了，今天的产量恢复正常。")
		"investigate":
			if target < 0 or target >= 3: return false
			if investigated.has(target): return _deny("这处线索今天已调查过，明天会出现新的记录。")
			if not _pay(action): return false
			investigated.append(target)
			var amount: int = 3 if day >= 11 else 2
			evidence = mini(20, evidence + amount)
			var entry: String = "第 %d 天 · %s：%s" % [day, CLUES[target], ["深夜排放的废水与检测报告不符。", "合同隐瞒了矿区工人的防护保障。", "土地估价与公司提交的收购文书存在矛盾。"][target]]
			archive.append(entry)
			Village.add_card(self,["water_report","work_contract","land_offer"][target])
			if target == 1 and event == "封锁矿洞": event = ""
			story.emit("证据 +%d · 记者小林" % amount, entry + "\n\n小林：保留原件。等证据达到 20 份，就可以公开真相。")
			return _done("证据 %d / 20。你离守住这片土地又近了一步。" % evidence)
		"scarecrow":
			if scarecrow: return _deny("稻草人已经在守护农场。")
			var price: int=shop_price(25)
			if gold < price or inventory.ore < 2: return _deny("建造稻草人需要 %d 金币 + 2 矿石。"%price)
			if not _pay("scarecrow"): return false
			gold -= price; inventory.ore -= 2; scarecrow = true
			return _done("稻草人建好了，之后乌鸦不再减少收成。")
	return false

func buy_seed(crop: int) -> bool:
	if not outcome.is_empty() or crop < 0 or crop >= CROPS.size(): return false
	var price: int = seed_price(crop)
	if gold < price: return _deny("金币不足。出售收成或完成订单获取金币。")
	_checkpoint("购买种子")
	gold -= price; seeds[crop] += 3
	return _done("购买 %s种子 ×3。" % CROPS[crop].name)

func item_name(key: String) -> String:
	if key.is_valid_int(): return CROPS[int(key)].name
	return {"fish":"鲜鱼", "ore":"矿石", "egg":"鸡蛋", "meal":"田园热饭","wood":"木材"}.get(key, key)

func selling_price(key: String) -> int:
	var price: int=CROPS[int(key)].price if key.is_valid_int() else {"fish":12,"ore":8,"egg":16,"meal":28,"wood":6}[key]
	if key.is_valid_int(): price=int(price*Village.factor(self,"crop"))
	return int(price*0.7) if event=="市场打压" else price

func sell(key: String) -> bool:
	if not outcome.is_empty() or not inventory.has(key): return false
	if inventory[key] <= 0: return _deny("背包里没有这种物品。")
	var price: int = selling_price(key)
	_checkpoint("出售物品")
	inventory[key] -= 1; gold += price
	return _done("出售 %s ×1，获得 %d 金币。" % [item_name(key), price])

func upgrade(tool: int) -> bool:
	if not outcome.is_empty() or tool < 0 or tool >= 4: return false
	var level: int = tools[tool]
	if level >= 5: return _deny("这件工具已经满级。")
	var price: int=shop_price(20*level)
	if gold < price or inventory.ore < 3 * level or inventory.wood<2*level: return _deny("需要 %d 金币 + %d 矿石 + %d 木材。" % [price,3*level,2*level])
	_checkpoint("升级工具")
	gold -= price; inventory.ore -= 3*level;inventory.wood-=2*level; tools[tool] += 1
	return _done("%s 升至 Lv.%d。" % [["锄头","洒水壶","鱼竿","镐子"][tool], tools[tool]])

func seed_price(crop: int) -> int:
	return shop_price(ceili(CROPS[crop].seed*3*Village.factor(self,"seed")))

func buy_chicken() -> bool:
	if not outcome.is_empty(): return false
	if chickens>=MAX_CHICKENS: return _deny("小院最多容纳 4 只小鸡。")
	var price: int=shop_price(CHICKEN_PRICE)
	if gold<price: return _deny("购买小鸡需要 %d 金币。"%price)
	_checkpoint("购买小鸡");gold-=price;chickens+=1
	return _done("购入小鸡 ×1，现有 %d / 4 只。整群饲养仍为 3 AP，每只产 1 个蛋。"%chickens)

func shop_price(base: int) -> int:
	return maxi(1,(base*maxi(0,100-reputation)+99)/100)

func gift_chance() -> int:
	return mini(100,[25,50,100][mini(gift_attempts,2)]+maxi(0,reputation))

func suggest_action(index: int) -> String:
	var p: Dictionary=plots[index]
	if not p.tilled: return "till"
	if p.crop<0: return "plant"
	if p.growth>=growth_target(p): return "harvest"
	return "water"

func donate(key: String) -> bool:
	if not outcome.is_empty(): return false
	if gift_success: return _deny("今天已经获得赠礼线索，明天再来。")
	if gift_attempts>=3: return _deny("今天的三次赠礼机会已用完。")
	if key not in ["0","1","2","3","4","5","6","7","egg","fish","ore"]: return false
	if inventory[key]<=0: return _deny("缺少可赠送的%s。"%item_name(key))
	_checkpoint("赠礼获取线索")
	inventory[key]-=1
	var chance: int=gift_chance()
	gift_attempts+=1
	gift_success=rng.randi_range(1,100)<=chance
	if gift_success:
		var amount: int=3 if day>=11 else 2
		evidence=mini(20,evidence+amount)
		var entry: String="第 %d 天 · 村民赠礼线索：村民提供了黎明工业违规往来的原始记录。"%day
		archive.append(entry)
		Village.add_card(self,["discharge_photo","wage_note","valuation_sheet"][gift_attempts%3])
		story.emit("村民的回礼 · 证据 +%d"%amount,entry+"\n\n今天已成功获得线索，赠礼机会明天刷新。")
		return _done("赠出%s ×1，获得 %d 份证据（第 %d 次赠礼）。"%[item_name(key),amount,gift_attempts])
	return _done("赠出%s ×1，暂未获得线索；下次成功率 %d%%。"%[item_name(key),gift_chance()])

func capacity_price() -> int:
	return shop_price(100 + ((max_ap-10)/2)*50)

func buy_capacity() -> bool:
	if not outcome.is_empty(): return false
	if max_ap>=MAX_AP_LIMIT: return _deny("AP 上限已达到 30。")
	var price: int=capacity_price()
	if gold<price: return _deny("提升 AP 上限需要 %d 金币。"%price)
	_checkpoint("提升 AP 上限")
	gold-=price;max_ap+=2;ap=mini(max_ap,ap+2)
	return _done("AP 上限提升至 %d，当前 AP 同时 +2；以后每天恢复至新上限。"%max_ap)

func buy_meal() -> bool:
	if not outcome.is_empty(): return false
	var price: int=shop_price(MEAL_PRICE)
	if gold<price: return _deny("购买热饭需要 %d 金币。"%price)
	_checkpoint("购买热饭")
	gold-=price;inventory.meal+=1
	return _done("购入热饭 ×1，在背包中食用可恢复 5 AP。")

func tool_effect(tool: int, level: int = -1) -> String:
	var lv: int=int(tools[tool]) if level<0 else level
	match tool:
		0: return "一次开垦 %d 格 · %d AP"%[lv,maxi(1,2-lv/3)]
		1: return "一次浇水 %d 格 · 1 AP"%lv
		2: return "每次钓鱼 %d 条 · %d AP"%[lv+1,maxi(1,3-lv/3)]
		3: return "每次挖矿 %d 块 · %d AP"%[lv+1,maxi(1,3-lv/3)]
	return ""

func _make_orders() -> void:
	orders = []
	var choice: int = rng.randi_range(0,2)
	var key: String = ["fish", "egg", str(rng.randi_range(0, CROPS.size()-1))][choice]
	orders.append({"key":"fish", "count":1, "reward":25 + day / 3, "done":false, "client":"村长的晚餐"})
	orders.append({"key":key, "count":2, "reward":48 + day, "done":false, "client":"集市补货"})

func deliver(index: int) -> bool:
	if not outcome.is_empty() or index < 0 or index >= orders.size(): return false
	var order: Dictionary = orders[index]
	if order.done: return _deny("这个订单已经完成。")
	if inventory[order.key] < order.count: return _deny("还缺少 %s。先去收集物资。" % item_name(order.key))
	_checkpoint("交付订单")
	inventory[order.key] -= order.count; gold += order.reward
	reputation += 1; order.done = true; delivered = true; missed = 0
	return _done("交付成功！获得 %d 金币和 1 声望。" % order.reward)

func _advance_crops() -> void:
	for p: Dictionary in plots:
		if p.crop>=0 and is_moist(p): p.growth=mini(p.growth+1,growth_target(p))
		p.moisture=maxi(0,int(p.get("moisture",0))-1)
		p.water=false

func next_day() -> bool:
	if not outcome.is_empty(): return false
	undo_history.clear()
	if day >= 3: missed = 0 if delivered else missed + 1
	gold -= 8
	_advance_crops()
	gift_attempts=0;gift_success=false
	day += 1; ap = max_ap; delivered = false; fed = false; cooked = false; comforted = false; investigated = []
	weather=Village.forecast(day)
	Village.advance(self)
	if weather == "小雨":
		for p: Dictionary in plots:
			if p.crop>=0: _water_plot(p)
	event = EVENTS[rng.randi_range(0, EVENTS.size()-1)] if day>=4 and village.active.size()<2 else ""
	if event=="破坏作物" and village.guards>0:
		village.guards-=1;event=""
		Village.mail(self,"王伯","帮你守住了一次农场","邻居及时拦住了破坏者。消耗一次保护，作物没有损失。","protection")
	if event == "破坏作物":
		var candidates: Array = []
		for i: int in range(plots.size()):
			if plots[i].crop >= 0: candidates.append(i)
		if not candidates.is_empty():
			var hit: int = candidates[rng.randi_range(0,candidates.size()-1)]
			plots[hit].crop=-1;plots[hit].growth=0;plots[hit].water=false;plots[hit].moisture=0;plots[hit].regrowing=false
	_make_orders()
	if gold < 0: outcome = "bad_money"
	elif missed >= 5: outcome = "bad_orders"
	elif day > 25: outcome = "bad_time"
	if not outcome.is_empty(): story.emit("土地的最后一封信", ending_text())
	elif day == 4: story.emit("第四天 · 黎明工业", "周总的代表再次来到村口。\n\n“这片土地的报价已经很优厚了。”\n\n你拒绝了。当天，农场开始出现异常。去调查，把每一份记录留下来。")
	elif day == 11: story.emit("第十一天 · 小林的来信", "小林：越来越多村民愿意作证。从今天起，每次调查可获得 3 份证据。\n\n在第 25 天结束前集齐 20 份，决定如何让真相被看见。")
	return _done("第 %d 天 · %s。维护费用 8 金币。%s" % [day, weather, "今日干扰："+event if not event.is_empty() else "村庄暂时安宁。"])

func expose(channel: int) -> bool:
	if not outcome.is_empty(): return false
	if evidence < 20: return _deny("需要集齐 20 份证据。")
	if channel < 0 or channel > 2: return false
	undo_history.clear()
	outcome = ["good_media", "good_government", "neutral"][channel]
	story.emit("麦野仍在 · 终章", ending_text())
	return _done("故事结束。你用 %d 天，留下了自己的答案。" % day)

func ending_text() -> String:
	match outcome:
		"good_media": return "小林把报道放上了头版。村民站在你的身边，黎明工业停止了收购。\n\n田野里，新一季的芽正在长出。你守住的不只是农场，还有大家选择生活的权利。\n\n好结局 · 麦野仍在"
		"good_government": return "你将原始记录递交给监管部门。污染与违规合同被调查，收购计划暂停，河流开始恢复。\n\n好结局 · 清流回到村庄"
		"neutral": return "公开的证据让公司退让。你争取到土地保留与赔偿，签下和解协议。\n\n日子继续，但你仍会留意远处的烟囱。\n\n中结局 · 有条件的春天"
		"bad_money": return "金币已经不足以支付农场的维护开销。你暂时离开了土地。\n\n坏结局 · 空了的粮仓\n建议：每天交付鲜鱼订单，出售多余收成，再投入扩建。"
		"bad_orders": return "连续五天没有交付订单，村庄的经营网络断了。收购代表趁虚而入。\n\n坏结局 · 沉默的集市\n建议：每天至少交付一个订单；调查与经营同样重要。"
		_: return "第二十五天过去，收购文件盖上了最后一个印章。\n\n坏结局 · 来迟的真相\n建议：在经营之余尽早调查，集齐证据后主动曝光。"

func _checkpoint(label: String) -> void:
	undo_history.append({"label":label,"state":to_data()})
	if undo_history.size()>512: undo_history.pop_front()

func can_undo() -> bool:
	return outcome.is_empty() and not undo_history.is_empty()

func undo() -> bool:
	if not can_undo(): return _deny("今天没有可以撤回的操作。")
	var entry: Dictionary=undo_history.pop_back()
	_restore(entry.state.duplicate(true))
	return _done("已撤回%s。AP、物资与任务进度已恢复。" % entry.label)

func to_data() -> Dictionary:
	return {"chickens":chickens,"tree_ready_days":tree_ready_days.duplicate(),"version":1,"day":day,"ap":ap,"max_ap":max_ap,"gift_attempts":gift_attempts,"gift_success":gift_success,"gold":gold,"reputation":reputation,"evidence":evidence,"missed":missed,"delivered":delivered,"inventory":inventory.duplicate(true),"seeds":seeds.duplicate(),"plots":plots.duplicate(true),"tools":tools.duplicate(),"orders":orders.duplicate(true),"investigated":investigated.duplicate(),"archive":archive.duplicate(),"event":event,"weather":weather,"fed":fed,"cooked":cooked,"comforted":comforted,"scarecrow":scarecrow,"outcome":outcome,"rng":str(rng.state),"village":village.duplicate(true)}

func save_game(path: String = SAVE_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path+".tmp", FileAccess.WRITE)
	if f == null: return _deny("存档失败：无法写入存档目录。")
	var payload: Dictionary=to_data()
	payload["undo_history"]=undo_history.duplicate(true)
	f.store_string(JSON.stringify(payload)); f.close()
	var result: Error = DirAccess.rename_absolute(path+".tmp",path)
	if result != OK: return _deny("存档失败：无法替换存档文件。")
	message.emit("进度已保存。")
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return _deny("还没有存档，请先开始游戏。")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return _deny("存档无法读取；当前游戏未被覆盖。")
	var d: Dictionary = parsed
	if not _valid_save(d): return _deny("存档数据不完整；当前游戏未被覆盖。")
	var history: Variant=d.get("undo_history",[])
	if not history is Array or history.size()>512: return _deny("撤回记录损坏；当前游戏未被覆盖。")
	for entry: Variant in history:
		if not entry is Dictionary or not entry.get("label") is String or not entry.get("state") is Dictionary: return _deny("撤回记录损坏；当前游戏未被覆盖。")
		if not _valid_save(entry.state) or entry.state.day!=d.day or not entry.state.outcome.is_empty(): return _deny("撤回记录损坏；当前游戏未被覆盖。")
	_restore(d.duplicate(true))
	undo_history.clear()
	for entry: Dictionary in history: undo_history.append(entry.duplicate(true))
	return _done("回到第 %d 天。田野还在等你。" % day)

func _restore(d: Dictionary) -> void:
	village=Village.migrate(d.get("village",Village.make(int(d.day))))
	chickens=int(d.get("chickens",2));tree_ready_days=d.get("tree_ready_days",[0,0,0,0]).duplicate()
	for i: int in range(tree_ready_days.size()): tree_ready_days[i]=int(tree_ready_days[i])
	gift_attempts=int(d.get("gift_attempts",0));gift_success=d.get("gift_success",false)
	day=int(d.day); max_ap=int(d.get("max_ap",10)); ap=int(d.ap); gold=int(d.gold); reputation=int(d.reputation); evidence=int(d.evidence); missed=int(d.missed)
	delivered=d.delivered; inventory=d.inventory;inventory["wood"]=int(inventory.get("wood",0)); seeds=d.seeds; plots=d.plots; tools=d.tools; orders=d.orders
	investigated=d.investigated; archive=d.archive; event=d.event; weather=d.weather; fed=d.fed; cooked=d.cooked
	comforted=d.comforted; scarecrow=d.scarecrow; outcome=d.outcome; rng.state=int(d.rng)
	for p: Dictionary in plots:
		p.crop=int(p.crop);p.growth=int(p.growth);p.regrowing=p.get("regrowing",false)
		p.moisture=int(p.get("moisture",1 if p.water else 0))
	for o: Dictionary in orders: o.count=int(o.count); o.reward=int(o.reward)
	for key: String in inventory: inventory[key]=int(inventory[key])
	for i: int in range(seeds.size()): seeds[i]=int(seeds[i])
	for i: int in range(tools.size()): tools[i]=int(tools[i])
	for i: int in range(investigated.size()): investigated[i]=int(investigated[i])
	if not d.has("village"): Village.initialize(self)

func _valid_save(d: Dictionary) -> bool:
	if d.has("village") and not Village.valid(d.village): return false
	if not _number(d.get("chickens",2)) or d.get("chickens",2)<0 or d.get("chickens",2)>MAX_CHICKENS: return false
	var trees: Variant=d.get("tree_ready_days",[0,0,0,0])
	if not trees is Array or trees.size()!=4: return false
	for ready: Variant in trees:
		if not _number(ready) or ready<0: return false
	for key: String in to_data():
		if key not in ["max_ap","gift_attempts","gift_success","village","chickens","tree_ready_days"] and not d.has(key): return false
	if d.version != 1 or not d.plots is Array or d.plots.size()!=24 or not d.seeds is Array or d.seeds.size()!=8 or not d.tools is Array or d.tools.size()!=4: return false
	if not d.inventory is Dictionary or not d.orders is Array or d.orders.size()!=2: return false
	if not d.investigated is Array or not d.archive is Array: return false
	for key: String in inventory:
		if key=="wood" and not d.inventory.has(key): continue
		if not d.inventory.has(key) or not _number(d.inventory[key]) or d.inventory[key]<0: return false
	for key: String in ["day","ap","gold","reputation","evidence","missed"]:
		if not _number(d[key]): return false
	var saved_attempts: Variant=d.get("gift_attempts",0)
	if not _number(saved_attempts) or saved_attempts<0 or saved_attempts>3 or not d.get("gift_success",false) is bool: return false
	var saved_max: Variant=d.get("max_ap",10)
	if not _number(saved_max) or saved_max<10 or saved_max>MAX_AP_LIMIT: return false
	if d.day<1 or d.day>26 or d.ap<0 or d.ap>saved_max or d.evidence<0 or d.evidence>20: return false
	for key: String in ["fed","cooked","comforted","scarecrow","delivered"]:
		if not d[key] is bool: return false
	for key: String in ["event","weather","outcome","rng"]:
		if not d[key] is String: return false
	if not d.rng.is_valid_int(): return false
	for v: Variant in d.tools:
		if not _number(v) or v<1 or v>5: return false
	for v: Variant in d.seeds:
		if not _number(v) or v<0: return false
	for p: Variant in d.plots:
		if not p is Dictionary: return false
		for key: String in ["tilled","crop","growth","water"]:
			if not p.has(key): return false
		if not p.tilled is bool or not p.water is bool or not _number(p.crop) or not _number(p.growth): return false
		if p.crop < -1 or p.crop >= 8 or p.growth<0 or p.growth>6: return false
		if not _number(p.get("moisture",0)) or p.get("moisture",0)<0 or p.get("moisture",0)>2 or not p.get("regrowing",false) is bool: return false
	for o: Variant in d.orders:
		if not o is Dictionary: return false
		for key: String in ["key","count","reward","done","client"]:
			if not o.has(key): return false
		if not o.key is String or not inventory.has(o.key) or not _number(o.count) or o.count<1 or not _number(o.reward) or o.reward<0 or not o.done is bool or not o.client is String: return false
	for v: Variant in d.investigated:
		if not _number(v) or v<0 or v>2: return false
	for v: Variant in d.archive:
		if not v is String: return false
	return true

func _number(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floor(float(v))
