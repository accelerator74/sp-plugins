#include <amxmodx>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "Zombie Plague extra item - Radar"
#define VERSION "1.2"
#define AUTHOR "Sonic Son'edit & Accelerator"

new g_msgHostageAdd, g_msgHostageDel, g_maxplayers, g_itemid_radar;

new player_has_radar[33], playerz_has_radar[33];

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled")

	g_msgHostageAdd = get_user_msgid("HostagePos")
	g_msgHostageDel = get_user_msgid("HostageK")
	
	g_maxplayers = get_maxplayers()

	g_itemid_radar = zp_register_extra_item("Radar Scanner", 8, ZP_TEAM_HUMAN & ZP_TEAM_ZOMBIE)
	
	set_task (2.0,"radar_human",_,_,_,"b");
	set_task (2.1,"radar_zombie",_,_,_,"b");
}

public client_connect(id)
{
	player_has_radar[id] = false; 
	playerz_has_radar[id] = false;
}

public zp_extra_item_selected(player, itemid)
{
	if (itemid == g_itemid_radar) 
	{
		if (zp_get_user_zombie(player))
		{
			playerz_has_radar[player] = true;
		}
		else
		{
			player_has_radar[player] = true;
		}
		client_print(player, print_chat, "[ZP] You bought Radar Scanner");
	}
}

public radar_human()
{
		new zombie_count = 0;
		new zombie_list[32];
		new ZombieCoords[3];
		new id, i;
		
		for (new id=1; id<=g_maxplayers; id++)
		{
				if (is_user_connected(id) && zp_get_user_zombie(id) && is_user_alive(id))
				{
					zombie_count++;
					zombie_list[zombie_count]=id;
				}
		}
		
		for (id=1; id<=g_maxplayers; id++)
		{
			if (!is_user_alive(id) || !player_has_radar[id]) continue;
			
			for (i=1;i<=zombie_count;i++)
			{			
				get_user_origin(zombie_list[i], ZombieCoords)
			
				message_begin(MSG_ONE_UNRELIABLE, g_msgHostageAdd, {0,0,0}, id)
				write_byte(id)
				write_byte(i)		
				write_coord(ZombieCoords[0])
				write_coord(ZombieCoords[1])
				write_coord(ZombieCoords[2])
				message_end()
			
				message_begin(MSG_ONE_UNRELIABLE, g_msgHostageDel, {0,0,0}, id)
				write_byte(i)
				message_end()
			}
		}
}

public radar_zombie()
{
		new humans_count = 0;
		new humans_list[32];
		new HumansCoords[3];
		new id, i;
		
		for (new id=1; id<=g_maxplayers; id++)
		{
				if (is_user_connected(id) && !zp_get_user_zombie(id) && is_user_alive(id))
				{
					humans_count++;
					humans_list[humans_count]=id;
				}
		}
		
		for (id=1; id<=g_maxplayers; id++)
		{
			if (!is_user_alive(id) || !playerz_has_radar[id]) continue;
			
			for (i=1;i<=humans_count;i++)
			{			
				get_user_origin(humans_list[i], HumansCoords)
			
				message_begin(MSG_ONE_UNRELIABLE, g_msgHostageAdd, {0,0,0}, id)
				write_byte(id)
				write_byte(i)		
				write_coord(HumansCoords[0])
				write_coord(HumansCoords[1])
				write_coord(HumansCoords[2])
				message_end()
			
				message_begin(MSG_ONE_UNRELIABLE, g_msgHostageDel, {0,0,0}, id)
				write_byte(i)
				message_end()
			}
		}
}

public zp_user_infected_post(id, infector)
	player_has_radar[id] = false;

public zp_user_humanized_post(id, survivor)
	playerz_has_radar[id] = false;

public fw_PlayerKilled(victim, attacker, shouldgib)
{
	player_has_radar[victim] = false;
	playerz_has_radar[victim] = false;
}

public zp_round_ended(winteam)
{
		for (new id=1; id<=g_maxplayers; id++)
		{
			player_has_radar[id] = false;
			playerz_has_radar[id] = false;
		}
}
