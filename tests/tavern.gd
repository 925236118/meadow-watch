extends SceneTree
const State=preload("res://scripts/farm_state.gd")
const Village=preload("res://scripts/village_rules.gd")
const Dialogue=preload("res://scripts/villager_dialogue.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok: print("[PASS] "+label)
	else: failures+=1;printerr("[FAIL] "+label)
func _initialize() -> void:
	var s: RefCounted=State.new()
	for i: int in range(4): Village.talk(s,i)
	var before: Dictionary=s.to_data()
	check(Village.drink(s) and s.ap==int(before.ap)-1,"drink costs exactly one AP after daily conversations")
	var guests: int=0;var exact: bool=true;var talk_flags: bool=true
	for p: Dictionary in Village.PEOPLE:
		var delta: int=s.village.people[p.id].points-before.village.people[p.id].points
		if delta>0: guests+=1
		exact=exact and delta in [0,2]
		talk_flags=talk_flags and s.village.people[p.id].talk_day==before.village.people[p.id].talk_day
	check(guests in [2,3] and exact,"two or three distinct residents gain exactly quarter star")
	check(talk_flags and s.village.talk_count==before.village.talk_count,"drink neither uses free talks nor changes daily affection flags")
	check(s.village.mail.back().kind=="rumor" and s.village.mail.size()>before.village.mail.size(),"each drink gives a rumor letter")
	var after: Dictionary=s.to_data()
	check(s.undo() and s.to_data()==before,"drink undo restores AP, relationships, mail and random state")
	check(Village.drink(s) and s.to_data()==after,"undo replay cannot reroll guests or rewards")
	check(Village.drink(s) and s.ap==int(after.ap)-1,"another drink is possible independently of first-talk limits")
	s.save_game("user://tavern-test.json");var saved: Dictionary=s.to_data();var loaded: RefCounted=State.new()
	check(loaded.load_game("user://tavern-test.json") and loaded.to_data()==saved,"drink outcome persists through save/load")
	s.ap=0;before=s.to_data();var steps: int=s.undo_history.size()
	check(not Village.drink(s) and s.to_data()==before and s.undo_history.size()==steps,"zero AP drink fails without relationship or RNG changes")
	s.new_game();s.village.known=[]
	check(Village.drink(s) and s.village.known.size()==1 and s.village.mail.back().title.begins_with("小道消息"),"drink prioritizes an undiscovered planned event")
	s.new_game();s.day=25;s.village.active=[];s.village.planned=[]
	check(Village.drink(s) and s.village.mail.back().body.contains("明日"),"weather chatter still supplies a message when no event exists")
	for i: int in range(4):
		s.new_game();var openings: Dictionary={}
		for level: int in range(6):
			s.village.people[Village.PEOPLE[i].id].points=level*8
			var spoken: String=Dialogue.line(s,i)
			openings[spoken.split("\n\n")[0]]=true
			check(not spoken.contains(Dialogue.PROFILES[i].temperament) and not spoken.contains(Dialogue.PROFILES[i].background),"internal profile is not presented as an NPC dossier: %d/%d"%[i,level])
		check(openings.size()==6,"each relationship stage has distinct voice: "+Village.PEOPLE[i].id)
		s.village.request={};s.village.active=[];s.chickens=0;s.ap=10
		s.weather="晴天";var sunny: String=Dialogue.line(s,i)
		s.weather="小雨";var weather_reacts: bool=false
		for count: int in range(8):
			s.village.talk_count=count
			if Dialogue.line(s,i).contains(Dialogue.RAIN[i]): weather_reacts=true
		check(weather_reacts,"weather changes resident's observations: "+Village.PEOPLE[i].id)
		s.weather="晴天";s.village.active=[Village.EVENTS[0].duplicate(true)];s.village.talk_count=1
		var event_reacts: bool=false
		for count: int in range(8):
			s.village.talk_count=count
			if Dialogue.line(s,i).contains(Dialogue.EVENTS.mine_repair[i]): event_reacts=true
		check(event_reacts,"resident responds to mine maintenance in own voice: "+Village.PEOPLE[i].id)
	print("[RESULT] %d tavern and narrative checks, %d failures"%[checks,failures]);quit(1 if failures>0 else 0)
