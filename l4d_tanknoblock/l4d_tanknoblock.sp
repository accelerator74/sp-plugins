#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CHECK_RADIUS 50.0

float fg_xyz[33][5];
bool fg_active[33];
int g_VelModifierOffset = -1;

public Plugin myinfo =
{
	name = "[L4D] Tank No Block",
	author = "Accelerator & TY",
	description = "Fix stupid AI Tank",
	version = "4.2",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	g_VelModifierOffset = FindSendPropInfo("CCSPlayer", "m_flVelocityModifier");
	if (g_VelModifierOffset == -1)
	{	
		LogError("\"CCSPlayer::m_flVelocityModifier\" could not be found.");
		SetFailState("\"CCSPlayer::m_flVelocityModifier\" could not be found.");
	}
	
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("ability_use", Ability_Use);
}

Action TyTimerConnected(Handle timer, int client)
{
	if (IsTank(client))
	{
		if (fg_active[client] && fg_xyz[client][4] < GetGameTime())
		{
			float fCxyz[3];
			GetClientAbsOrigin(client, fCxyz);
			float fx3 = fg_xyz[client][0] - fCxyz[0];
			float fy3 = fg_xyz[client][1] - fCxyz[1];
			float fz3 = fg_xyz[client][2] - fCxyz[2];

			int iStuck = 0;
			float fRd1 = fg_xyz[client][3] + CHECK_RADIUS - 1.0;
			float fRd2 = - fRd1;

			fg_xyz[client][0] = fCxyz[0];
			fg_xyz[client][1] = fCxyz[1];
			fg_xyz[client][2] = fCxyz[2];

			if (fx3 > fRd2 && fx3 < fRd1)
			{
				if (fy3 > fRd2 && fy3 < fRd1)
				{
					if (fz3 > - CHECK_RADIUS && fz3 < CHECK_RADIUS)
					{
						iStuck = 1;
						fg_xyz[client][3] += 1.0;

						if (GetEntityMoveType(client) == MOVETYPE_LADDER)
						{
							fCxyz[2] += 80.0;
							TeleportEntity(client, fCxyz, NULL_VECTOR, NULL_VECTOR);
						}
						else
						{
							if (fg_xyz[client][3] > 8)
							{
								float pos[3];
								GetNearestClientPosition(client, pos);
								
								if (pos[0] != 0.0 && pos[1] != 0.0 && pos[2] != 0.0)
								{
									TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
									iStuck = 0;
								}
							}
							else if (fg_xyz[client][3] > 1)
							{
								float vel[3];
								GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel); 
								vel[2] = 600.0;
								TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
							}
						}
					}
				}
			}
			if (!iStuck)
			{
				fg_xyz[client][3] = 0.0;
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

void OnTakeDamagePost(int client, int attacker, int inflictor, float damage, int damagetype)
{
	if (damage > 0.0)
	{
		if (IsTank(client))
		{
			if (!fg_active[client] && attacker > 0 && attacker <= MaxClients)
			{
				if (GetClientTeam(attacker) == 2)
					fg_active[client] = true;
			}
			
			SetEntDataFloat(client, g_VelModifierOffset, 1.0, true);
		}
	}
}

void Event_TankSpawn(Event event, const char [] name, bool dontBroadcast)
{
	int iUserid = GetClientOfUserId(GetEventInt(event, "userid"));
	if (iUserid && IsFakeClient(iUserid))
	{
		fg_xyz[iUserid][3] = 0.0;
		fg_active[iUserid] = false;
		SDKHook(iUserid, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		CreateTimer(2.0, TyTimerConnected, iUserid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

void Ability_Use(Event event, const char[] event_name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsTank(client))
	{
		fg_xyz[client][4] = GetGameTime() + 3.0;
	}
}

void GetNearestClientPosition(int tank, float position[3])
{
	float dist, min_dist = 999.0, pos[2][3];
	
	GetClientAbsOrigin(tank, pos[0]);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(GetClientTeam(i) == 2)
			{
				GetClientAbsOrigin(i, pos[1]);
				
				dist = GetVectorDistance(pos[0], pos[1]);
				if (dist < min_dist)
				{
					min_dist = dist;
					position = pos[1];
				}
			}
		}
	}
}

bool IsTank(int client)
{
	static int iZC_offs = -1;
	if (iZC_offs == -1)
	{
		iZC_offs = FindSendPropInfo("CTerrorPlayer", "m_zombieClass");
	}
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		if (GetEntData(client, iZC_offs) == 8)
			return true;
	}
	return false;
}