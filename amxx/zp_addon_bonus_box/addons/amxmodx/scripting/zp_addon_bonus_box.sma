/*
Name: [ZP] Addon: Bonus Box
Author: PomanoB & Accelerator
Version 1.2

Based on [ZP] DM Item's by PomanoB

vesion 1.2:
* Added extra items
* Sprite
* Message to all found box
* Fixed get gravity user (unfrozen)
* Lighting on the box
* Spin box
* Fixed code

Version 1.1b:
* Fixed language messages
* Added cvar - Chance drop box
* Using module Hamsanwich for give ammo weapons

Version 1.1a:
* Fixed bug: Very much box - server crash. Max boxes count 20
* Fixed aura mode R, G, B, W, use function fm_set_rendering

Version 1.1:
* Box on the ground
* Fixed code
* Add new bonus: Nemesis, Survivor, Speed(only zombie), Invisible(only zombie), Frost, God Mode
* Fixed conditions
* Admin menu
* Cvars
* Random Aura
*/

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#include <zombieplague>
#include <hamsandwich>

#define PLUGIN "[ZP] Addon: Bonus Box"
#define VERSION "1.2"
#define AUTHOR "PomanoB & Accelerator"

#define OFFSET_FLASH_AMMO 387
#define OFFSET_HE_AMMO 388
#define OFFSET_SMOKE_AMMO 389

//Uncomment, if you want to use the model from Half-Life
//#define DEFAULT_MODEL

//Max spawn box
#define MAXBOX 15

new g_Menu, gScreenfade, gGlass, gSprBoom, gSprBox, g_maxplayers
new cvar_Health_add_Z, cvar_Health_add_H, cvar_Health_del_Z, cvar_Health_del_H, cvar_Ammopacks_add, cvar_Ammopacks_del, cvar_Gravity, cvar_Speed_Z, cvar_Speed_H, cvar_Armor_add, cvar_Armor_del, cvar_FLASH, cvar_HE, cvar_SMOKE, cvar_Invisible_time, cvar_FrostTime, cvar_Godmode_time, cvar_Aura, cvar_Spawn, cvar_Light, cvar_Light_radius, cvar_Spin, cvar_SpeedSpin, cvar_MsgToAll, cvar_Sprite
new bool:gIsFrosted[33], bool:Gravity[33], bool:Speed[33], bool:Bright[33]
new CountBox = 0
new r = 255, g = 255, b = 255
new ExtraHumans[128][64], ExtraZombies[128][64]
new ExtrahCount = 0, ExtrazCount = 0

new const item_class_name[] = "bx"

new const gItems[18][] = {"First Aid", "Boom", "+AmmoPacks", "-AmmoPacks", "Invisible", "Frost", "Low Gravity", "Speed", "God Mode", "Light", "Night Vision", "ARMOR", "Grenades Pack", "SG550", "G3SG1", "M249", "AWP", "Extra Item"}

new const gSoundFrosted[] = "warcraft3/impalehit.wav"
new const gSoundBreak[] = "warcraft3/impalelaunch1.wav"
new const gModelGlass[] = "models/glassgibs.mdl"
new const gSprideBoom[] = "sprites/zerogxplode.spr"
new const gSpriteBox[] = "sprites/bonusbox.spr"

#if !defined DEFAULT_MODEL
new g_models[][] = {"models/zombie_plague/presents.mdl"}
#else
new g_models[][] = {"models/w_weaponbox.mdl"}
#endif

