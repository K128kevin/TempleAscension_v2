extends Node
const Data = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var checks: Array = []
var failures: Array = []
var game
func check(ok: bool, message: String):
	if ok: checks.append(message)
	else: failures.append(message); push_error(message)
func start(owner_game):
	game = owner_game
	game.set_process(false)
	check(game.run.floor==0 and game.player.position==Vector3(0,0,9),"New character starts at temple entrance")
	check(game.player.visual.clips.size()==38,"All locomotion, weapon and hit reaction clips are present")
	check(game.run.class_id=="warrior" and game.run.skills.cleave==1,"Warrior starts with Cleave and sword")
	game.player.hp=20; game.run.energy=60; game.heal()
	check(game.player.hp==80 and game.run.energy==0 and game.heal_cd==20 and not game.run.has("flasks"),"Healing spell instantly restores 60 percent for 60 energy with a 20-second cooldown and no charges")
	game.heal()
	check(game.run.energy==0,"Healing spell cooldown prevents another cast")
	game.run.energy=10; game.dash()
	check(game.run.energy==0 and game.dash_time>0 and game.player.invulnerable>0,"Dash spends ten energy and has no cooldown")
	game.player.busy=0; game.player.invulnerable=0; game.dash_time=0
	game.player.hp=game.player.max_hp; game.hurt_player(5)
	check(game.player.visual.state in ["ShieldHit","ShieldHitHead"] and game.player.visual.reaction_time>0,"Light damage plays a hit flinch, shield held steady")
	game.player.visual.locomotion(true,false)
	check(game.player.visual.state in ["ShieldHit","ShieldHitHead"],"Locomotion waits for the flinch to finish")
	game.player.visual.advance(.4); game.player.visual.locomotion(true,false)
	check(game.player.visual.state in ["Run","SwordRun"],"Locomotion resumes after the flinch")
	game.player.hp=game.player.max_hp; game.hurt_player(game.player.max_hp*.5)
	check(game.player.visual.state=="ShieldHitStagger","Heavy damage staggers the hero")
	game.player.visual.play("Idle"); game.player.busy=1.0; game.hurt_player(5)
	check(game.player.visual.state=="Idle","Hit reactions never interrupt attacks")
	game.player.busy=0; game.player.hp=game.player.max_hp
	game.run.energy=10; game.dash()
	var hp: float = game.player.hp
	game.hurt_player(100)
	check(game.player.hp==hp,"Evade prevents damage")
	game.player.invulnerable=0; game.dash_time=0
	game.hurt_player(10000)
	check(game.mode=="dead","Lethal damage opens retry")
	game.retry_floor()
	check(game.run.deaths==1 and game.run.class_id=="warrior","Retry preserves the character")
	game.pause_game(); check(game.mode=="paused","Pause stops campaign processing")
	game.resume_game(); check(game.mode=="playing","Resume restores gameplay")
	var total = 0
	for floor_index in 5:
		var expected=0
		for count in Data.COUNTS[floor_index].values(): expected+=count
		check(game.enemies.size()==expected,"Floor %d roster preserved" % (floor_index+1))
		check(game.world.path(game.world.spawn,game.world.exit_point).size()>0,"Floor %d stairs reachable" % (floor_index+1))
		for enemy in game.enemies:
			check(not game.world.path(game.world.spawn,enemy.position).is_empty(),"Enemy is reachable: "+enemy.uid)
			for offset in [Vector3(0,0,1.3),Vector3(1.3,0,0),Vector3(-1.3,0,0),Vector3(0,0,-1.3)]:
				if game.world.fits(enemy.position+offset): game.player.position=enemy.position+offset; break
			game.run.weapon=1
			for swing in 30:
				if enemy.dead: break
				game.player.tick(1.2) # Finish the previous swing and its recovery.
				game.attack(false,enemy.position)
				game.tick_scheduled(1.2)
			check(enemy.dead,"Defeat through weapon combat: "+enemy.uid)
			total+=1
		check(game.remaining()==0 and game.world.exit_seal.visible,"Combat opens stairs on floor %d" % (floor_index+1))
		for pickup in game.pickups.duplicate():
			game.player.position=pickup.node.position; game.player.position.y=0
			game.tick_pickups(.016)
		check(game.pickups.is_empty() and game.run.gems.is_empty(),"Weapon loot can be collected; no permanent gems")
		check(not game.run.owned[2] and not game.run.owned[3],"Bow and axe do not drop")
		if floor_index==2: check(game.run.owned[4],"Staff drop remains available")
		var points: int = game.run.points
		var xp: int = game.run.xp
		game.player.position=game.world.exit_point
		game.interact()
		check(game.run.floor==floor_index+1 and game.mode=="playing","Stairs advance immediately without allocation gate")
		check(game.run.points==points and game.run.xp==xp,"Stairs grant neither XP nor attribute points")
		await get_tree().process_frame
	check(total==247 and game.run.level>=18,"All temple enemies grant enough XP to unlock level 18 skills")
	check(game.enemies.size()==21 and game.boss.max_hp==1125,"Summit and offerings remain intact")
	game.player.position=game.boss.position+Vector3(0,0,4)
	game.boss.awake=true
	for wave in 4:
		game.boss.hp=game.boss.max_hp*(.79-wave*.2)
		game.boss.tick(.016)
		var awake=0
		for enemy in game.enemies:
			if enemy.kind=="offering" and not enemy.dormant_offering: awake+=1
		check(awake==(wave+1)*5,"Boss threshold wakes offering wave")
	var offering=game.enemies[1]
	offering.position=game.boss.position
	var boss_hp: float=game.boss.hp
	var xp: int=game.run.xp
	offering.tick(.016)
	check(game.boss.hp>boss_hp and offering.dead and game.run.xp==xp,"Absorbed offering heals boss and grants no kill XP")
	game.boss.laser_cooldown=0; game.boss.windup=0; game.boss.tick(.016)
	check(game.boss.windup>0,"Boss laser telegraphs")
	game.boss.tick(1.1)
	check(game.boss.laser_time==5,"Boss gaze lasts five seconds")
	game.boss.hit(10000)
	check(game.crown_available and game.run.xp>xp,"Boss death grants XP and releases crown")
	game.player.position=game.crown_position
	game.interact()
	check(game.mode=="ending" and game.run.completed,"Crown opens ending")
	game.summary_menu(); game.save_run()
	check(Save.valid(game.run),"Complete character obeys point and skill budgets")
	var restored=Save.load_run()
	check(not restored.is_empty() and restored.completed and restored.level==game.run.level,"Completed character saves and reloads")
	Save.write(game.run)
	var file=FileAccess.open(Save.directory.path_join("run.json"),FileAccess.WRITE)
	file.store_string("broken json"); file.close()
	check(not Save.load_run().is_empty(),"Backup recovers corrupted character save")
	FileAccess.open("res://test-results/campaign.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":checks.size(),"failed":failures,"checks":checks,"regular_enemies_fought":total},"  "))
	print("CAMPAIGN_TEST: ",checks.size()," passed; ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
