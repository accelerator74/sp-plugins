#pragma semicolon 1

#include <sourcemod>
#include <colors>

#define PLUGIN_VERSION "1.2.0"

#define MAX_LINE_WIDTH 64
#define L4D_MAXPLAYERS 32
#define TEAM_SPECTATORS 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3
#define MAX_TOP_PLAYERS 6

new ZC_TANK = 5;

new Handle:counters_show_frags = INVALID_HANDLE;
new Handle:counters_show_tank_damage = INVALID_HANDLE;
new Handle:counters_show_witch_damage = INVALID_HANDLE;
new Handle:counters_show_tank_hp = INVALID_HANDLE;

new Kills[L4D_MAXPLAYERS + 1];
new TankDamage[L4D_MAXPLAYERS + 1];
new WitchDamage[L4D_MAXPLAYERS + 1];
new bool:AllowPrints;
new Time_TankSpawn;

public Plugin:myinfo = 
{
	name = "Left 4 Dead 1,2 Counters",
	author = "Jonny, Accelerator",
	description = "Some counters here.",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	counters_show_frags = CreateConVar("counters_show_frags", "1", "0 = disabled, 1 = normal (once per map), 2 = after each kill");
	counters_show_witch_damage = CreateConVar("counters_show_witch_damage", "0", "");
	counters_show_tank_damage = CreateConVar("counters_show_tank_damage", "1", "");
	counters_show_tank_hp = CreateConVar("counters_show_tank_hp", "1", "");
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_incapacitated", Event_PlayerIncapacitated);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_bot_replace", Event_Replace);
	HookEvent("bot_player_replace", Event_Replace);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
	HookEvent("witch_killed", Event_WitchKilled, EventHookMode_Post);
	HookEvent("tank_frustrated", Event_TankFrustrated, EventHookMode_PostNoCopy);
	RegConsoleCmd("sm_frags", Command_Frags);

	decl String:moddir[24];
	GetGameFolderName(moddir, sizeof(moddir));
	if (StrEqual(moddir, "left4dead2", false))
	{
		ZC_TANK = 8;
	}
}

public OnMapStart()
{
	ClearKillsCounter();
	ClearWitchDamageCounter();
	ClearTankDamageCounter();
}

public Action:Command_Frags(client, args)
{
	PrintTotalFrags(client);
}

ClearKillsCounter()
{
	for (new i = 0; i <= MaxClients; i++)
	{
		Kills[i] = 0;
	}
}

ClearWitchDamageCounter()
{
	for (new i = 0; i <= MaxClients; i++)
	{
		WitchDamage[i] = 0;
	}
}

ClearTankDamageCounter()
{
	for (new i = 0; i <= MaxClients; i++)
	{
		TankDamage[i] = 0;
	}
}

stock PrintTotalFrags(client = 0)
{
	if (!AllowPrints)
		return;
	
	new String:Message[256];
	new String:TempMessage[64];
	Message = "Frags: ";
	new bool:more_than_one = false;

	new Fraggers = 0;
	new Kills2D[L4D_MAXPLAYERS + 1][2];
	for (new i = 1; i <= MaxClients; i++)
	{
		Kills2D[i][0] = i;
		Kills2D[i][1] = 0;
		if (Kills[i] > 0)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
			{
				Kills2D[i][1] = Kills[i];
				Fraggers++;
			}
		}
	}
	SortCustom2D(Kills2D, MaxClients, Sort_Function);
	if (Fraggers > MAX_TOP_PLAYERS) Fraggers = MAX_TOP_PLAYERS;
	for (new i = 0; i < Fraggers; i++)
	{
		if (more_than_one)
		{
			FormatEx(TempMessage, sizeof(TempMessage), ", {blue}%N{default}: %d", Kills2D[i][0], Kills[Kills2D[i][0]]);
		}
		else
		{
			FormatEx(TempMessage, sizeof(TempMessage), "{blue}%N{default}: %d", Kills2D[i][0], Kills[Kills2D[i][0]]);
		}
		more_than_one = true;
		StrCat(Message, sizeof(Message), TempMessage);
	}	
	if (Fraggers == 0) return;
	
	if (client > 0)
		CPrintToChat(client, Message);
	else
	{
		CPrintToChatAll(Message);
		ClearKillsCounter();
	}
}