public plugin_precache()
{
	for (new i = 0; i < sizeof g_models; i++)
		precache_model(g_models[i])	
		
	precache_sound(gSoundFrosted)
	precache_sound(gSoundBreak)
	gGlass = precache_model(gModelGlass)
	gSprBoom = precache_model(gSprideBoom)
	gSprBox = precache_model(gSpriteBox)
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_Touch, "fwd_Touch")
	register_forward(FM_PlayerPreThink,"fwd_PlayerPreThink")
	register_forward(FM_Think,"fwd_Think")
	
	register_event("HLTV", "round_start", "a", "1=0", "2=0")
	register_event("DeathMsg","event_DeathMsg","a")
	register_event("ResetHUD", "event_ResetHud", "be")
	
	register_clcmd("bonusbox_menu", "display_items_menu", ADMIN_RCON, " - Bonus Box Menu")
	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	cvar_Health_add_Z = register_cvar("bx_health_add_zombie", "500")
	cvar_Health_add_H = register_cvar("bx_health_add_human", "50")
	cvar_Health_del_Z = register_cvar("bx_health_del_zombie", "250")
	cvar_Health_del_H = register_cvar("bx_health_del_human", "25")
	cvar_Ammopacks_add = register_cvar("bx_ammopacks_add", "5")
	cvar_Ammopacks_del = register_cvar("bx_ammopacks_del", "5")
	cvar_Gravity = register_cvar("bx_gravity", "0.5")
	cvar_Speed_Z = register_cvar("bx_speed_zombie", "250.0")
	cvar_Speed_H = register_cvar("bx_speed_human", "170.0")
	cvar_Armor_add = register_cvar("bx_armor_add", "100")
	cvar_Armor_del = register_cvar("bx_armor_del", "100")
	cvar_FLASH = register_cvar("bx_flash", "3")
	cvar_HE = register_cvar("bx_he", "3")
	cvar_SMOKE = register_cvar("bx_smoke", "3")
	cvar_Invisible_time = register_cvar("bx_invisible_time", "10.0")
	cvar_FrostTime = register_cvar("bx_frost_time", "5.0")
	cvar_Godmode_time = register_cvar("bx_godmode_time", "5.0")
	cvar_Aura = register_cvar("bx_aura", "1")
	cvar_Spawn = register_cvar("bx_spawn", "5")
	cvar_Light = register_cvar("bx_light", "1")
	cvar_Light_radius = register_cvar("bx_light_radius", "8")
	cvar_Spin = register_cvar("bx_spin", "0")
	cvar_SpeedSpin = register_cvar("bx_spin_speed", "10.0")
	cvar_MsgToAll = register_cvar("bx_msgtoall", "0")
	cvar_Sprite = register_cvar("bx_spritebox", "0")
	
	register_cvar("bonus_box", VERSION, FCVAR_SERVER | FCVAR_SPONLY)
	
	register_dictionary("bonus_box.txt")
	
	gScreenfade = get_user_msgid("ScreenFade")
	
	g_maxplayers = get_maxplayers()
	
	g_Menu = menu_create("Bonus Box Menu:","menu_item")
	
	menu_additem(g_Menu, "Create", "1")
	menu_additem(g_Menu, "Delete", "2")
	menu_additem(g_Menu, "Delete all", "3")
	menu_additem(g_Menu, "All on the ground", "4")
	
	set_task(1.0, "extra_humans")
	set_task(1.1, "extra_zombies")
}

public plugin_cfg()
{
	new file[64]; get_localinfo("amxx_configsdir",file,63);
	format(file, 63, "%s/zp_addon_bonusbox.cfg", file);
	if(file_exists(file)) server_cmd("exec %s", file), server_exec();
}

public extra_humans()
{
	new configsdir[200], ExtrashFile[200], Result
	new fSize, temp
	
	get_configsdir(configsdir,199)
	format(ExtrashFile,199,"%s/zp_bx_extra_humans.ini",configsdir)
	
	if(!file_exists(ExtrashFile)) 
	{
		server_print("Bonus Box Error: Coudn't find %s", ExtrashFile)
		return PLUGIN_HANDLED
	}
	
	fSize = file_size(ExtrashFile,1);
	
	if(!fSize)
		ExtrahCount = 0
		
	for(new i=0; i < fSize; i++)
	{
		Result = read_file(ExtrashFile, i, ExtraHumans[i], 63, temp) 
		
		if(!Result)
			continue
			
		ExtrahCount++
	}
	server_print("Bonus Box: %d Extras for Humans loaded", ExtrahCount)
	
	return PLUGIN_CONTINUE
}

