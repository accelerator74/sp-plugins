#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>

new bool:g_WallClimb[33]
new Float:g_wallorigin[32][3]
new g_maxplayers, item_climb

public plugin_init() 
{
	register_plugin("[ZP] Extra Item: Wall climb ", "1.0", "Python1320 & Accelerator")
	register_forward(FM_Touch, "fwd_touch")
	register_forward(FM_PlayerPreThink, "fwd_playerprethink")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	g_maxplayers = get_maxplayers()
	
	item_climb = zp_register_extra_item("Wall climb", 17, ZP_TEAM_ZOMBIE)
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == item_climb) 
	{
		g_WallClimb[player] = true
		client_print(player, print_chat, "[ZP] You bought Wall climb. Use button 'E' for wall climb");
	}
}

public zp_user_infected_post(id, infector)
	g_WallClimb[id] = false

public zp_user_humanized_post(id, survivor)
	g_WallClimb[id] = false

public fw_PlayerKilled(victim, attacker, shouldgib)
	g_WallClimb[victim] = false

public zp_round_ended(winteam)
{
	for (new id=1; id<=g_maxplayers; id++)
		g_WallClimb[id] = false
}

public client_connect(id)
	g_WallClimb[id] = false

public fwd_touch(id, world)
{
	if(!is_user_alive(id) || !g_WallClimb[id])
		return FMRES_IGNORED
		
	pev(id, pev_origin, g_wallorigin[id])

	return FMRES_IGNORED
}

public wallclimb(id, button)
{
	static Float:origin[3]
	pev(id, pev_origin, origin)

	if(get_distance_f(origin, g_wallorigin[id]) > 25.0)
		return FMRES_IGNORED  // if not near wall
	
	if(fm_get_entity_flags(id) & FL_ONGROUND)
		return FMRES_IGNORED
		
	if(button & IN_FORWARD)
	{
		static Float:velocity[3]
		velocity_by_aim(id, 120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	else if(button & IN_BACK)
	{
		static Float:velocity[3]
		velocity_by_aim(id, -120, velocity)
		fm_set_user_velocity(id, velocity)
	}
	return FMRES_IGNORED
}	

public fwd_playerprethink(id) 
{
	if(!g_WallClimb[id]) 
		return FMRES_IGNORED
	
	new button = fm_get_user_button(id)
	
	if(button & IN_USE) //Use button = climb
		wallclimb(id, button)

	return FMRES_IGNORED
}
