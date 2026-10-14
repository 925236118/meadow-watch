extends SceneTree
const State=preload("res://scripts/farm_state.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("[PASS] "+label)
	else: failures+=1;printerr("[FAIL] "+label)

func _initialize() -> void:
	var s: RefCounted=State.new()
	check(s.chickens==0 and s.inventory.wood==0 and s.seeds==[2,0,0,0,0,1,0,0],"new farm starts with no chickens and just three seeds")
	check(s.plots[0].growth==2 and s.plots[1].crop==0 and s.plots[2].crop==1,"starter crops retain a harvest and two growing plants")
	var before: Dictionary=s.to_data()
	check(not s.act("feed") and s.to_data()==before and not s.can_undo(),"empty flock cannot spend AP or fodder money")
	s.gold=39;before=s.to_data()
	check(not s.buy_chicken() and s.to_data()==before,"unaffordable chicken purchase leaves state unchanged")
	s.gold=1000;before=s.to_data()
	check(s.buy_chicken() and s.chickens==1 and s.gold==960 and s.ap==10,"chicken purchase costs forty coins and no AP")
	check(s.undo() and s.to_data()==before,"chicken purchase fully undoable")
	s.reputation=20;check(s.buy_chicken() and s.gold==968,"chicken price receives reputation discount")
	for count: int in range(1,5):
		s.new_game();s.gold=1000
		for i: int in range(count): s.buy_chicken()
		before=s.to_data();var gold: int=s.gold
		check(s.act("feed") and s.ap==7 and s.gold==gold-4 and s.inventory.egg==count,"flock of %d costs fixed three AP and yields %d eggs"%[count,count])
		var after: Dictionary=s.to_data()
		check(not s.act("feed") and s.to_data()==after,"flock fed only once daily: %d"%count)
		check(s.undo() and s.to_data()==before,"feeding undo restores eggs, fodder, AP and daily flag: %d"%count)
	check(s.chickens==4,"four chickens bought")
	before=s.to_data();check(not s.buy_chicken() and s.to_data()==before,"fifth chicken rejected without payment")
	s.event="噪声扰民";s.act("feed")
	check(s.inventory.egg==2,"noise halves flock egg output")
	s.undo();s.act("comfort");s.act("feed")
	check(s.inventory.egg==4,"comfort restores purchased flock yield")
	s.new_game();before=s.to_data()
	check(not s.act("chop",-1) and not s.act("chop",4) and s.to_data()==before,"invalid tree cannot cost AP")
	check(s.act("chop",0) and s.ap==8 and s.inventory.wood==3 and s.tree_ready_days[0]==4,"chopping costs two AP, yields three wood and regrows in three days")
	var chopped: Dictionary=s.to_data()
	check(not s.act("chop",0) and s.to_data()==chopped,"tree stump cannot be harvested repeatedly")
	check(s.undo() and s.to_data()==before,"tree and wood undo together")
	s.act("chop",0);s.gold=1000
	for date: int in [2,3]:
		s.delivered=true;s.next_day();check(not s.act("chop",0),"tree still recovering on day %d"%date)
	s.delivered=true;s.next_day()
	check(s.day==4 and s.act("chop",0) and s.inventory.wood==6,"same tree becomes usable on announced recovery day")
	var gold: int=s.gold;var ap: int=s.ap
	check(s.selling_price("wood")==6 and s.sell("wood") and s.gold==gold+6 and s.ap==ap,"wood sells for six coins and zero AP")
	s.event="市场打压";gold=s.gold
	check(s.selling_price("wood")==4 and s.sell("wood") and s.gold==gold+4,"wood displayed sale price follows existing market pressure")
	s.new_game();s.gold=1000;s.inventory.ore=10
	before=s.to_data()
	check(not s.upgrade(0) and s.to_data()==before,"tool upgrade requires wood as well as money and ore")
	s.inventory.wood=2;before=s.to_data()
	check(s.upgrade(0) and s.gold==980 and s.inventory.ore==7 and s.inventory.wood==0 and s.tools[0]==2,"level one upgrade consumes twenty coins, three ore, two wood")
	check(s.undo() and s.to_data()==before,"upgrade undo restores all three resources")
	s.act("chop",0);s.buy_chicken()
	var expected: Dictionary=s.to_data();s.save_game("user://pioneer-test.json")
	var loaded: RefCounted=State.new()
	check(loaded.load_game("user://pioneer-test.json") and loaded.to_data()==expected,"save/load retains purchased chickens, wood, stumps and undo history")
	var old: Dictionary=expected.duplicate(true);old.erase("chickens");old.erase("tree_ready_days");old.inventory.erase("wood")
	check(s._valid_save(old),"old saves without new resources remain accepted")
	loaded._restore(old)
	check(loaded.chickens==2 and loaded.inventory.wood==0 and loaded.tree_ready_days==[0,0,0,0],"old saves keep former two-chicken flock and initialize forest and wood")
	var bad: Dictionary=expected.duplicate(true);bad.chickens=5;check(not s._valid_save(bad),"over-cap flock save rejected")
	bad=expected.duplicate(true);bad.tree_ready_days=[0];check(not s._valid_save(bad),"missing tree save data rejected")
	bad=expected.duplicate(true);bad.inventory.wood=-1;check(not s._valid_save(bad),"negative wood save rejected")
	# Real two-day opening: purchase a bird, feed, collect the starter crop and fish.
	s.new_game();s.buy_chicken();s.act("fish");s.deliver(0);s.plot_action(0,"harvest");s.sell("0");s.act("feed");s.sell("egg");s.plot_action(1,"water")
	check(s.ap==1 and s.chickens==1 and s.gold==103 and s.delivered,"reduced opening stock supports buying, feeding, farming and first-day order")
	s.next_day();s.act("chop",0);s.act("mine");s.act("fish");s.deliver(0)
	check(s.ap==2 and s.inventory.wood==3 and s.inventory.ore==2 and s.gold==120 and s.outcome.is_empty(),"second day can gather upgrade materials and keep farm solvent")
	print("[RESULT] %d pioneer checks, %d failures"%[checks,failures]);quit(1 if failures>0 else 0)
