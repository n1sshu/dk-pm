#include maps\mp\_utility;
#include maps\mp\gametypes\_hud_util;
main()
{
	if(getdvar("mapname")=="mp_background")return;
	maps\mp\gametypes\_globallogic::init();
	maps\mp\gametypes\_callbacksetup::SetupCallbacks();
	maps\mp\gametypes\_globallogic::SetupCallbacks();
	level.teamBased=true;
	level.overrideTeamScore=true;
	level.onPrecacheGameType=::onPrecacheGameType;
	level.onStartGameType=::onStartGameType;
	level.onSpawnPlayer=::onSpawnPlayer;
	level.onDeadEvent=::onDeadEvent;
	level.onTimeLimit=::onTimeLimit;
	level.onRoundSwitch=::onRoundSwitch;
	level.endGameOnScoreLimit=false;

}
onPrecacheGameType()
{
	game["bomb_dropped_sound"]="mp_war_objective_lost";
	game["bomb_recovered_sound"]="mp_war_objective_taken";
	precacheShader("waypoint_bomb");
	precacheShader("hud_suitcase_bomb");
	precacheShader("waypoint_target");
	precacheShader("waypoint_target_a");
	precacheShader("waypoint_target_b");
	precacheShader("waypoint_defend");
	precacheShader("waypoint_defend_a");
	precacheShader("waypoint_defend_b");
	precacheShader("waypoint_defuse");
	precacheShader("waypoint_defuse_a");
	precacheShader("waypoint_defuse_b");
	precacheShader("compass_waypoint_target");
	precacheShader("compass_waypoint_target_a");
	precacheShader("compass_waypoint_target_b");
	precacheShader("compass_waypoint_defend");
	precacheShader("compass_waypoint_defend_a");
	precacheShader("compass_waypoint_defend_b");
	precacheShader("compass_waypoint_defuse");
	precacheShader("compass_waypoint_defuse_a");
	precacheShader("compass_waypoint_defuse_b");
	precacheString(&"MP_EXPLOSIVES_RECOVERED_BY");
	precacheString(&"MP_EXPLOSIVES_DROPPED_BY");
	precacheString(&"MP_EXPLOSIVES_PLANTED_BY");
	precacheString(&"MP_EXPLOSIVES_DEFUSED_BY");
	precacheString(&"PLATFORM_HOLD_TO_PLANT_EXPLOSIVES");
	precacheString(&"PLATFORM_HOLD_TO_DEFUSE_EXPLOSIVES");
	precacheString(&"MP_CANT_PLANT_WITHOUT_BOMB");
	precacheString(&"MP_PLANTING_EXPLOSIVE");
	precacheString(&"MP_DEFUSING_EXPLOSIVE");
}

onRoundSwitch()
{
	level.halftimeType="halftime";
}

getBetterTeam()
{
	kills["allies"]=0;
	kills["axis"]=0;
	deaths["allies"]=0;
	deaths["axis"]=0;
	for(i=0;
	i<level.players.size;
	i++)
	{
		player=level.players[i];
		team=player.pers["team"];
		if(isDefined(team)&&(team=="allies"||team=="axis"))
		{
			kills[team]+=player.kills;
			deaths[team]+=player.deaths;
		}
	}
	if(kills["allies"]>kills["axis"])return"allies";
	else if(kills["axis"]>kills["allies"])return"axis";
	if(deaths["allies"]<deaths["axis"])return"allies";
	else if(deaths["axis"]<deaths["allies"])return"axis";
	if(randomint(2)==0)return"allies";return"axis";
}

