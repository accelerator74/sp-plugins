#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombieplague>

#pragma newdecls required

bool round_no_block = false;

bool g_ShouldCollide[MAXPLAYERS + 1] = { true, ... };
float g_ShouldCollideTime[MAXPLAYERS + 1];

float EngineTime;
float eTime;
float LastTick;

public Plugin myinfo =
{
	name = "[ZP] Addon: Semiclip",
	author = "Accelerator",
	description = "",
	version = "3.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	LoadTranslations("semiclip.phrases");
	
	HookEvent( "round_start", Event_RoundStart );
	HookEvent( "player_spawn", EventPlayerSpawn );
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i)) 
			OnClientPutInServer(i);
	}
}

public void EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!client)
		return;
	
	if (round_no_block)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	round_no_block = true;
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientConnected( i ) && IsClientInGame( i ) )
			SetEntProp(i, Prop_Data, "m_CollisionGroup", 2);
	}
}

public void ZP_OnZombieModStarted(int modeIndex)
{
	round_no_block = false;
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientConnected( i ) && IsClientInGame( i ) )
			SetEntProp(i, Prop_Data, "m_CollisionGroup", 5);
	}
	CreateTimer(7.0, Timer_Info);
}

public Action Timer_Info(Handle timer)
{
	PrintHintTextToAll("%t", "How_Use");
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientConnected( i ) && IsClientInGame( i ) && !IsFakeClient( i ))
			QueryClientConVar(i, "cl_use_opens_buy_menu", view_as<ConVarQueryFinished>(ClientConVar), i);
	}
}

public void ClientConVar(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (StringToInt(cvarValue) == 1)
	{
		PrintToChat(client, "%t", "Buy_Use");
		PrintToChat(client, "%t", "Buy_Use_Disable");
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon)
{
	if (round_no_block)
		return;
	
	if (buttons & IN_USE)
	{
		EngineTime = GetEngineTime();
		
		g_ShouldCollide[client] = false;
		g_ShouldCollideTime[client] = EngineTime;
		
		if (EngineTime - LastTick > 0.1)
		{
			LastTick = EngineTime;
			
			float location[3], targetOrigin[3];
			GetClientAbsOrigin(client, location);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					if (IsPlayerAlive(i))
					{
						if (GetClientTeam(client) == GetClientTeam(i))
						{
							GetClientAbsOrigin(i, targetOrigin);
							
							if (GetVectorDistance(targetOrigin, location) <= 80.0)
							{
								g_ShouldCollide[i] = false;
								g_ShouldCollideTime[i] = EngineTime;
							}
						}
					}
				}
			}
		}
	}
}

public void OnGameFrame()
{
	eTime = GetEngineTime() - 1.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_ShouldCollideTime[i] > 0.0 && eTime >= g_ShouldCollideTime[i])
		{
			g_ShouldCollide[i] = true;
			g_ShouldCollideTime[i] = 0.0;
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_ShouldCollide, ShouldCollide);
}

public bool ShouldCollide(int entity, int collisiongroup, int contentsmask, bool result)
{
	if (contentsmask == 33636363)
	{
		if(!g_ShouldCollide[entity])
		{
			result = false;
			return false;
		}
		else
		{
			result = true;
			return true;
		}
	}
	
	return true;
}