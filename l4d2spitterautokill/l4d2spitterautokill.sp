#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new Handle:Spitter_Timer[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "[L4D2] Spitter Autokill",
	author = "Accelerator",
	description = "",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public OnPluginStart()
{
	HookEvent("player_spawn", EventPlayerSpawn);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("player_death", EventPlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
}

public Action:EventPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsSpitter(client))
	{
		if (Spitter_Timer[client] != INVALID_HANDLE)
		{
			KillTimer(Spitter_Timer[client]);
			Spitter_Timer[client] = INVALID_HANDLE;
		}
		Spitter_Timer[client] = CreateTimer(22.0, Timer_Autokill, client);
	}
	
	return Plugin_Continue;
}

public Action:Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsSpitter(client))
	{
		if (Spitter_Timer[client] != INVALID_HANDLE)
		{
			KillTimer(Spitter_Timer[client]);
			Spitter_Timer[client] = INVALID_HANDLE;
		}
		Spitter_Timer[client] = CreateTimer(10.0, Timer_Autokill, client);
	}
	
	return Plugin_Continue;
}

public Action:EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (Spitter_Timer[client] != INVALID_HANDLE)
	{
		KillTimer(Spitter_Timer[client]);
		Spitter_Timer[client] = INVALID_HANDLE;
	}
	
	return Plugin_Continue;
}

public Action:Timer_Autokill(Handle:timer, any:client)
{
	if (!IsClientInGame(client))
	{
		Spitter_Timer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if (!IsPlayerAlive(client))
	{
		Spitter_Timer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if (IsSpitter(client))
	{
		ForcePlayerSuicide(client);
		PrintHintText(client, "Autokill\nDo not hold Spitter!");
	}
	
	Spitter_Timer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (Spitter_Timer[i] != INVALID_HANDLE)
		{
			KillTimer(Spitter_Timer[i]);
			Spitter_Timer[i] = INVALID_HANDLE;
		}
	}
}

bool:IsSpitter(client)
{
	return bool:(client > 0 && client <= MaxClients && !IsFakeClient(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 4 && !(GetEntProp(client, Prop_Send, "m_isGhost") > 0));
}