#include <amxmodx>

#define PLUGIN "[ZP] Addon: Rand Lighting"
#define VERSION "1.1"
#define AUTHOR "Accelerator"

new rand_light, cvar_rand

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)	
	
	cvar_rand = register_cvar("zp_rand_lighting", "0")
	
	rand_light = random_num(0, 3)
	
	set_task(15.0, "light_change")
}

public light_change()
{	
	new Float:rand_timer
	
	if (!get_pcvar_num(cvar_rand))
	{
		if (rand_light++ == 3)
			rand_light = 0
	}
	else
		rand_light = random_num(0, 3)
	
	switch(rand_light)
	{
		case 0:
		{
			server_cmd("zp_lighting a")
			rand_timer = random_float(180.0, 300.0)
			ChatColor(0, "!g[ZP]!y Time of Day: Night (%.0f seconds)", rand_timer)
		}
		case 1:
		{
			server_cmd("zp_lighting f")
			rand_timer = random_float(40.0, 75.0)
			ChatColor(0, "!g[ZP]!y Time of Day: Day (%.0f seconds)", rand_timer)
		}
		case 2:
		{
			server_cmd("zp_lighting c")
			rand_timer = random_float(120.0, 250.0)
			ChatColor(0, "!g[ZP]!y Time of Day: Evening (%.0f seconds)", rand_timer)
		}
		case 3:
		{
			server_cmd("zp_lighting b")
			rand_timer = random_float(60.0, 120.0)
			ChatColor(0, "!g[ZP]!y Time of Day: Twilight (%.0f seconds)", rand_timer)
		}
	}
	
	set_task(rand_timer, "light_change")
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