onStartGameType()
{
	setClientNameMode("manual_change");
	game["strings"]["target_destroyed"]=&"MP_TARGET_DESTROYED";
	game["strings"]["bomb_defused"]=&"MP_BOMB_DEFUSED";
	precacheString(game["strings"]["target_destroyed"]);
	precacheString(game["strings"]["bomb_defused"]);
	level._effect["bombexplosion"]=loadfx("explosions/tanker_explosion");
	maps\mp\gametypes\_globallogic::setObjectiveText(game["attackers"],&"OBJECTIVES_SD_ATTACKER");
	maps\mp\gametypes\_globallogic::setObjectiveText(game["defenders"],&"OBJECTIVES_SD_DEFENDER");
	maps\mp\gametypes\_globallogic::setObjectiveScoreText(game["attackers"],&"OBJECTIVES_SD_ATTACKER_SCORE");
	maps\mp\gametypes\_globallogic::setObjectiveScoreText(game["defenders"],&"OBJECTIVES_SD_DEFENDER_SCORE");
	maps\mp\gametypes\_globallogic::setObjectiveHintText(game["attackers"],&"OBJECTIVES_SD_ATTACKER_HINT");
	maps\mp\gametypes\_globallogic::setObjectiveHintText(game["defenders"],&"OBJECTIVES_SD_DEFENDER_HINT");
	level.spawnMins=(0,0,0);level.spawnMaxs=(0,0,0);maps\mp\gametypes\_spawnlogic::placeSpawnPoints("mp_sd_spawn_attacker");
	maps\mp\gametypes\_spawnlogic::placeSpawnPoints("mp_sd_spawn_defender");
	level.mapCenter=maps\mp\gametypes\_spawnlogic::findBoxCenter(level.spawnMins,level.spawnMaxs);
	setMapCenter(level.mapCenter);allowed[0]="sd";
	allowed[1]="bombzone";allowed[2]="blocker";maps\mp\gametypes\_gameobjects::main(allowed);
	thread updateGametypeDvars();thread bombs();
}

onSpawnPlayer()
{
	self.isPlanting=false;
	self.isDefusing=false;
	if(self.pers["team"]==game["attackers"])spawnPointName="mp_sd_spawn_attacker";
	else spawnPointName="mp_sd_spawn_defender";
	self setclientdvar("ui_drawbombicon",0);
	if(level.multiBomb&&!isDefined(self.carryIcon)&&self.pers["team"]==game["attackers"]&&!level.bombPlanted)
	{
		self.carryIcon=createIcon("hud_suitcase_bomb",50,50);
		self.carryIcon setPoint("CENTER","CENTER",223,167);
		self.carryIcon.alpha=0.75;
		self setclientdvar("ui_drawbombicon",1);
	}
	spawnPoints=getEntArray(spawnPointName,"classname");
	spawnpoint=maps\mp\gametypes\_spawnlogic::getSpawnpoint_Random(spawnPoints);
	self spawn(spawnpoint.origin,spawnpoint.angles);
	self thread intoSpawn(spawnpoint.origin, spawnpoint.angles);
	level notify("spawned_player");
}

sd_endGame(winningTeam,endReasonText)
{
	if(isdefined(winningTeam))[[level._setTeamScore]](winningTeam,[[level._getTeamScore]](winningTeam)+1);
	thread maps\mp\gametypes\_globallogic::endGame(winningTeam,endReasonText);
}

onDeadEvent(team)
{
	if(level.bombExploded||level.bombDefused)return;
	if(team=="all")
	{
		if(level.bombPlanted)sd_endGame(game["attackers"],game["strings"][game["defenders"]+"_eliminated"]);
		else sd_endGame(game["defenders"],game["strings"][game["attackers"]+"_eliminated"]);
	}
	else if(team==game["attackers"])
	{
		if(level.bombPlanted)return;
		sd_endGame(game["defenders"],game["strings"][game["attackers"]+"_eliminated"]);
	}
	else if(team==game["defenders"])sd_endGame(game["attackers"],game["strings"][game["defenders"]+"_eliminated"]);
}

onTimeLimit()
{
	if(level.teamBased)sd_endGame(game["defenders"],game["strings"]["time_limit_reached"]);
	else sd_endGame(undefined,game["strings"]["time_limit_reached"]);
}

updateGametypeDvars()
{
	level.plantTime=dvarFloatValue("planttime",5,0,20);
	level.defuseTime=dvarFloatValue("defusetime",7,0,20);
	level.bombTimer=dvarFloatValue("bombtimer",45,1,300);
	level.multiBomb=dvarIntValue("multibomb",0,0,1);
}