PrintTotalWitchDamage()
{
	if (!AllowPrints)
		return;
	
	new String:Message[256];
	new String:TempMessage[64];
	Message = "{green}Witch{default} was killed by: ";
	new bool:more_than_one = false;

	new Fraggers = 0;
	new WitchDamage2D[L4D_MAXPLAYERS + 1][2];
	for (new i = 1; i <= MaxClients; i++)
	{
		WitchDamage2D[i][0] = i;
		WitchDamage2D[i][1] = 0;
		if (WitchDamage[i] > 0)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS) 
			{
				WitchDamage2D[i][1] = WitchDamage[i];
				Fraggers++;
			}
		}
	}
	SortCustom2D(WitchDamage2D, MaxClients, Sort_Function);
	if (Fraggers > MAX_TOP_PLAYERS) Fraggers = MAX_TOP_PLAYERS;
	for (new i = 0; i < Fraggers; i++)
	{
		if (more_than_one)
		{
			FormatEx(TempMessage, sizeof(TempMessage), ", {blue}%N{default}: %d", WitchDamage2D[i][0], WitchDamage[WitchDamage2D[i][0]]);
		}
		else
		{
			FormatEx(TempMessage, sizeof(TempMessage), "{blue}%N{default}: %d", WitchDamage2D[i][0], WitchDamage[WitchDamage2D[i][0]]);
		}
		more_than_one = true;
		StrCat(Message, sizeof(Message), TempMessage);
	}	
	if (Fraggers == 0) return;
	CPrintToChatAll(Message);
}

PrintTotalTankDamage(mode)
{
	if (!AllowPrints)
		return;
	
	new String:Message[256];
	new String:TempMessage[64];
	if (mode > 0)
	{
		Message = "{green}Tank(s){default} was killed by: ";
	}
	else
	{
		Message = "{green}Tank(s){default} was damaged by: ";
		
	}
	new bool:more_than_one = false;
	
	new Fraggers = 0;
	new TankDamage2D[L4D_MAXPLAYERS + 1][2];
	for (new i = 1; i <= MaxClients; i++)
	{
		TankDamage2D[i][0] = i;
		TankDamage2D[i][1] = 0;
		if (TankDamage[i] > 0)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVORS)
			{
				TankDamage2D[i][1] = TankDamage[i];
				Fraggers++;
			}
		}
	}
	SortCustom2D(TankDamage2D, MaxClients, Sort_Function);
	if (Fraggers > MAX_TOP_PLAYERS) Fraggers = MAX_TOP_PLAYERS;
	for (new i = 0; i < Fraggers; i++)
	{
		if (more_than_one)
		{
			FormatEx(TempMessage, sizeof(TempMessage), ", {blue}%N{default}: %d", TankDamage2D[i][0], TankDamage[TankDamage2D[i][0]]);
		}
		else
		{
			FormatEx(TempMessage, sizeof(TempMessage), "{blue}%N{default}: %d", TankDamage2D[i][0], TankDamage[TankDamage2D[i][0]]);
		}
		more_than_one = true;
		StrCat(Message, sizeof(Message), TempMessage);
	}	
	if (Fraggers == 0) return;
	CPrintToChatAll(Message);
}

public Event_RoundStart(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	ClearKillsCounter();
	ClearWitchDamageCounter();
	ClearTankDamageCounter();
	AllowPrints = true;
}

public Event_RoundEnd(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	if (GetConVarInt(counters_show_frags) > 0) PrintTotalFrags();
	AllowPrints = false;
}

public Event_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	Time_TankSpawn = GetTime();
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!IsValidClient(client)) return;
	if (client)
	{
		if (IsTank(client))
		{
			TankKilled(client, attacker);
			return;
		}
	}
	if (IsValidClient(attacker) && GetClientTeam(attacker) == TEAM_SURVIVORS)
	{
		Kills[attacker]++;
		if (GetConVarInt(counters_show_frags) > 1 && attacker != client)
		{
			PrintCenterText(attacker, "%d", Kills[attacker]);
		}
	}
	if (!IsPlayersAlive())
	{
		if (!AllowPrints)
			return;
		
		decl String:sHealth[64];
		if (GetTankHP(sHealth, sizeof(sHealth)) > 0)
		{
			CPrintToChatAll("{red}Tank(s){default} had %s health remaining!", sHealth);
			PrintTotalTankDamage(0);
			ClearTankDamageCounter();
		}
		if (GetConVarInt(counters_show_frags) > 0) PrintTotalFrags();
		AllowPrints = false;
	}
}

