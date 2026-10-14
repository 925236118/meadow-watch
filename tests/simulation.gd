extends SceneTree
const State = preload("res://scripts/farm_state.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("[FAIL] "+label)
	else: print("[PASS] "+label)

func _initialize() -> void:
	var s: RefCounted=State.new()
	check(s.ap==10 and s.plots.size()==24,"fresh farm has 10 AP and 24 plots")
	check(not s.plot_action(6,"plant",0) and s.ap==10,"invalid planting costs nothing")
	check(s.plot_action(6,"till") and s.ap==8,"tilling costs 2 AP")
	check(s.plot_action(6,"plant",0) and s.ap==8 and s.seeds[0]==1,"plant consumes one seed and zero AP")
	check(s.plot_action(6,"water") and s.ap==7,"watering consumes AP")
	check(not s.plot_action(6,"water") and s.ap==7,"duplicate watering rejected without AP cost")
	check(not s.plot_action(6,"harvest") and s.ap==7,"immature harvest rejected")
	s.next_day()
	check(s.plots[6].growth==1 and not s.plots[6].water and s.ap==10,"watered crop grows only at day transition")
	s.next_day()
	check(s.plots[6].growth==1,"dry crop does not grow")
	s.plot_action(6,"water");s.next_day()
	check(s.plots[6].growth==2,"two watered nights ripen carrot")
	s.event="";check(s.plot_action(6,"harvest") and s.inventory["0"]==2,"harvest goes to inventory")
	check(s.plots[6].crop==-1 and s.plots[6].tilled,"harvest keeps cultivated soil")
	s.ap=0;check(not s.act("fish") and s.inventory.fish==0,"insufficient AP prevents rewards")
	s.ap=10;s.event="污染水源";s.act("fish");check(s.inventory.fish==1,"pollution halves fishing yield")
	s.event="封锁矿洞";var before: int=s.ap
	check(not s.act("mine") and s.ap==before,"blocked mine spends no AP")
	check(s.act("investigate",1) and s.event=="" and s.evidence==2,"mine investigation lifts blockade")
	check(not s.act("investigate",1),"each clue investigated once per day")
	s.new_game();s.act("fish");s.deliver(0)
	check(s.delivered and s.gold==115 and s.reputation==1,"order consumes goods and grants gold and reputation")
	before=s.gold;check(not s.deliver(0) and s.gold==before,"order cannot be delivered twice")
	s.act("cook");check(s.inventory.meal==1,"cooking creates food")
	before=s.ap;s.act("eat");check(s.ap==mini(10,before+5) and s.inventory.meal==0,"food restores capped AP")
	check(not s.act("cook"),"one cooking action per day")
	s.new_game();s.chickens=2;s.event="噪声扰民";s.act("comfort");s.act("feed")
	check(s.inventory.egg==2 and s.gold==86,"comfort restores egg yield")
	check(not s.act("feed"),"animals can only be fed once daily")
	s.new_game();s.inventory.ore=30;s.inventory.wood=30;s.gold=1000
	for i: int in range(4): s.upgrade(0)
	check(s.tools[0]==5 and s.cost("till")==1,"level 5 hoe reduces AP and caps upgrades")
	check(not s.upgrade(0),"max tool level cannot be exceeded")
	s.tools[1]=3;s.plot_action(6,"till");s.plot_action(6,"plant");s.plot_action(7,"till");s.plot_action(7,"plant");s.plot_action(6,"water")
	check(s.plots[6].water and s.plots[7].water,"upgraded watering can irrigates neighboring plots")
	s.new_game();s.inventory["0"]=2;s.event="市场打压";before=s.gold;s.sell("0")
	check(s.gold-before==11,"market pressure reduces sale price by 30 percent")
	s.gold=1000;s.inventory.ore=10;s.act("scarecrow");s.event="乌鸦袭击";s.plot_action(0,"harvest")
	check(s.inventory["0"]==3,"scarecrow prevents crow harvest loss")
	# Reach the good ending using an economically viable policy, not injected evidence.
	s.new_game()
	for i: int in range(10):
		s.act("fish");s.deliver(0);s.act("investigate",i%3)
		if s.evidence>=20: break
		s.next_day()
	check(s.evidence==20 and s.gold>0 and s.missed==0,"ten-day fishing/order/investigation route is viable")
	check(s.expose(0) and s.outcome=="good_media","20 real collected evidence triggers good ending")
	before=s.gold;check(not s.sell("fish") and not s.next_day() and s.gold==before,"finished story locks economic and turn actions")
	for channel: int in [1,2]:
		s.new_game();s.evidence=20;s.expose(channel)
		check(s.outcome==["good_media","good_government","neutral"][channel],"exposure channel %d has distinct outcome"%channel)
	s.new_game();s.gold=7;s.next_day();check(s.outcome=="bad_money","insolvency triggers failure")
	s.new_game();s.gold=1000
	for i: int in range(7): s.next_day()
	check(s.outcome=="bad_orders","five missed orders after tutorial triggers failure")
	s.new_game();s.gold=10000
	for i: int in range(25):
		s.inventory.fish=1;s.deliver(0);s.next_day()
	check(s.outcome=="bad_time" and s.day==26,"acquisition deadline triggers failure")
	# Save/load round trip, rejection of malformed data and RNG continuation.
	s.new_game();s.act("fish");s.act("investigate",0)
	check(s.save_game("user://test_save.json"),"save written")
	var expected: Dictionary=s.to_data()
	s.next_day()
	var expected_event: String=s.event
	check(s.load_game("user://test_save.json") and s.to_data()==expected,"JSON round trip restores complete state")
	s.next_day();check(s.event==expected_event,"save restores RNG sequence")
	var f: FileAccess=FileAccess.open("user://bad_save.json",FileAccess.WRITE)
	f.store_string('{"version":1}');f.close()
	before=s.day;check(not s.load_game("user://bad_save.json") and s.day==before,"malformed save does not overwrite state")
	expected=s.to_data();expected.plots[0].crop="invalid"
	f=FileAccess.open("user://bad_save.json",FileAccess.WRITE);f.store_string(JSON.stringify(expected));f.close()
	check(not s.load_game("user://bad_save.json") and s.day==before,"invalid nested save rejected safely")
	DirAccess.remove_absolute("user://test_save.json");DirAccess.remove_absolute("user://bad_save.json")
	print("[RESULT] %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