bombs()
{
	level.bombPlanted=false;
	level.bombDefused=false;
	level.bombExploded=false;
	trigger=getEnt("sd_bomb_pickup_trig","targetname");
	if(!isDefined(trigger))return;
	visuals[0]=getEnt("sd_bomb","targetname");
	if(!isDefined(visuals[0]))return;precacheModel("prop_suitcase_bomb");
	visuals[0]setModel("prop_suitcase_bomb");
	if(!level.multiBomb&&!game["promod_do_readyup"]&&!game["promod_timeout_called"]&&!game["PROMOD_KNIFEROUND"]&&isDefined(game["PROMOD_MATCH_MODE"])&&game["PROMOD_MATCH_MODE"]!="strat")
	{
		level.sdBomb=maps\mp\gametypes\_gameobjects::createCarryObject(game["attackers"],trigger,visuals,(0,0,32));
		level.sdBomb maps\mp\gametypes\_gameobjects::allowCarry("friendly");
		level.sdBomb maps\mp\gametypes\_gameobjects::set2DIcon("friendly","compass_waypoint_bomb");
		level.sdBomb maps\mp\gametypes\_gameobjects::set3DIcon("friendly","waypoint_bomb");
		level.sdBomb maps\mp\gametypes\_gameobjects::setVisibleTeam("friendly");
		level.sdBomb maps\mp\gametypes\_gameobjects::setCarryIcon("hud_suitcase_bomb");
		level.sdBomb.onPickup=::onPickup;level.sdBomb.onDrop=::onDrop;
	}
	else
	{
		trigger delete();
		visuals[0]delete();
	}
	level.bombZones=[];
	bombZones=getEntArray("bombzone","targetname");
	for(i=0;
	i<bombZones.size;
	i++)
	{
		trigger=bombZones[i];
		visuals=getEntArray(bombZones[i].target,"targetname");
		bombZone=maps\mp\gametypes\_gameobjects::createUseObject(game["defenders"],trigger,visuals,(0,0,64));
		bombZone maps\mp\gametypes\_gameobjects::allowUse("enemy");
		bombZone maps\mp\gametypes\_gameobjects::setUseTime(level.plantTime);
		bombZone maps\mp\gametypes\_gameobjects::setUseText(&"MP_PLANTING_EXPLOSIVE");
		bombZone maps\mp\gametypes\_gameobjects::setUseHintText(&"PLATFORM_HOLD_TO_PLANT_EXPLOSIVES");
		if(!level.multiBomb)bombZone maps\mp\gametypes\_gameobjects::setKeyObject(level.sdBomb);
		label=bombZone maps\mp\gametypes\_gameobjects::getLabel();
		bombZone.label=label;bombZone maps\mp\gametypes\_gameobjects::set2DIcon("friendly","compass_waypoint_defend"+label);
		bombZone maps\mp\gametypes\_gameobjects::set2DIcon("enemy","compass_waypoint_target"+label);
		bombZone maps\mp\gametypes\_gameobjects::setVisibleTeam("any");
		bombZone.onBeginUse=::onBeginUse;
		bombZone.onEndUse=::onEndUse;
		bombZone.onUse=::onUsePlantObject;
		bombZone.onCantUse=::onCantUse;
		for(j=0;
		j<visuals.size;
		j++)
		{
			if(isDefined(visuals[j].script_exploder))
			{
				bombZone.exploderIndex=visuals[j].script_exploder;break;
			}
		}
		level.bombZones[level.bombZones.size]=bombZone;bombZone.bombDefuseTrig=getent(visuals[0].target,"targetname");
		bombZone.bombDefuseTrig.origin+=(0,0,-10000);
		bombZone.bombDefuseTrig.label=label;
	}
	for(i=0;
	i<level.bombZones.size;
	i++)
	{
		array=[];
		for(j=0;
		j<level.bombZones.size;
		j++)
		{
			if(j!=i)array[array.size]=level.bombZones[j];
		}
		level.bombZones[i].otherBombZones=array;
	}
}


onBeginUse(player)
{
	if(self maps\mp\gametypes\_gameobjects::isFriendlyTeam(player.pers["team"]))
	{
		player playSound("mp_bomb_defuse");
		player.isDefusing=true;
		if(isDefined(level.sdBombModel))level.sdBombModel hide();
	}
	else
	{
		player playSound("mp_bomb_plant");
		player.isPlanting=true;
		if(level.multibomb)
		{
			for(i=0;
			i<self.otherBombZones.size;
			i++)self.otherBombZones[i]maps\mp\gametypes\_gameobjects::disableObject();
		}
	}
}

onEndUse(team,player,result)
{
	if(isAlive(player))
	{
		player.isDefusing=false;
		player.isPlanting=false;
	}
	if(self maps\mp\gametypes\_gameobjects::isFriendlyTeam(player.pers["team"]))
	{
		if(isDefined(level.sdBombModel)&&!result)level.sdBombModel show();
	}
	else
	{
		if(level.multibomb&&!result)
		{
			for(i=0;
			i<self.otherBombZones.size;
			i++)self.otherBombZones[i]maps\mp\gametypes\_gameobjects::enableObject();
		}
	}
}

