#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

Handle hTimerKill[33];

public Plugin myinfo =
{
	name = "L4D2 SI Ability Dies",
	author = "Accelerator",
	description = "Spitter and Charger Dies After Ability use",
	version = "1.2",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", EventPlayerSpawn);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("player_death", EventPlayerDeath);
	HookEvent("player_team", EventPlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnClientDisconnect(int client)
{
	delete hTimerKill[client];
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
		delete hTimerKill[i];
}

void EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	delete hTimerKill[client];

	if (IsSpitterOrCharger(client))
	{
		hTimerKill[client] = CreateTimer(22.0, Timer_Autokill, client);
	}
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsSpitterOrCharger(client))
	{
		delete hTimerKill[client];
		hTimerKill[client] = CreateTimer(10.0, Timer_Autokill, client);
	}
}

void EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	delete hTimerKill[GetClientOfUserId(event.GetInt("userid"))];
}

Action Timer_Autokill(Handle timer, int client)
{
	hTimerKill[client] = null;

	if (!IsClientInGame(client))
		return Plugin_Stop;

	if (!IsPlayerAlive(client))
		return Plugin_Stop;

	if (IsSpitterOrCharger(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_carryVictim") > 0 || GetEntPropEnt(client, Prop_Send, "m_pummelVictim") > 0)
		{
			hTimerKill[client] = CreateTimer(10.0, Timer_Autokill, client);
			return Plugin_Stop;
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			{
				if (ClientViews(client, i))
				{
					hTimerKill[client] = CreateTimer(5.0, Timer_Autokill, client);
					return Plugin_Stop;
				}
			}
		}

		ForcePlayerSuicide(client);
		PrintHintText(client, "Don't hold Special Infected!");
	}

	return Plugin_Stop;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

bool IsSpitterOrCharger(int client)
{
	return (client && !IsFakeClient(client) && (GetClientTeam(client) == 3) && ((GetEntProp(client, Prop_Send, "m_zombieClass") == 4) || (GetEntProp(client, Prop_Send, "m_zombieClass") == 6)) && !GetEntProp(client, Prop_Send, "m_isGhost", 1));
}

 // https://github.com/shanapu/MyJailbreak/blob/dev/addons/sourcemod/scripting/include/mystocks.inc
bool ClientViews(int viewer, int target, float fMaxDistance=0.0, float fThreshold=0.73)
{
	float fViewPos[3], fViewAng[3], fTargetPos[3], fViewDir[3], fDistance[3], fTargetDir[3];
	GetClientEyePosition(viewer, fViewPos);
	GetClientEyeAngles(viewer, fViewAng);
	GetClientEyePosition(target, fTargetPos);

	fViewAng[0] = fViewAng[2] = 0.0;
	GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);

	fDistance[0] = fTargetPos[0]-fViewPos[0];
	fDistance[1] = fTargetPos[1]-fViewPos[1];
	fDistance[2] = 0.0;

	if (fMaxDistance != 0.0)
	{
		if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
			return false;
	}

	NormalizeVector(fDistance, fTargetDir);
	if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold)
		return false;

	Handle hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
	if (TR_DidHit(hTrace))
	{
		delete hTrace;
		return false;
	}

	delete hTrace;
	return true;
}

bool ClientViewsFilter(int entity, int mask, any junk)
{
	if (entity > 0 && entity <= MaxClients) 
		return false;

	return true;
}