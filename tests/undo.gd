extends SceneTree
const State=preload("res://scripts/farm_state.gd")
var failures: int=0
var checks: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("[FAIL] "+text)
	else: print("[PASS] "+text)

func _initialize() -> void:
	for action: String in ["till","plant","water","harvest","fish","mine","cook","eat","feed","comfort","investigate","scarecrow","buy","sell","upgrade","deliver"]:
		var s: RefCounted=State.new()
		match action:
			"cook","sell","deliver": s.inventory.fish=2
			"eat": s.ap=0;s.inventory.meal=1
			"comfort": s.event="噪声扰民"
			"investigate": s.event="封锁矿洞"
			"scarecrow","upgrade": s.inventory.ore=10
		var before: Dictionary=s.to_data()
		var ok: bool=false
		match action:
			"till": ok=s.plot_action(6,action)
			"plant": ok=s.plot_action(3,action,2)
			"water": ok=s.plot_action(1,action)
			"harvest": ok=s.plot_action(0,action)
			"buy": ok=s.buy_seed(0)
			"sell": ok=s.sell("fish")
			"upgrade": ok=s.upgrade(0)
			"deliver": ok=s.deliver(0)
			"investigate": ok=s.act(action,1)
			_: ok=s.act(action)
		check(ok and s.can_undo() and s.undo() and s.to_data()==before,"complete state restored: "+action)
	var s: RefCounted=State.new()
	var initial: Dictionary=s.to_data()
	s.act("fish");s.act("fish");s.act("investigate",0)
	check(s.ap==0,"decision sequence exhausts AP")
	check(not s.act("mine") and s.undo_history.size()==3,"failed action adds no undo step")
	check(s.undo() and s.ap==4 and s.evidence==0 and s.archive.is_empty(),"undo at zero AP restores ability to work")
	s.undo();s.undo()
	check(s.to_data()==initial and not s.can_undo(),"multi-step undo returns exactly to start")
	s.act("fish");s.deliver(0);s.save_game("user://undo_test.json")
	var other: RefCounted=State.new()
	check(other.load_game("user://undo_test.json") and other.undo_history.size()==2,"save preserves today's undo history")
	other.undo();other.undo()
	check(other.to_data()==initial,"loaded undo restores inventory, order, gold and AP")
	s.next_day();check(not s.can_undo(),"next day clears undo history")
	s.act("fish");s.new_game();check(not s.can_undo(),"new game clears undo history")
	s.act("fish");s.evidence=20;s.expose(0)
	check(not s.can_undo() and not s.undo(),"final exposure ends undo availability")
	var f: FileAccess=FileAccess.open("user://undo_bad.json",FileAccess.WRITE)
	var invalid: Dictionary=initial.duplicate(true);invalid.undo_history=[{"label":"bad","state":{}}]
	f.store_string(JSON.stringify(invalid));f.close()
	other.act("fish");var unchanged: Dictionary=other.to_data()
	check(not other.load_game("user://undo_bad.json") and other.to_data()==unchanged,"corrupt history rejected without changing live state")
	f=FileAccess.open("user://undo_bad.json",FileAccess.WRITE);f.store_string(JSON.stringify(initial));f.close()
	check(other.load_game("user://undo_bad.json") and not other.can_undo(),"legacy save without history remains compatible")
	DirAccess.remove_absolute("user://undo_test.json");DirAccess.remove_absolute("user://undo_bad.json")
	print("[RESULT] %d undo checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