public extra_zombies()
{
	new configsdir[200], ExtraszFile[200], Result
	new fSize, temp
	
	get_configsdir(configsdir,199)
	format(ExtraszFile,199,"%s/zp_bx_extra_zombies.ini",configsdir)
	
	if(!file_exists(ExtraszFile)) 
	{
		server_print("Bonus Box Error: Coudn't find %s", ExtraszFile)
		return PLUGIN_HANDLED
	}
	
	fSize = file_size(ExtraszFile,1);
	
	if(!fSize)
		ExtrazCount = 0
		
	for(new i=0; i < fSize; i++)
	{
		Result = read_file(ExtraszFile, i, ExtraZombies[i], 63, temp) 
		
		if(!Result)
			continue
			
		ExtrazCount++
	}
	server_print("Bonus Box: %d Extras for Zombies loaded", ExtrazCount)
	
	return PLUGIN_CONTINUE
}

public client_connect(id)
{
	gIsFrosted[id] = false
	Gravity[id] = false
	Speed[id] = false
	Bright[id] = false
}

public client_disconnect(id)
{
	if (task_exists(id))
		remove_task(id)
}

public display_items_menu(id, level, cid)
{
	if (cmd_access(id, level, cid, 0))
		menu_display(id, g_Menu, 0)
		
	return PLUGIN_HANDLED
}

public menu_item(id, menu, item)
{
	if( item < 0 ) 
		return PLUGIN_CONTINUE
 
	new cmd[3]
	new maccess, callback
 
	menu_item_getinfo(menu, item, maccess, cmd,2,_,_, callback)
	new iChoice = str_to_num(cmd)
	
	switch(iChoice)
	{
		case 1:
		{
			new origin[3]
			
			if (!is_user_alive(id))
			{
				get_user_origin(id, origin, 0)
				
				addItem(origin, false)
			}
			else
			{
				get_user_origin(id, origin, 3)
				
				addItem(origin, true)
			}
		}
		case 2:
			deleteItem(id)
		case 3:
			deleteAllItems()
		case 4:
			GroundAllItems()
	}
	menu_display(id, g_Menu, 0)
	
	return PLUGIN_CONTINUE
}

public fwd_Touch(toucher, touched)
{
	if (!is_user_alive(toucher) || !pev_valid(touched))
		return FMRES_IGNORED
	
	new classname[32]	
	pev(touched, pev_classname, classname, 31)
	if (!equal(classname, item_class_name))
		return FMRES_IGNORED
	
	CountBox--
	
	SpawnBox(toucher)
	set_pev(touched, pev_effects, EF_NODRAW)
	set_pev(touched, pev_solid, SOLID_NOT)
	removeEntity(touched)
	
	return FMRES_IGNORED
	
}

public fwd_PlayerPreThink(id)
{
	if(gIsFrosted[id])
	{
		set_pev(id, pev_velocity, Float:{0.0,0.0,0.0})		
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN); 
	}
	
	if(Speed[id])
	{
		if (zp_get_user_zombie(id))
			fm_set_user_maxspeed(id, get_pcvar_float(cvar_Speed_Z))
		else
			fm_set_user_maxspeed(id, get_pcvar_float(cvar_Speed_H))
	}
}

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	if (!is_user_connected(attacker) || !is_user_connected(victim) || attacker == victim || !attacker)
		return HAM_IGNORED
	
	Gravity[victim] = false
	Speed[victim] = false
	Bright[victim] = false
	
	if (random_num(1, get_pcvar_num(cvar_Spawn)) == 1)
	{
		new origin[3]
		get_user_origin(victim, origin, 0)
		
		addItem(origin, false)
	}
	
	return HAM_IGNORED
}

public event_DeathMsg()
{
	new id = read_data(2)
	
	if(gIsFrosted[id])
		RemoveFrost(id)
}

public event_ResetHud(id)
{
	if(gIsFrosted[id]) 
		RemoveFrost(id)
}

public removeEntity(ent)
{
	if (pev_valid(ent))
		engfunc(EngFunc_RemoveEntity, ent)
}

