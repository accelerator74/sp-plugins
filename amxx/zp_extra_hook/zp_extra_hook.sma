/*==================================================================================================

				==================================
				=     Kz-Arg Mod By ReymonARG    =
				==================================
				

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
				Copyright © 2008, ReymonARG
			   This file is provided as is (no warranties)

	Kz-Arg Mod is free software;
	you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with Kz-Arg Mod; if not, write to the
	Free Software Foundation, Inc., 59 Temple Place - Suite 330,
	Boston, MA 02111-1307, USA.
	
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = 
	
	// Creadits
	* Teame06
	* Kz-Arg Server
	* Nv-Arg Community
	* KzM Servers that I get the Model of de PHP for Top15:D
	* Xtreme-Jumps.eu
	* All persons that help in  AMX Mod X > Scripting
		arkshine, Emp`, danielkza, anakin_cstrike, Exolent[jNr], connorr,
		|PJ| Shorty, stupok, SchlumPF, etc..

	
	// Friends :D
	* Ckx 			( Argentina )		Kz Player
	* ChaosAD 		( Argentina ) 		Kz Player
	* Kunqui 		( Argentina ) 		Kz Player
	* RTK 			( Argentina )		Kz Player
	* BLT 			( Argentina ) 		Kz Player
	* Juann			( Argentina ) 		Scripter
	* Juanchox 		    ( ? ) 		Kz Player
	* Pajaro^		( Argentina )		Kz Player
	* Limado 		( Argentina )		Kz Player
	* Pepo 			( Argentina )		Kz Player
	* Kuliaa		( Argentina )		Kz Player
	* Mucholote		 ( Ecuador )		Kz Player
	* Creative & Yeans	  ( Spain )		Request me the Plugin, So I did :D
												 
===============================================================================R=E=Y=M=O=N==A=R=G=*/
#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "[ZP] Extra Item: Hook"
#define VERSION "1.1"
#define AUTHOR "ReymonARG & STRELOK (ZP Extra)"

new Float:g_hook_speed[33];
new Float:gravity;
new g_hook_color[33];
new g_naturalcolor[33][3];
new bool:hook[33];
new hook_to[33][3];
new hashook[33];
new beamsprite;
new g_item, g_maxplayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_concmd("+hook","hook_on");
	register_concmd("-hook","hook_off");
	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")
	
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")  
	g_maxplayers = get_maxplayers();
	
	g_item = zp_register_extra_item("Hook", 25, ZP_TEAM_HUMAN & ZP_TEAM_ZOMBIE)
}

public plugin_precache()
{
	beamsprite = precache_model("sprites/plasma.spr")
}

public zp_extra_item_selected(player, itemid)
{
	gravity = fm_get_user_gravity(player)
	
	if (itemid == g_item)
	{
		client_cmd(player, "bind v +hook")
		hashook[player] = true
		client_print(player, print_chat, "[ZP] You bought Hook. Use button V to pull the rope");
	}
}
	
public client_connect(id)
{
	g_hook_speed[id] = 320.0;
	g_hook_color[id] = 0;
	hashook[id] = false;
}

public event_round_start()
{
	for(new i = 1; i < g_maxplayers; i++)
		hashook[i] = false;
}

public hook_on(id)
{
	if( !hashook[id] || hook[id] )
		return PLUGIN_HANDLED;
	
	set_pev(id, pev_gravity, 0.0);
	set_task(0.1,"hook_prethink",id+10000,"",0,"b");
	hook[id]=true;
	hook_to[id][0]=999999;
	hook_prethink(id+10000);
	return PLUGIN_HANDLED;
}

public hook_off(id)
{
	if (zp_get_user_zombie(id))
	{
		set_pev(id, pev_gravity, gravity);
	}
	else
	{
		set_pev(id, pev_gravity, 1.0);
	}
	
	hook[id] = false;
	return PLUGIN_HANDLED;
}

public zp_user_infected_post(id, infector)
	hashook[id] = false;

public fw_PlayerKilled(victim, attacker, shouldgib)
	hashook[victim] = false;

public hook_prethink(id)
{
	id -= 10000;
	
	if(!is_user_alive(id))
		hook[id]=false;
	
	if(!hook[id])
	{
		remove_task(id+10000);
		return PLUGIN_HANDLED;
	}


	static origin1[3];
	new Float:origin[3];
	get_user_origin(id,origin1);
	pev(id, pev_origin, origin);

	if(hook_to[id][0]==999999)
	{
		static origin2[3];
		get_user_origin(id,origin2,3);
		hook_to[id][0]=origin2[0];
		hook_to[id][1]=origin2[1];
		hook_to[id][2]=origin2[2];
	}

	//Create blue beam
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(1);
	write_short(id);
	write_coord(hook_to[id][0]);
	write_coord(hook_to[id][1]);
	write_coord(hook_to[id][2]);
	write_short(beamsprite);
	write_byte(1);
	write_byte(1);
	write_byte(5);
	write_byte(18);
	write_byte(0);
	if( g_hook_color[id] == 0 )
	{
		write_byte(random(256));
		write_byte(random(256));
		write_byte(random(256));
	}
	else if( g_hook_color[id] == 1 )
	{
		write_byte(g_naturalcolor[id][0]);
		write_byte(g_naturalcolor[id][1]);
		write_byte(g_naturalcolor[id][2]);
	}
	write_byte(200);
	write_byte(0);
	message_end();

	//Calculate Velocity
	static Float:velocity[3];
	velocity[0] = (float(hook_to[id][0]) - float(origin1[0])) * 3.0;
	velocity[1] = (float(hook_to[id][1]) - float(origin1[1])) * 3.0;
	velocity[2] = (float(hook_to[id][2]) - float(origin1[2])) * 3.0;

	static Float:y;
	y = velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2];

	static Float:x;
	x = (g_hook_speed[id]) / floatsqroot(y);

	velocity[0] *= x;
	velocity[1] *= x;
	velocity[2] *= x;

	set_velo(id,velocity);

	return PLUGIN_CONTINUE;
}

public set_velo(id,Float:velocity[3])
	return set_pev(id,pev_velocity,velocity);
