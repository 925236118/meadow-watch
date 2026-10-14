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
	s.seeds[3]=1;s.plot_action(3,"plant",3);s.plot_action(3,"water")
	s._advance_crops()
	check(s.plots[3].growth==1 and s.is_moist(s.plots[3]) and not s.plots[3].water,"pumpkin retains moisture into second day")
	var before_ap: int=s.ap
	check(not s.plot_action(3,"water") and s.ap==before_ap,"unnecessary pumpkin watering is free rejection")
	s._advance_crops()
	check(s.plots[3].growth==2 and not s.is_moist(s.plots[3]),"one irrigation supplies exactly two growth days")
	s._advance_crops();check(s.plots[3].growth==2,"dry pumpkin still requires irrigation")
	var irrigation: int=1
	while s.plots[3].growth<5:
		if not s.is_moist(s.plots[3]): s.plot_action(3,"water");irrigation+=1
		s._advance_crops()
	check(irrigation==3 and s.plot_action(3,"harvest") and s.ap==5,"pumpkin full cycle costs three water AP and two harvest AP")
	check(s.inventory["3"]==2 and s.selling_price("3")==31,"pumpkin yield two and repriced to thirty-one")
	for crop_id: int in [2,7]:
		s.new_game();s.seeds[crop_id]=1;s.plot_action(3,"plant",crop_id)
		var seeds_before: int=s.seeds[crop_id]
		for i: int in range(s.CROPS[crop_id].days):
			s.ap=10;s.plot_action(3,"water");s._advance_crops()
		check(s.growth_target(s.plots[3])==s.CROPS[crop_id].days and s.plot_action(3,"harvest"),"long first maturity for crop %d"%crop_id)
		check(s.plots[3].crop==crop_id and s.plots[3].regrowing and s.growth_target(s.plots[3])==2,"harvest retains plant for two-day regrowth")
		var snapshot: Dictionary=s.to_data()
		for i: int in range(2):
			s.ap=10;s.plot_action(3,"water");s._advance_crops()
		check(s.plot_action(3,"harvest") and s.inventory[str(crop_id)]==4 and s.seeds[crop_id]==seeds_before,"second harvest requires no new seed")
		s.undo();check(s.plots[3].growth==2 and s.plots[3].regrowing and s.inventory[str(crop_id)]==2,"undo restores regrowth phase and inventory")
		s.save_game("user://cycles_test.json")
		var copy: RefCounted=State.new()
		check(copy.load_game("user://cycles_test.json") and copy.plots[3]==s.plots[3],"save restores regrowth state")
	s.new_game();s.seeds[3]=1;s.plot_action(3,"plant",3);s.plot_action(3,"water");s._advance_crops()
	s.save_game("user://cycles_test.json");var copy: RefCounted=State.new();copy.load_game("user://cycles_test.json")
	check(copy.plots[3].moisture==1 and copy.is_moist(copy.plots[3]),"save retains next-day pumpkin moisture")
	var legacy: Dictionary=s.to_data()
	for p: Dictionary in legacy.plots: p.erase("moisture");p.erase("regrowing")
	var f: FileAccess=FileAccess.open("user://cycles_legacy.json",FileAccess.WRITE);f.store_string(JSON.stringify(legacy));f.close()
	check(copy.load_game("user://cycles_legacy.json") and copy.plots[3].has("moisture"),"legacy crop saves gain default fields")
	s.new_game();s.plot_action(0,"harvest")
	check(s.plots[0].crop==-1,"single-harvest crops still clear soil")
	for path: String in ["user://cycles_test.json","user://cycles_legacy.json"]: DirAccess.remove_absolute(path)
	print("[RESULT] %d crop checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