public addItem(origin[3], fly)
{
	if (CountBox > MAXBOX)
		return PLUGIN_CONTINUE

	CountBox++	
	
	new ent = fm_create_entity("info_target")
	set_pev(ent, pev_classname, item_class_name)
	
	engfunc(EngFunc_SetModel,ent, g_models[random_num(0, sizeof g_models - 1)])

	set_pev(ent,pev_mins,Float:{-10.0,-10.0,0.0})
	set_pev(ent,pev_maxs,Float:{10.0,10.0,25.0})
	set_pev(ent,pev_size,Float:{-10.0,-10.0,0.0,10.0,10.0,25.0})
	engfunc(EngFunc_SetSize,ent,Float:{-10.0,-10.0,0.0},Float:{10.0,10.0,25.0})
	
	set_pev(ent,pev_solid,SOLID_BBOX)
	
	if (fly)
		set_pev(ent,pev_movetype,MOVETYPE_FLY)
	else
		set_pev(ent,pev_movetype,6)
	
	new Float:fOrigin[3]
	IVecFVec(origin, fOrigin)
	set_pev(ent, pev_origin, fOrigin)
	
	if (get_pcvar_num(cvar_Aura) == 1)
	{
		switch(random_num(1,4))
		{
			case 1: {r = 0; g = 0; b = 255;}
			case 2: {r = 0; g = 255; b = 0;}
			case 3: {r = 255; g = 0; b = 0;}
			case 4: {r = 255; g = 255; b = 255;}
		}
	}
	if (get_pcvar_num(cvar_Aura) == 2)
	{
		r = random_num( 0,255 )
		g = random_num( 0,255 )
		b = random_num( 0,255 )
	}
	
	if (get_pcvar_num(cvar_Aura) != 0)
		fm_set_rendering(ent,kRenderFxGlowShell, r, g, b, kRenderNormal, 16)
	
	set_pev(ent, pev_iuser1, r)
	set_pev(ent, pev_iuser2, g)
	set_pev(ent, pev_iuser3, b)
	
	set_pev(ent, pev_nextthink, get_gametime())
	
	if(get_pcvar_num(cvar_Spin) || get_pcvar_num(cvar_Sprite)) 
		set_task(0.1, "boxopt", ent)
	
	if (get_pcvar_num(cvar_MsgToAll))
		client_print(0, print_center, "%L", LANG_PLAYER, "BX_BOXSPAWN")
	
	return PLUGIN_CONTINUE
}

public fwd_Think(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED

	new class[32]	
	pev(ent, pev_classname, class, 31)
	if (!equal(class, item_class_name))
		return FMRES_IGNORED
		
	if(get_pcvar_num(cvar_Light)) 
	{ 
		static Float:origin[3] 
		pev(ent, pev_origin, origin) 
		
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0) 
		write_byte(TE_DLIGHT) 
		engfunc(EngFunc_WriteCoord, origin[0]) 
		engfunc(EngFunc_WriteCoord, origin[1]) 
		engfunc(EngFunc_WriteCoord, origin[2]) 
		write_byte(get_pcvar_num(cvar_Light_radius)) 
		write_byte(pev(ent, pev_iuser1)) 
		write_byte(pev(ent, pev_iuser2)) 
		write_byte(pev(ent, pev_iuser3)) 
		write_byte(51) 
		write_byte(0) 
		message_end() 
	}
	set_pev(ent, pev_nextthink, get_gametime() + 5.0)
	
	return FMRES_IGNORED
}

public boxopt(ent)
{
	if (!pev_valid(ent))
		return PLUGIN_CONTINUE
		
	if(get_pcvar_num(cvar_Spin)) 
	{
		static Float:angles[3] 
		pev(ent, pev_angles, angles) 
		
		angles[1] = angles[1] - get_pcvar_float(cvar_SpeedSpin)
			
		set_pev(ent, pev_angles, angles) 
	}
	
	if (get_pcvar_num(cvar_Sprite))
	{
		static Float:origin[3] 
		pev(ent, pev_origin, origin) 
		engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_TEMPENTITY, origin, 0)
		write_byte(TE_SPRITE)
		engfunc(EngFunc_WriteCoord, origin[0]) 
		engfunc(EngFunc_WriteCoord, origin[1]) 
		engfunc(EngFunc_WriteCoord, origin[2]+45) 
		write_short(gSprBox)
		write_byte(10)
		write_byte(200)
		message_end()
	}

	set_task(0.1, "boxopt", ent)
	
	return PLUGIN_CONTINUE
}

