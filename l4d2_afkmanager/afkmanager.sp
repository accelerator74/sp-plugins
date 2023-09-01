#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#pragma newdecls required

enum struct PlayerData {
	int specTime;
	int afkTime;
	int shoved;
	float position[3];
	float angles[2];
}

PlayerData playerData[MAXPLAYERS+1];

ConVar l4d2_afk_kick;
ConVar l4d2_afk_time;

int g_iAfkKick;
int g_iAfkTime;

public Plugin myinfo = 
{
	name = "AFK Manager",
	author = "Accelerator",
	description = "AutoKick AFK Players",
	version = "3.5",
	url = "https://github.com/accelerator74/sp-plugins"
}

public void OnPluginStart()
{
	l4d2_afk_kick = CreateConVar("l4d2_afk_kick", "350", "AFK time after which you will be kicked");
	l4d2_afk_time = CreateConVar("l4d2_afk_time", "60", "AFK time after which you will be moved to the Spectator team");
	
	g_iAfkKick = l4d2_afk_kick.IntValue;
	g_iAfkTime = l4d2_afk_time.IntValue;
	
	l4d2_afk_kick.AddChangeHook(OnConVarChange);
	l4d2_afk_time.AddChangeHook(OnConVarChange);
	
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_hurt", Event_PlayerShoved);
	HookEvent("player_shoved", Event_PlayerShoved);
	
	HookEntityOutput("func_button_timed", "OnPressed", OnButtonPress);
}

public void OnMapStart()
{
	CreateTimer(1.0, timer_AfkCheck, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void OnConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_iAfkKick = l4d2_afk_kick.IntValue;
	g_iAfkTime = l4d2_afk_time.IntValue;
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	playerData[client].position = view_as<float>({0.0, 0.0, 0.0});
	playerData[client].angles = view_as<float>({0.0, 0.0});
	playerData[client].specTime = 0;
	playerData[client].afkTime = 0;
	playerData[client].shoved = 0;
}

void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	playerData[GetClientOfUserId(event.GetInt("userid"))].shoved = 2;
}

void OnButtonPress(const char[] name, int caller, int activator, float delay)
{
	if (activator < 1 || activator > MaxClients)
		return;
	
	playerData[activator].afkTime = 0;
}

Action timer_AfkCheck(Handle timer)
{
	int idx;
	bool isAFK;
	float curPosition[3], curAngles[3];

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			if(GetClientTeam(client) <= 1)
			{
				if(GetUserAdmin(client) != INVALID_ADMIN_ID)
					continue;
				
				playerData[client].specTime++;
				
				if(playerData[client].specTime >= g_iAfkKick)
				{
					KickClient(client, "You were AFK for too long (%i sec)", playerData[client].specTime);
				}
				else
				{
					PrintCenterText(client, "AFK autokick: %i sec", g_iAfkKick - playerData[client].specTime);
				}
			}
			else
			{
				if(!IsPlayerAlive(client))
					continue;
				
				if(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) || GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1))
					continue;
				
				GetClientAbsOrigin(client, curPosition);
				
				if (IsInSaferoom(curPosition))
					continue;
				
				GetClientEyeAngles(client, curAngles);
				
				isAFK = true;
				
				if(GetVectorDistance(curPosition, playerData[client].position) > 80.0)
				{
					isAFK = false;
				}
				
				if(isAFK)
				{
					if(curAngles[0] != playerData[client].angles[0] && 
						curAngles[1] != playerData[client].angles[1]) 
					{
						isAFK = false;
					}
				}
				
				for(idx = 0; idx < 2; idx++)
				{
					playerData[client].position[idx] = curPosition[idx];
					playerData[client].angles[idx] = curAngles[idx];
				}
				
				playerData[client].position[2] = curPosition[2];
				
				if(isAFK)
				{
					playerData[client].afkTime++;
					
					if(playerData[client].afkTime >= g_iAfkTime)
					{
						SetEntProp(client, Prop_Send, "m_iGlowType", 0);
						SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
						SetEntProp(client, Prop_Send, "m_bFlashing", 0);
						SetEntProp(client, Prop_Send, "m_nGlowRange", 0);
						RequestFrame(MoveToSpectator, GetClientUserId(client));
					}
				}
				else
				{
					if (playerData[client].shoved-- <= 0)
						playerData[client].afkTime = 0;
				}
			}
		}
	}
	return Plugin_Continue;
}

void MoveToSpectator(any client)
{
	if ((client = GetClientOfUserId(client)) == 0)
		return;
	
	ChangeClientTeam(client, 1);
	PrintToChat(client, "\x05You moved in spectators for inaction");
}

bool IsInSaferoom( const float vOrigin[3] )
{
	int info_changelevel = MaxClients + 1;
	
	while ( (info_changelevel = FindEntityByClassname(info_changelevel, "info_changelevel")) && IsValidEntity(info_changelevel) )
	{
		float vMins[3], vMaxs[3];
		GetEntPropVector(info_changelevel, Prop_Data, "m_vecMins", vMins);
		GetEntPropVector(info_changelevel, Prop_Data, "m_vecMaxs", vMaxs);

		if ( IsPointInBox(vOrigin, vMins, vMaxs) )
            return true;
	}
	
	return false;
}

bool IsPointInBox( const float pt[3], const float boxMin[3], const float boxMax[3] )
{
	if ( (pt[0] > boxMax[0]) || (pt[0] < boxMin[0]) )
		return false;
	if ( (pt[1] > boxMax[1]) || (pt[1] < boxMin[1]) )
		return false;
	if ( (pt[2] > boxMax[2]) || (pt[2] < boxMin[2]) )
		return false;
	
	return true;
}