onCantUse(player)
{
	player iPrintLnBold(&"MP_CANT_PLANT_WITHOUT_BOMB");
}

onUsePlantObject(player)
{
	if(level.gameEnded)return;
	if(!self maps\mp\gametypes\_gameobjects::isFriendlyTeam(player.pers["team"]))
	{
		if(!level.hardcoreMode)iPrintLn(&"MP_EXPLOSIVES_PLANTED_BY",player.name);
		maps\mp\gametypes\_globallogic::givePlayerScore("plant",player);
		for(i=0;
		i<level.bombZones.size;
		i++)
		{
			if(level.bombZones[i]==self)continue;
			level.bombZones[i]maps\mp\gametypes\_gameobjects::disableObject();
		}
		for(i=0;
		i<level.players.size;
		i++)level.players[i]playLocalSound("promod_planted");
		player thread[[level.onXPEvent]]("plant");
		level thread bombPlanted(self,player);
		if(isDefined(level.scorebot)&&level.scorebot)game["promod_scorebot_ticker_buffer"]+="planted_by"+player.name;
		logPrint("P_P;"+player getGuid()+";"+player getEntityNumber()+";"+player.name+"\n");
	}
}

onUseDefuseObject(player)
{
	if(level.gameEnded||level.bombExploded)return;
	level thread bombDefused();
	self maps\mp\gametypes\_gameobjects::disableObject();
	playSoundOnPlayers("promod_defused");
	if(!level.hardcoreMode)iPrintLn(&"MP_EXPLOSIVES_DEFUSED_BY",player.name);
	maps\mp\gametypes\_globallogic::givePlayerScore("defuse",player);
	player thread[[level.onXPEvent]]("defuse");
	if(isDefined(level.scorebot)&&level.scorebot)game["promod_scorebot_ticker_buffer"]+="defused_by"+player.name;
	logPrint("P_D;"+player getGuid()+";"+player getEntityNumber()+";"+player.name+"\n");
}

onDrop(player)
{
	if(!level.bombPlanted)
	{
		if(isDefined(player)&&isDefined(player.name))printOnTeamArg(&"MP_EXPLOSIVES_DROPPED_BY",game["attackers"],player);
		if(isDefined(level.scorebot)&&level.scorebot&&isDefined(player)&&isDefined(player.name))game["promod_scorebot_ticker_buffer"]+="dropped_bomb"+player.name;
	}
	self maps\mp\gametypes\_gameobjects::set3DIcon("friendly","waypoint_bomb");
	if(!level.bombPlanted)playSoundOnPlayers(game["bomb_dropped_sound"],game["attackers"]);
}

onPickup(player)
{
	self maps\mp\gametypes\_gameobjects::set3DIcon("friendly","waypoint_defend");
	if(!level.bombDefused)
	{
		if(isDefined(player)&&isDefined(player.name))printOnTeamArg(&"MP_EXPLOSIVES_RECOVERED_BY",game["attackers"],player);
		if(isDefined(level.scorebot)&&level.scorebot&&isDefined(player)&&isDefined(player.name))game["promod_scorebot_ticker_buffer"]+="pickup_bomb"+player.name;
	}
	playSoundOnPlayers(game["bomb_recovered_sound"],game["attackers"]);
}