public SpawnBox(id)
{
	new zombie
	zombie = zp_get_user_zombie(id)
		
	new i = random_num(0, (zombie ? 11 : 21))
	
	new founder[32]
	get_user_name(id, founder, 31)
	
	switch (i)
	{
		case 0:
			if (zombie)
			{
				if (!zp_get_user_last_zombie(id) && !zp_get_user_nemesis(id) && !zp_is_nemesis_round() && !zp_is_survivor_round() && !zp_is_swarm_round() && !zp_is_plague_round())
				{
					zp_disinfect_user(id)
					ChatColor(id, "!g[ZP]!y %L", id, "BX_ANTIDOT")
				}
				else
					ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
			}
			else
			{
				if (!zp_get_user_last_human(id) && !zp_get_user_survivor(id) && !zp_is_nemesis_round() && !zp_is_survivor_round() && !zp_is_swarm_round() && !zp_is_plague_round())
				{
					zp_infect_user(id)
					ChatColor(id, "!g[ZP]!y %L", id, "BX_INFECT")
				}
				else
					ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
			}
			
		case 1:
		{
			fm_set_user_health(id, get_user_health(id) + (zombie ? get_pcvar_num(cvar_Health_add_Z) : get_pcvar_num(cvar_Health_add_H)))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_HEALTH_UP")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[0])
		}
		case 2:
		{
			Boom(id)
			fm_set_user_health(id, get_user_health(id) - (zombie ? get_pcvar_num(cvar_Health_del_Z) : get_pcvar_num(cvar_Health_del_H)))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_HEALTH_DOWN")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[1])
		}
		case 3:
		{
			zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + random_num(1, get_pcvar_num(cvar_Ammopacks_add)))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_AMMOPACKS_UP")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[2])
		}
		case 4:
		{
			zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) - random_num(1, get_pcvar_num(cvar_Ammopacks_del)))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_AMMOPACKS_DOWN")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[3])
		}
		case 5:
			if (zombie)
			{
				if (!zp_get_user_nemesis(id) && !zp_is_nemesis_round() && !zp_is_survivor_round() && !zp_is_swarm_round() && !zp_is_plague_round())
				{
					new name[32]
					get_user_name(id, name, 31)
					
					zp_make_user_nemesis(id)
					ChatColor(0, "!g[ZP]!y %L", id, "BX_NEMESIS", name)
				}
				else
					ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
			}
			else
			{
				if (!zp_get_user_survivor(id) && !zp_is_nemesis_round() && !zp_is_survivor_round() && !zp_is_swarm_round() && !zp_is_plague_round())
				{
					new name[32]
					get_user_name(id, name, 31)
				
					zp_make_user_survivor(id)
					ChatColor(0, "!g[ZP]!y %L", id, "BX_SURVIVOR", name)
				}
				else
					ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
			}
		case 6:
		{
			if (zombie && !zp_get_user_nemesis(id) && !zp_is_nemesis_round() && !zp_is_survivor_round() && !task_exists(id))
			{
				fm_set_user_rendering(id, kRenderFxNone, 0, 0, 0,kRenderTransAlpha, 0)

				ChatColor(id, "!g[ZP]!y %L", id, "BX_INVISIBLE", get_pcvar_float(cvar_Invisible_time))

				set_task(get_pcvar_float(cvar_Invisible_time), "remove_invisible", id)
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[4])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
		}
		case 7:
		{
			if (!task_exists(id))
			{
				fm_set_rendering(id, kRenderFxGlowShell, 100, 149, 237, kRenderNormal,25)
				engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, gSoundFrosted, 1.0, ATTN_NORM, 0, PITCH_NORM)
			
				message_begin(MSG_ONE, gScreenfade, _, id)
				write_short(~0)
				write_short(~0)
				write_short(0x0004)
				write_byte(100)
				write_byte(149)
				write_byte(237)
				write_byte(100)
				message_end()
				
				gIsFrosted[id] = true
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_FROST")
				
				set_task(get_pcvar_float(cvar_FrostTime), "RemoveFrost", id)
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[5])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
		}
		case 8:
		{
			if (!Gravity[id])
			{
				fm_set_user_gravity(id, get_pcvar_float(cvar_Gravity))
				ChatColor(id, "!g[ZP]!y %L", id, "BX_GRAVITY")
				
				Gravity[id] = true
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[6])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 9:
		{
			if (!Speed[id])
			{
				if (zombie)
					ChatColor(id, "!g[ZP]!y %L", id, "BX_SPEED_UP")
				else
					ChatColor(id, "!g[ZP]!y %L", id, "BX_SPEED_DOWN")

				Speed[id] = true
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[7])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 10:
		{
			if (zombie && !get_user_godmode(id) && !task_exists(id))
			{
				set_user_godmode(id, 1)
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_GODMODE", get_pcvar_float(cvar_Godmode_time))
				
				set_task(get_pcvar_float(cvar_Godmode_time), "disable_godmode", id)
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[8])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")	
		}
		case 11:
		{
			if (ExtrazCount && zombie)
			{
				new Extraz_rand = random_num(0, (ExtrazCount - 1))
				
				zp_force_buy_extra_item(id, zp_get_extra_item_id(ExtraZombies[Extraz_rand]), 1)
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[17])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 12:
		{
			if (!Bright[id])
			{
				set_pev(id, pev_effects, pev(id, pev_effects) | EF_BRIGHTLIGHT)
				ChatColor(id, "!g[ZP]!y %L", id, "BX_BRIGHTLIGHT")
				
				Bright[id] = true
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[9])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 13:
		{
			if (!zp_get_user_nightvision(id))
			{
				zp_set_user_nightvision(id, 1)
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NIGHTVISION")
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[10])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 14:
		{
			fm_set_user_armor(id, get_user_armor(id) + get_pcvar_num(cvar_Armor_add))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_ARMOR_UP")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[11])
		}
		case 15:
		{
			fm_set_user_armor(id, get_user_armor(id) - get_pcvar_num(cvar_Armor_del))
			ChatColor(id, "!g[ZP]!y %L", id, "BX_ARMOR_DOWN")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[11])
		}
		case 16:
		{
			fm_give_item(id, "weapon_flashbang")
			fm_give_item(id, "weapon_smokegrenade")
			fm_give_item(id, "weapon_hegrenade")
			
			set_pdata_int(id, OFFSET_FLASH_AMMO, get_pcvar_num(cvar_FLASH))
			set_pdata_int(id, OFFSET_HE_AMMO, get_pcvar_num(cvar_HE))
			set_pdata_int(id, OFFSET_SMOKE_AMMO, get_pcvar_num(cvar_SMOKE))
			
			ChatColor(id, "!g[ZP]!y %L", id, "BX_GRENADES")
			
			if (get_pcvar_num(cvar_MsgToAll) == 2)
				client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[12])
		}
		case 17:
		{
			if (!user_has_weapon(id, CSW_SG550))
			{
				fm_give_item(id, "weapon_sg550")
				ExecuteHamB(Ham_GiveAmmo, id, 90, "556nato", 90)
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_SG550")
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[13])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 18:
		{
			if (!user_has_weapon(id, CSW_G3SG1))
			{
				fm_give_item(id, "weapon_g3sg1")
				ExecuteHamB(Ham_GiveAmmo, id, 90, "762nato", 90)
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_G3SG1")
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[14])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 19:
		{
			if (!user_has_weapon(id, CSW_M249))
			{
				fm_give_item(id, "weapon_m249")
				ExecuteHamB(Ham_GiveAmmo, id, 200, "556natobox", 200)
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_M249")
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[15])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 20:
		{
			if (!user_has_weapon(id, CSW_AWP))
			{
				fm_give_item(id, "weapon_awp")
				ExecuteHamB(Ham_GiveAmmo, id, 30, "338magnum", 30)
				
				ChatColor(id, "!g[ZP]!y %L", id, "BX_AWP")
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[16])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
		case 21:
		{
			if (ExtrahCount)
			{
				new Extrah_rand = random_num(0, (ExtrahCount - 1))
				
				zp_force_buy_extra_item(id, zp_get_extra_item_id(ExtraHumans[Extrah_rand]), 1)
				
				if (get_pcvar_num(cvar_MsgToAll) == 2)
					client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND_ON", founder, gItems[17])
			}
			else
				ChatColor(id, "!g[ZP]!y %L", id, "BX_NO")
		}
	}
	
	if (get_pcvar_num(cvar_MsgToAll) == 1)
		client_print(0, print_center, "%L", LANG_PLAYER, "BX_FOUND", founder)
}

public deleteItem(id)
{
	new ent, a_body
	get_user_aiming(id, ent, a_body)
	if (!pev_valid(ent))
		return PLUGIN_CONTINUE
		
	new class[32]
	pev(ent, pev_classname, class, 31)
	if (!equal(class, item_class_name))
		return PLUGIN_CONTINUE
	
	CountBox--
	
	set_pev(ent, pev_flags, FL_KILLME)
	
	return PLUGIN_CONTINUE
}

public deleteAllItems()
{
	CountBox = 0

	new ent = FM_NULLENT
	static string_class[] = "classname"
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, string_class, item_class_name))) 
		set_pev(ent, pev_flags, FL_KILLME)
}

public GroundAllItems()
{
	new ent = FM_NULLENT
	static string_class[] = "classname"
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, string_class, item_class_name))) 
		set_pev(ent,pev_movetype,6)
}

