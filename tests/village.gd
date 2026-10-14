extends SceneTree
const State=preload("res://scripts/farm_state.gd")
const Village=preload("res://scripts/village_rules.gd")
var checks: int=0
var failures: int=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if ok: print("[PASS] "+label)
	else: failures+=1;printerr("[FAIL] "+label)

func fixture(event_index: int) -> Dictionary:
	var event: Dictionary=Village.EVENTS[event_index].duplicate(true)
	event.merge({"uid":99,"start":1,"finish":3})
	return event

func letter_kind(s: RefCounted, kind: String) -> int:
	var count: int=0
	for letter: Dictionary in s.village.mail:
		if letter.kind==kind: count+=1
	return count

func _initialize() -> void:
	var s: RefCounted=State.new()
	check(s.village.people.size()==4 and Village.unread(s)==3,"four villagers and welcome, request, rumor letters")
	var initial: Dictionary=s.to_data()
	var id: int=s.village.mail[0].id
	check(Village.read_mail(s,id) and Village.unread(s)==2,"reading updates unread count")
	check(not Village.read_mail(s,id),"already-read letter is not another action")
	check(s.undo() and s.to_data()==initial,"reading can be undone completely")
	check(Village.talk(s,0) and s.ap==10 and s.village.people.elder.points==2 and Village.free_talks(s)==2,"first conversation is free and adds quarter star")
	var after_talk: Dictionary=s.to_data()
	check(Village.talk(s,0) and s.ap==10 and s.village.people.elder.points==2 and s.village.talk_count==2,"repeated conversation allowed but affection gained only once daily")
	check(s.undo() and s.to_data()==after_talk,"repeated talk undo restores global free quota")
	check(s.undo() and s.to_data()==initial,"talk undo restores AP, bond and rumor RNG")
	s.ap=0
	for i: int in range(3): check(Village.talk(s,0) and s.ap==0,"free conversation available at zero AP: %d"%i)
	check(s.village.people.elder.points==2 and Village.free_talks(s)==0,"three repeated conversations use global quota without farming affection")
	var exhausted: Dictionary=s.to_data();var undo_size: int=s.undo_history.size()
	check(not Village.talk(s,1) and s.to_data()==exhausted and s.undo_history.size()==undo_size,"fourth conversation at zero AP fails without side effects")
	s.ap=2
	check(Village.talk(s,0) and s.ap==1 and s.village.people.elder.points==2,"fourth conversation consumes one AP without extra affection")
	check(Village.talk(s,0) and s.ap==0 and s.village.talk_count==5,"fifth conversation remains allowed and costs one AP")
	var paid_state: Dictionary=s.to_data();s.save_game("user://talk-quota-test.json")
	var saved_talk: RefCounted=State.new();saved_talk.load_game("user://talk-quota-test.json")
	check(saved_talk.to_data()==paid_state and Village.free_talks(saved_talk)==0,"conversation count and free quota survive save/load")
	check(saved_talk.undo() and saved_talk.ap==1 and saved_talk.village.talk_count==4,"paid conversation undo restores AP and conversation count")
	s.new_game()
	for i: int in range(4): Village.talk(s,i)
	check(s.ap==9 and s.village.talk_count==4,"three free conversations shared across villagers, fourth costs AP")
	var one_gain_each: bool=true
	for person: Dictionary in s.village.people.values(): one_gain_each=one_gain_each and person.points==2
	check(one_gain_each,"each villager gets one daily affection gain independently")
	s.delivered=true;s.next_day()
	check(Village.free_talks(s)==3 and Village.talk(s,0) and s.ap==10 and s.village.people.elder.points==4,"next day resets free quota and daily affection eligibility")
	s.new_game()
	s.inventory.egg=3
	var before_gift: Dictionary=s.to_data()
	check(Village.gift(s,0,"egg") and s.inventory.egg==2 and s.ap==10 and s.village.people.elder.points==4,"favorite gift adds half star at zero AP")
	var after_gift: Dictionary=s.to_data()
	check(not Village.gift(s,0,"egg") and s.to_data()==after_gift,"daily gift limit is per villager")
	check(s.undo() and s.to_data()==before_gift,"gift undo restores inventory and generated letters")
	s.inventory.fish=1;Village.gift(s,0,"fish")
	check(s.village.people.elder.points==2,"neutral gift adds quarter star")
	s.day+=1;s.inventory.ore=1;Village.gift(s,0,"ore")
	check(s.village.people.elder.points==0,"disliked gift removes quarter star with zero floor")
	Village._bond(s,"elder",40)
	check(s.village.people.elder.points==40 and s.village.people.elder.milestones==[1,2,3,4,5] and letter_kind(s,"friendship")==5,"all five star milestones send letters")
	Village._bond(s,"elder",-8);Village._bond(s,"elder",100)
	check(s.village.people.elder.points==40 and letter_kind(s,"friendship")==5,"five-star cap and milestones never repeat after affection drops")
	var gifts_by_star: Dictionary={}
	for letter: Dictionary in s.village.mail:
		if letter.kind=="friendship": gifts_by_star[letter.title]=letter.gift.get("type","")
	check(gifts_by_star["我们已经有 3 星的交情了"]=="seeds" and gifts_by_star["我们已经有 4 星的交情了"]=="guard" and gifts_by_star["我们已经有 5 星的交情了"]=="evidence","three, four, five stars award seeds, protection, evidence")
	for mode: String in ["active","talk_only"]:
		s.new_game();s.gold=10000;s.inventory.egg=20
		var days: int=7 if mode=="active" else 20
		for date: int in range(days):
			Village.talk(s,0)
			if mode=="active": Village.gift(s,0,"egg")
			if date==days-2: check(s.village.people.elder.points<40,"not full affection one day too early: "+mode)
			if date<days-1: s.delivered=true;s.next_day()
		check(s.village.people.elder.points==40 and letter_kind(s,"friendship")==5,"full affection and five letters after %d days: %s"%[days,mode])
	s.new_game()
	for reward: String in ["seeds","evidence","guard"]:
		s.village.request.reward=reward;s.village.request.done=false
		var key: String=s.village.request.key;s.inventory[key]=2
		var before: Dictionary=s.to_data()
		check(Village.complete_request(s) and s.inventory[key]==0 and s.ap==10 and s.reputation==int(before.reputation)+1,"mutual help consumes materials and rewards reputation: "+reward)
		var thank: Dictionary=s.village.mail.back();id=thank.id
		check(s.village.people[s.village.request.npc].points==int(before.village.people[s.village.request.npc].points)+4,"mutual help adds exactly half star: "+reward)
		check(thank.kind=="thanks" and thank.gift.type==reward and not thank.claimed,"help reward arrives as unclaimed thank-you letter: "+reward)
		var before_claim: Dictionary=s.to_data()
		check(Village.collect_mail(s,id) and thank.claimed,"claim help attachment: "+reward)
		var claimed: Dictionary=s.to_data()
		check(not Village.collect_mail(s,id) and s.to_data()==claimed,"attachment cannot be duplicated: "+reward)
		check(s.undo() and s.to_data()==before_claim,"undo restores attachment and rewards: "+reward)
		check(s.undo() and s.to_data()==before,"undo restores entire completed request: "+reward)
	s.village.guards=1;s.day=3;s.gold=1000;s.delivered=true
	s.village.active=[];s.village.planned=[]
	var selected: RandomNumberGenerator=RandomNumberGenerator.new()
	for seed_value: int in range(100):
		selected.seed=seed_value
		if selected.randi_range(0,5)==2: s.rng.seed=seed_value;break
	s.next_day()
	check(s.village.guards==0 and s.plots[0].crop==0 and s.event.is_empty() and letter_kind(s,"protection")==1,"one guard blocks one company crop destruction and sends letter")
	s.new_game();s.village.active=[fixture(0)]
	check(not s.act("mine") and s.ap==10 and s.inventory.ore==0,"mine maintenance blocks action without AP cost")
	s.village.active=[fixture(2)]
	check(not s.act("fish") and s.ap==10 and s.inventory.fish==0,"pond cleaning blocks fishing without AP cost")
	s.village.active=[fixture(1)];s.act("mine")
	check(s.inventory.ore==4 and s.ap==7,"new mine vein adds two ore per action")
	s.village.active=[fixture(3)];s.act("fish")
	check(s.inventory.fish==4 and s.ap==4,"fish breeding adds two fish per action")
	for event_index: int in range(4,8):
		s.new_game();s.village.active=[fixture(event_index)];s.gold=1000;s.inventory["0"]=1
		var seed_cost: int=s.seed_price(0);var sale: int=s.selling_price("0")
		var gold: int=s.gold;s.buy_seed(0)
		check(s.gold==gold-seed_cost,"event seed price matches settlement: "+Village.EVENTS[event_index].id)
		gold=s.gold;s.sell("0")
		check(s.gold==gold+sale,"event crop price matches settlement: "+Village.EVENTS[event_index].id)
	s.new_game();s.day=2;Village.advance(s)
	var rumor_before: Dictionary=s.to_data()
	check(not Village.next_unknown(s).is_empty() and Village.buy_rumor(s) and s.gold==78,"shop sells a future rumor for twelve coins")
	var rumor_after: Dictionary=s.to_data()
	check(not Village.buy_rumor(s) and s.to_data()==rumor_after,"shop rumor limited to one purchase per day")
	check(s.undo() and s.to_data()==rumor_before,"rumor undo restores coins, availability and letter")
	var event: Dictionary=s.village.planned.back()
	check(Village.buy_rumor(s) and Village.preview(s).contains(event.name),"bought rumor enters visible forecast")
	check(Village.closed(s,"mine")==false,"planned closure has no effect before its start date")
	s.new_game();s.act("investigate",0)
	check(s.village.cards.has("water_report"),"investigation creates an identifiable evidence card")
	Village.add_card(s,"discharge_photo")
	var chain_before: Dictionary=s.to_data()
	check(Village.connect_chain(s,0) and s.evidence==3 and s.village.chains.has("pollution"),"related cards award one evidence on association")
	check(not Village.connect_chain(s,0),"evidence association cannot be repeated")
	check(s.undo() and s.to_data()==chain_before,"association undo restores score, chain and letter")
	s.village.people.elder.points=40;Village._bond(s,"elder",0)
	s.village.active=[fixture(4)]
	var expected: Dictionary=s.to_data()
	check(s.save_game("user://village-test.json"),"social state save writes successfully")
	var loaded: RefCounted=State.new();loaded.load_game("user://village-test.json")
	check(loaded.to_data()==expected,"social JSON round trip retains stars, milestone flags, event factors, mail and RNG")
	var ten_star: Dictionary=expected.duplicate(true)
	ten_star.village.erase("bond_version")
	ten_star.village.erase("talk_count")
	for person: Dictionary in ten_star.village.people.values():
		var legacy_milestones: Array=[]
		for milestone: int in person.milestones: legacy_milestones.append(milestone*2)
		person.milestones=legacy_milestones
	ten_star.village.people.lin.points=17
	ten_star.village.people.lin.talk_day=ten_star.day
	ten_star.village.people.lin.milestones=[2,4]
	ten_star.village.mail[1].body="请在第 4 天结束前送来 小麦 ×2。完成后会寄感谢信，可能附上种子、证据或一次农场保护。"
	ten_star.village.mail[1].read=true
	for letter: Dictionary in ten_star.village.mail:
		if letter.kind=="friendship":
			for stars: int in [5,4,3,2,1]:
				letter.title=letter.title.replace("我们已经有 %d 星的交情了"%stars,"我们已经有 %d 星的交情了"%(stars*2))
				letter.body=letter.body.replace("好感度：%d / 5 星。"%stars,"好感度：%d / 10 星。"%(stars*2))
			letter.claimed=true;letter.read=true
	check(s._valid_save(ten_star),"old ten-star social save remains accepted")
	var file: FileAccess=FileAccess.open("user://ten-star-test.json",FileAccess.WRITE)
	var old_snapshot: Dictionary=ten_star.duplicate(true)
	old_snapshot.village.people.elder.points=39;old_snapshot.village.people.elder.milestones=[2,4,6,8]
	ten_star["undo_history"]=[{"label":"旧版好感操作","state":old_snapshot}]
	file.store_string(JSON.stringify(ten_star));file.close()
	check(loaded.load_game("user://ten-star-test.json") and loaded.village.bond_version==2 and loaded.village.people.elder.milestones==[1,2,3,4,5],"JSON load migrates old thresholds into five-star milestones")
	check(loaded.village.people.lin.points==17 and loaded.village.people.lin.milestones==[1,2],"legacy fractional progress keeps exact completion percentage")
	check(loaded.village.talk_count==1 and Village.free_talks(loaded)==2,"legacy save reconstructs used talk quota from today's villagers")
	check(loaded.village.mail[1].body.contains("两份小麦") and not loaded.village.mail[1].body.contains("可能附上") and loaded.village.mail[1].read,"legacy request letter becomes natural without revealing rewards or resetting read state")
	var migration_safe: bool=true
	for letter: Dictionary in loaded.village.mail:
		if letter.kind=="friendship": migration_safe=migration_safe and letter.claimed and letter.read and not letter.body.contains("/ 10 星")
	check(migration_safe,"legacy letters update star text and retain claim/read status")
	var before_bond: int=loaded.village.mail.size()
	Village._bond(loaded,"elder",0)
	check(loaded.village.mail.size()==before_bond,"migration cannot reissue earned milestone gifts")
	check(loaded.undo() and loaded.village.people.elder.points==39 and loaded.village.people.elder.milestones==[1,2,3,4] and loaded.village.bond_version==2,"old undo history restores migrated affection correctly")
	var converted_state: Dictionary=loaded.to_data()
	loaded.save_game("user://five-star-test.json")
	loaded.load_game("user://five-star-test.json")
	check(loaded.to_data()==converted_state,"new social save is never migrated a second time")
	var unknown_version: Dictionary=expected.duplicate(true);unknown_version.village.bond_version=3
	check(not s._valid_save(unknown_version),"unsupported affection format rejected")
	var invalid_quota: Dictionary=expected.duplicate(true);invalid_quota.village.talk_count=-1
	check(not s._valid_save(invalid_quota),"negative conversation count rejected")
	var broken: Dictionary=expected.duplicate(true);broken.village.people.elder.points=41
	check(not s._valid_save(broken),"corrupt affection rejected")
	broken=expected.duplicate(true);broken.village.mail[0].gift={"type":"seeds","crop":99,"count":3}
	check(not s._valid_save(broken),"corrupt letter attachment rejected")
	var old: Dictionary=expected.duplicate(true);old.erase("village")
	check(s._valid_save(old),"legacy save without village data remains valid")
	loaded._restore(old)
	check(loaded.village.people.size()==4 and Village.unread(loaded)==3,"legacy save initializes new village systems")
	s.new_game();s.gold=10000
	var safe: bool=true;var consistent: bool=true;var durations: bool=true
	for day: int in range(1,25):
		var tomorrow: String=Village.forecast(s.day+1)
		s.delivered=true;s.next_day()
		consistent=consistent and s.weather==tomorrow
		safe=safe and s.village.active.size()+(0 if s.event.is_empty() else 1)<=2
		for e: Dictionary in s.village.active:
			durations=durations and e.start<=s.day and e.finish>=s.day and e.finish-e.start+1 in [1,2,3]
		for date: int in range(s.day,26):
			var count: int=0
			for e: Dictionary in s.village.active+s.village.planned:
				if e.start<=date and e.finish>=date: count+=1
			safe=safe and count<=2
	check(safe,"maximum two concurrent events including company interference across all twenty-five days")
	check(consistent,"two-day weather forecasts match actual transitions")
	check(durations,"events activate and expire on exact announced dates and last one to three days")
	print("[RESULT] %d village checks, %d failures"%[checks,failures]);quit(1 if failures>0 else 0)
