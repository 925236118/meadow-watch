extends SceneTree
const State=preload("res://scripts/farm_state.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if ok: print("[PASS] "+text)
	else: failures+=1;printerr("[FAIL] "+text)
func _initialize() -> void:
	var s: RefCounted=State.new()
	check(not s.buy_capacity() and not s.can_undo(),"unaffordable capacity purchase has no side effects")
	s.gold=10000;var before: Dictionary=s.to_data()
	check(s.buy_capacity() and s.max_ap==12 and s.ap==12 and s.gold==9900,"capacity adds two current and maximum AP")
	check(s.undo() and s.to_data()==before,"capacity purchase can be completely undone")
	s.buy_capacity();s.ap=1;s.next_day()
	check(s.ap==12,"daily refill uses purchased capacity")
	s.ap=2;before=s.to_data();s.buy_meal()
	check(s.inventory.meal==1 and s.gold==9857 and s.ap==2,"meal purchase consumes only money")
	s.act("eat");check(s.ap==7,"purchased food restores five AP")
	s.undo();s.undo();check(s.to_data()==before,"food consumption and purchase undo safely")
	s.ap=11;s.inventory.meal=1;s.act("eat")
	check(s.ap==12,"food capped at upgraded maximum")
	s.save_game("user://economy_test.json")
	var copy: RefCounted=State.new()
	check(copy.load_game("user://economy_test.json") and copy.max_ap==12,"capacity survives save and load")
	var legacy: Dictionary=State.new().to_data();legacy.erase("max_ap");legacy.erase("gift_attempts");legacy.erase("gift_success")
	var f: FileAccess=FileAccess.open("user://economy_legacy.json",FileAccess.WRITE);f.store_string(JSON.stringify(legacy));f.close()
	check(copy.load_game("user://economy_legacy.json") and copy.max_ap==10,"old save defaults to ten AP")
	s.new_game();s.reputation=20;s.gold=1000
	check(s.shop_price(100)==80 and s.shop_price(35)==28 and s.gift_chance()==45,"reputation discounts and lottery bonus")
	s.gift_attempts=1;check(s.gift_chance()==70,"reputation adds to second gift chance")
	s.gift_attempts=2;check(s.gift_chance()==100,"third gift remains guaranteed")
	s.reputation=100;check(s.shop_price(35)==1 and s.gift_chance()==100,"prices stay positive and chances capped")
	s.new_game();s.ap=0
	check(s.plot_action(3,"plant") and s.ap==0 and s.seeds[0]==1,"sowing remains available at zero AP")
	check(s.suggest_action(6)=="till" and s.suggest_action(4)=="plant" and s.suggest_action(1)=="water" and s.suggest_action(0)=="harvest","context chooses correct farm actions")
	s.event="市场打压";s.inventory.fish=1;var coins: int=s.gold
	check(s.selling_price("fish")==8 and s.sell("fish") and s.gold==coins+8,"displayed pressure price matches sale settlement")
	s.new_game();s.gold=10000
	for i: int in range(10): s.buy_capacity()
	check(s.max_ap==30 and not s.buy_capacity(),"capacity capped at thirty")
	s.new_game();s.tools[0]=2;s.plot_action(6,"till")
	check(s.plots[6].tilled and s.plots[7].tilled and not s.plots[8].tilled,"level two hoe tills two tiles")
	s.undo();s.tools[0]=5;s.plot_action(11,"till")
	check(not s.plots[12].tilled,"bulk hoe does not cross rows")
	for lv: int in range(1,6):
		s.new_game();s.tools[2]=lv;s.act("fish")
		check(s.inventory.fish==lv+1 and s.ap==10-s.cost("fish"),"fishing level %d produces visible gains"%lv)
		s.new_game();s.tools[3]=lv;s.act("mine")
		check(s.inventory.ore==lv+1 and s.ap==10-s.cost("mine"),"mining level %d produces visible gains"%lv)
	# Choose a deterministic sequence that misses the first two chances.
	var lottery: RandomNumberGenerator=RandomNumberGenerator.new()
	var chosen: int=0
	for seed_value: int in range(1,100):
		lottery.seed=seed_value
		var first: int=lottery.randi_range(1,100)
		var second: int=lottery.randi_range(1,100)
		if first>25 and second>50: chosen=seed_value;break
	s.new_game();s.rng.seed=chosen;s.inventory.fish=4;s.ap=0
	check(s.donate("fish") and not s.gift_success and s.gift_attempts==1,"first gift applies twenty-five percent chance")
	check(s.donate("fish") and not s.gift_success and s.gift_attempts==2,"second gift applies fifty percent chance")
	check(s.donate("fish") and s.gift_success and s.gift_attempts==3 and s.evidence==2 and s.ap==0,"third gift guaranteed and costs no AP")
	check(not s.donate("fish") and s.inventory.fish==1,"successful day stops further gifts")
	before=s.to_data();s.undo();s.donate("fish")
	check(s.to_data()==before,"undo restores gift RNG rather than enabling rerolls")
	s.save_game("user://economy_test.json");copy.load_game("user://economy_test.json")
	check(copy.gift_success and copy.gift_attempts==3,"daily lottery state persisted")
	s.next_day();check(not s.gift_success and s.gift_attempts==0,"gift opportunities reset each day")
	s.new_game();before=s.to_data();check(not s.donate("fish") and s.to_data()==before,"empty inventory cannot consume lottery attempt")
	for path: String in ["user://economy_test.json","user://economy_legacy.json"]: DirAccess.remove_absolute(path)
	print("[RESULT] %d economy checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