public round_start()
{
	for (new i=1; i<=g_maxplayers; i++)
	{
		Gravity[i] = false
		Speed[i] = false
		Bright[i] = false
	}
	
	deleteAllItems()
}

public zp_user_infected_post(id, infector)
{
	Gravity[id] = false
	Speed[id] = false
	Bright[id] = false
}

public zp_user_humanized_post(id, survivor)
{
	Gravity[id] = false
	Speed[id] = false
	Bright[id] = false
}
	
public remove_invisible(Player)
{
	fm_set_user_rendering(Player)
	
	remove_task(Player)
	
	ChatColor(Player, "!g[ZP]!y %L", Player, "BX_INVISIBLE_REMOVE")
}

public RemoveFrost(id) 
{
	if(!gIsFrosted[id]) // not alive / not frozen anymore
		return;
		
	// unfreeze
	gIsFrosted[id] = false;
	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
		
	set_pev(id, pev_gravity, fm_get_user_gravity(id))

	engfunc(EngFunc_EmitSound, id, CHAN_VOICE, gSoundBreak, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	fm_set_rendering(id)
	
	message_begin(MSG_ONE, gScreenfade, _, id);
	write_short(0); // duration
	write_short(0); // hold time
	write_short(0); // flags
	write_byte(0); // red
	write_byte(0); // green
	write_byte(0); // blue
	write_byte(0); // alpha
	message_end();
	
	static origin[3], Float:originF[3]
	pev(id, pev_origin, originF)
	FVecIVec(originF, origin)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL);
	write_coord(origin[0]);		// x
	write_coord(origin[1]);		// y
	write_coord(origin[2] + 24);	// z
	write_coord(16);		// size x
	write_coord(16);		// size y
	write_coord(16);		// size z
	write_coord(random_num(-50,50));// velocity x
	write_coord(random_num(-50,50));// velocity y
	write_coord(25);		// velocity z
	write_byte(10);			// random velocity
	write_short(gGlass);		// model
	write_byte(10);			// count
	write_byte(25);			// life
	write_byte(0x01);		// flags: BREAK_GLASS
	message_end();
}