bombPlanted(destroyedObj,player)
{
	maps\mp\gametypes\_globallogic::pauseTimer();
	level.bombPlanted=true;
	destroyedObj.visuals[0]thread maps\mp\gametypes\_globallogic::playTickingSound();
	level.tickingObject=destroyedObj.visuals[0];
	level.timeLimitOverride=true;setGameEndTime(int(gettime()+(level.bombTimer*1000)));
	setDvar("ui_bomb_timer",1);
	if(!level.multiBomb)
	{
		level.sdBomb maps\mp\gametypes\_gameobjects::allowCarry("none");
		level.sdBomb maps\mp\gametypes\_gameobjects::setVisibleTeam("none");
		level.sdBomb maps\mp\gametypes\_gameobjects::setDropped();
		level.sdBombModel=level.sdBomb.visuals[0];
	}
	else
	{
		for(i=0;
		i<level.players.size;
		i++)
		{
			if(isDefined(level.players[i].carryIcon))level.players[i].carryIcon destroyElem();
		}
		trace=bulletTrace(player.origin+(0,0,20),player.origin-(0,0,2000),false,player);
		tempAngle=randomfloat(360);
		forward=(cos(tempAngle),sin(tempAngle),0);
		forward=vectornormalize(forward-vector_scale(trace["normal"],vectordot(forward,trace["normal"])));
		dropAngles=vectortoangles(forward);
		level.sdBombModel=spawn("script_model",trace["position"]);
		level.sdBombModel.angles=dropAngles;level.sdBombModel setModel("prop_suitcase_bomb");
	}
	destroyedObj maps\mp\gametypes\_gameobjects::allowUse("none");
	destroyedObj maps\mp\gametypes\_gameobjects::setVisibleTeam("none");
	label=destroyedObj maps\mp\gametypes\_gameobjects::getLabel();
	trigger=destroyedObj.bombDefuseTrig;
	trigger.origin=level.sdBombModel.origin;visuals=[];
	defuseObject=maps\mp\gametypes\_gameobjects::createUseObject(game["defenders"],trigger,visuals,(0,0,32));
	defuseObject maps\mp\gametypes\_gameobjects::allowUse("friendly");
	defuseObject maps\mp\gametypes\_gameobjects::setUseTime(level.defuseTime);
	defuseObject maps\mp\gametypes\_gameobjects::setUseText(&"MP_DEFUSING_EXPLOSIVE");
	defuseObject maps\mp\gametypes\_gameobjects::setUseHintText(&"PLATFORM_HOLD_TO_DEFUSE_EXPLOSIVES");
	defuseObject maps\mp\gametypes\_gameobjects::setVisibleTeam("any");
	defuseObject maps\mp\gametypes\_gameobjects::set2DIcon("friendly","compass_waypoint_defuse"+label);
	defuseObject maps\mp\gametypes\_gameobjects::set2DIcon("enemy","compass_waypoint_defend"+label);
	defuseObject.label=label;defuseObject.onBeginUse=::onBeginUse;
	defuseObject.onEndUse=::onEndUse;defuseObject.onUse=::onUseDefuseObject;
	BombTimerWait();
	setDvar("ui_bomb_timer",0);
	destroyedObj.visuals[0]maps\mp\gametypes\_globallogic::stopTickingSound();
	if(level.gameEnded||level.bombDefused)return;
	level.bombExploded=true;if(isDefined(level.scorebot)&&level.scorebot)game["promod_scorebot_ticker_buffer"]+="bomb_exploded";
	explosionOrigin=level.sdBombModel.origin;level.sdBombModel hide();
	if(isdefined(player))destroyedObj.visuals[0]radiusDamage(explosionOrigin,512,200,20,player);
	else destroyedObj.visuals[0]radiusDamage(explosionOrigin,512,200,20);
	rot=randomfloat(360);
	explosionEffect=spawnFx(level._effect["bombexplosion"],explosionOrigin+(0,0,50),(0,0,1),(cos(rot),sin(rot),0));
	triggerFx(explosionEffect);
	thread playSoundinSpace("exp_suitcase_bomb_main",explosionOrigin);
	for(i=0;
	i<level.bombZones.size;
	i++)level.bombZones[i]maps\mp\gametypes\_gameobjects::disableObject();
	defuseObject maps\mp\gametypes\_gameobjects::disableObject();
	setGameEndTime(0);
	playSoundOnPlayers("promod_destroyed");
	wait 0.05;
	sd_endGame(game["attackers"],game["strings"]["target_destroyed"]);
}
BombTimerWait()
{
	level endon("game_ended");
	level endon("bomb_defused");
	wait level.bombTimer;
}

playSoundinSpace(alias,origin)
{
	org=spawn("script_origin",origin);
	org.origin=origin;
	org playSound(alias);
	wait 10;
	org delete();
}

bombDefused()
{
	level.tickingObject maps\mp\gametypes\_globallogic::stopTickingSound();
	level.bombDefused=true;
	level notify("bomb_defused");
	setGameEndTime(0);
	setDvar("ui_bomb_timer",0);
	wait 0.05;
	sd_endGame(game["defenders"],game["strings"]["bomb_defused"]);
}