public Event_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsPlayersAlive())
	{
		if (!AllowPrints)
			return;
		
		if (GetConVarInt(counters_show_tank_hp) > 0)
		{
			decl String:sHealth[64];
			if (GetTankHP(sHealth, sizeof(sHealth)) > 0)
			{
				CPrintToChatAll("{red}Tank(s){default} had %s health remaining!", sHealth);
				PrintTotalTankDamage(0);
				ClearTankDamageCounter();
			}
		}
		if (GetConVarInt(counters_show_frags) > 0) PrintTotalFrags();
		AllowPrints = false;
	}
}

public Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new enemy = GetClientOfUserId(GetEventInt(event, "attacker"));
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(target)) return;
	if (GetConVarInt(counters_show_tank_damage) > 0 && IsTank(target))
	{
		if (IsValidClient(enemy) && !IsIncapacitated(target))
		{
			TankDamage[enemy] += GetEventInt(event, "dmg_health");
			TankDamage[0] = GetClientHealth(target);
		}
	}
}

public Event_Replace(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	Kills[player] = 0;
	Kills[bot] = 0;
	TankDamage[player] = 0;
	TankDamage[bot] = 0;
	WitchDamage[player] = 0;
	WitchDamage[bot] = 0;
}

public Event_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new entityid = GetEventInt(event, "entityid");
	decl String:class_name[128];
	GetEdictClassname(entityid, class_name, sizeof(class_name));
	if (!StrEqual(class_name, "witch", false)) return;
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!IsValidClient(attacker)) return;
	WitchDamage[attacker] += GetEventInt(event, "amount");
	WitchDamage[0] = GetEntityHealth(entityid);
}

public Event_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(counters_show_witch_damage) < 1) return;
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));
	WitchDamage[userid] += WitchDamage[0];
	PrintTotalWitchDamage();
	ClearWitchDamageCounter();
}

public TankKilled(client, attacker)
{
	if (GetConVarInt(counters_show_tank_damage) < 1) return;
	if (GetTankHP() > 0) return;
	if (Time_TankSpawn + 5 > GetTime()) return;
	TankDamage[attacker] += TankDamage[0];
	PrintTotalTankDamage(1);
	ClearTankDamageCounter();
}

bool:IsValidClient(client)
{
	if (client < 1 || client > MaxClients) return false;
	if (!IsValidEntity(client))	return false;
	return true;
}

bool:IsTank(client)
{
	if (GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK) 
		return true;
	
	return false;
}

bool:IsIncapacitated(client)
{
	new isIncap = GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
	if (isIncap) return true;
	return false;
}

bool:IsPlayersAlive()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i) && !IsIncapacitated(i)) return true;
	}
	return false;
}

stock GetTankHP(String:sHealth[] = "", maxlen = 0)
{
	new iReturn = 0;
	new bool:more_than_one = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			if (IsTank(i) && IsPlayerAlive(i))
			{
				if (IsIncapacitated(i)) continue;
				if (maxlen > 0)
				{
					if (more_than_one)
					{
						Format(sHealth, maxlen, "%s, {olive}%i{default}", sHealth, GetClientHealth(i));
					}
					else
					{
						FormatEx(sHealth, maxlen, "{olive}%i{default}", GetClientHealth(i));
					}
				}
				more_than_one = true;
				iReturn = 1;
			}
		}
	}
	return iReturn;
}

public Sort_Function(array1[], array2[], const completearray[][], Handle:hndl)
{
	//sort function for our crown array
	if (array1[1] > array2[1]) return -1;
	if (array1[1] == array2[1]) return 0;
	return 1;
}

public GetEntityHealth(client)
{
	return GetEntProp(client, Prop_Data, "m_iHealth");
}