public Boom(id)
{
	// Get end aim origin
	new iOrigin[3]
	get_user_origin(id, iOrigin, 0)
	
	// Explosion
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, iOrigin) 
	write_byte(TE_EXPLOSION)	
	write_coord(iOrigin[0]) 
	write_coord(iOrigin[1]) 
	write_coord(iOrigin[2]) 
	write_short(gSprBoom)	
	write_byte(60)	// scale in 0.1's	
	write_byte(20)	// framerate			
	write_byte(TE_EXPLFLAG_NONE)	
	message_end()
	
	emit_sound(id, CHAN_AUTO, "weapons/explode5.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public disable_godmode(id)
{
	set_user_godmode(id)
	
	remove_task(id)
	
	ChatColor(id, "!g[ZP]!y %L", id, "BX_GODMODE_DISABLE")
}

// Stock: ChatColor!
stock ChatColor(const id, const input[], any:...)
{
	new count = 1, players[32]
	static msg[191]
	vformat(msg, 190, input, 3)
	
	replace_all(msg, 190, "!g", "^4") // Green Color
	replace_all(msg, 190, "!y", "^1") // Default Color
	replace_all(msg, 190, "!team", "^3") // Team Color
	replace_all(msg, 190, "!team2", "^0") // Team2 Color
	
	if (id) players[0] = id; else get_players(players, count, "ch")
	{
		for (new i = 0; i < count; i++)
		{
			if (is_user_connected(players[i]))
			{
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
}