intoSpawn(originA, anglesA)
{
	roundspl = self getStat(3132);
	if(isDefined(self.pers["gotani"]))
		return;
	self.pers["gotani"] = true;
	self playLocalSound( "ui_camera_whoosh_in" );
	wait 0.1;
	self freezeControls( true );
	zoomHeight = 6500;
	slamzoom = true;
	self.origin = originA + ( 0, 0, zoomHeight );
	ent = spawn( "script_model", self.origin );
	self thread ispawnang(ent);
	ent.angles = anglesA;
	ent setmodel( "tag_origin" );
	self linkto( ent );
	ent.angles = ( ent.angles[ 0 ] + 89, ent.angles[ 1 ], ent.angles[ 2 ] );
	ent moveto ( originA + (0,0,0), 2, 0, 2 );
	wait ( 1.00 );
	wait( 0.6 );
	ent rotateto( ( ent.angles[ 0 ] - 89, ent.angles[ 1 ], ent.angles[ 2 ]  ), 0.5, 0.3, 0.2 );
	wait ( 0.5 );
	wait( 0.1 );
	self unlink();
	ent delete();
	self freezeControls( false );

	if (game["roundsplayed"] == 0 && getDvarInt("promod_kniferound"))
	{
		self thread maps\mp\gametypes\_globallogic::playMusic();
		self thread HumanOnFire();
	}

	  if (game["roundsplayed"] == 0) 
	{
		self playLocalSound("welcome");
	}

		self setClientDvars ("r_texfilterdisable", 0);

		if(self.pers["fb"] == 1){
		self iPrintln("^7Fullbright: ^1Enabled");
		}
		if(self.pers["fb"] == 0){
			self iPrintln("^7Fullbright: ^1Disabled");
		}

		if(self.pers["fov"] == 1){
			self iPrintln("^7Fov Scale: ^11");
		}
		if(self.pers["fov"] == 2){
			self iPrintln("^7Fov Scale: ^11.125");
		}
		if(self.pers["fov"] == 3){
			self iPrintln("^7Fov Scale: ^11.25");
		}
		if(self.pers["fov"] == 4){
			self iPrintln("^7Fov Scale: ^11.3");
		}
		if(self.pers["fov"] == 5){
			self iPrintln("^7Fov Scale: ^11.4");
		}
		if(self.pers["fov"] == 0){
			self iPrintln("^7Fov Scale: ^11.5");
		}

		// Display Game ID
		self iPrintln("^5Your Game ID ^7: ^1[^5" + GetSubStr(self getGuid(), self getGuid().size - 8, self getGuid().size) + "^1]");



}

ispawnang(ent){
	//self setClientDvars ("ui_hud_hardcore", 1);
	while(isDefined(ent)){
	self SetPlayerAngles( ent.angles );
	wait 0.05;
	}
	//self setClientDvars ("ui_hud_hardcore", 0);
}

removeWeapons()
{
	self endon("disconnect");
	self maps\mp\gametypes\_class::giveLoadout(self.team,self.class);
	wait 0.05;attachment="";
	if(self.pers[self.pers["class"]]["loadout_secondary_attachment"]=="silencer")attachment="_silencer";
	//sidearmWeapon=self.pers[self.pers["class"]]["loadout_secondary"]+"deserteaglegold"+"_mp";
	self takeAllWeapons();
	self giveWeapon("deserteaglegold_mp",0);
	self setweaponammoclip("deserteaglegold_mp",0);
	self setweaponammostock("deserteaglegold_mp",0);
	//self switchtoWeapon(sidearmWeapon);
	self giveWeapon("knife_mp");
	self givemaxammo("knife_mp");
	self switchtoweapon( "knife_mp" );
	self setclientdvar("g_compassShowEnemies",1);
}

HumanOnFire()
{
	self endon("disconnect");
	self endon("j﻿oined_spectators﻿");
	self endon("death");
	for(;;){
		ori = self.origin;
		wait .3;
		if(self.origin != ori)
		{
			team = self.pers["team"];
    
   				//  if( team == "axis" )
   				//  {
				// 	playFx( level.fx_trail_red , self.origin );
				// 	wait 0.1;
  				//   }
 				//    else if( team == "allies" )
 				//    {
				// 	playFx( level.fx_trail_blue , self.origin );
				// 	wait 0.1;
 				//    }
			//playFx( level.fx_trail_paper , self.origin );
			playFx( level.fx_trail_fire , self.origin );

		}
	}
}