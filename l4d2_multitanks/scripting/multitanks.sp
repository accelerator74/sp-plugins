#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

Handle sdkReplaceBot;
Handle hStateTransition;

ConVar mt_enable;

ConVar mt_count_firstmap;
ConVar mt_count_regular;
ConVar mt_count_finale;
ConVar mt_count_1stwave;
ConVar mt_count_2ndwave;
ConVar mt_count_escape;

ConVar mt_health_firstmap;
ConVar mt_health_regular;
ConVar mt_health_finale;
ConVar mt_health_1stwave;
ConVar mt_health_2ndwave;
ConVar mt_health_escape;

ConVar z_tank_health;

int iTankCount;
int iTanksCount;
int iFinaleWave;

int iFrustration[MAXPLAYERS+1];
int iTankTicketsOffset = -1;

float TankSpawnPosition[3];

public Plugin myinfo =
{
	name = "[L4D] Multitanks",
	author = "Accelerator",
	description = "Additional tanks on tank spawn event",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	mt_enable = CreateConVar("mt_enable", "1", "Enabled MultiTanks?");
	
	mt_count_firstmap = CreateConVar("mt_count_firstmap", "2", "Count of total tanks on first maps");
	mt_count_regular = CreateConVar("mt_count_regular", "2", "Count of total tanks on regular maps");
	mt_count_finale = CreateConVar("mt_count_finale", "1", "Count of total tanks on final maps");
	mt_count_1stwave = CreateConVar("mt_count_1stwave", "1", "Count of total tanks when final start");
	mt_count_2ndwave = CreateConVar("mt_count_2ndwave", "1", "Count of total tanks in second wave after final start");
	mt_count_escape = CreateConVar("mt_count_escape", "1", "Count of total tanks when escape start");

	mt_health_firstmap = CreateConVar("mt_health_firstmap", "16000", "Tanks health on first maps");
	mt_health_regular = CreateConVar("mt_health_regular", "9000", "Tanks health on regular maps");
	mt_health_finale = CreateConVar("mt_health_finale", "16000", "Tanks health on final maps");
	mt_health_1stwave = CreateConVar("mt_health_1stwave", "16000", "Tanks health when final start");
	mt_health_2ndwave = CreateConVar("mt_health_2ndwave", "16000", "Tanks health in second wave after final start");
	mt_health_escape = CreateConVar("mt_health_escape", "16000", "Tanks health when escape start");
	
	AutoExecConfig(true, "multitanks");
	
	z_tank_health = FindConVar("z_tank_health");
	
	HookEvent("player_left_start_area", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("finale_start", OnFinaleStart, EventHookMode_PostNoCopy);
	HookEvent("finale_escape_start", OnFinaleEscapeStart, EventHookMode_PostNoCopy);
	
	GameData g_hGameConf = new GameData("multitanks");
	if(g_hGameConf == null)
	{
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "ReplaceWithBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	sdkReplaceBot = EndPrepSDKCall();
	if(sdkReplaceBot == null)
	{
		SetFailState("Unable to find the 'ReplaceWithBot' signature, check the file version!");
	}
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "State_Transition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
	hStateTransition = EndPrepSDKCall();
	if(hStateTransition == null)
	{
		SetFailState("Unable to find the 'State_Transition' signature, check the file version!");
	}
	iTankTicketsOffset = g_hGameConf.GetOffset("CTerrorPlayer::m_iTankTickets");
	if(iTankTicketsOffset == -1)
	{
		LogError("Failed to get CTerrorPlayer::m_iTankTickets");
	}
	delete g_hGameConf;
}

public void Event_RoundStart(Event hEvent, const char[] strName, bool DontBroadcast)
{
	if (!mt_enable.BoolValue)
		return;
	
	if (IsFirstMap())
	{
		iTanksCount = mt_count_firstmap.IntValue;
		z_tank_health.SetFloat(mt_health_firstmap.FloatValue, false, false);
	}
	else if (IsFinale())
	{
		iTanksCount = mt_count_finale.IntValue;
		z_tank_health.SetFloat(mt_health_finale.FloatValue, false, false);
	}
	else
	{
		iTanksCount = mt_count_regular.IntValue;
		z_tank_health.SetFloat(mt_health_regular.FloatValue, false, false);
	}
	
	iTankCount = 0;
	iFinaleWave = 0;
	
	ClearTankSpawnPosition();
}

public void OnFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!mt_enable.BoolValue)
		return;
	
	iTanksCount = mt_count_1stwave.IntValue;
	z_tank_health.SetFloat(mt_health_1stwave.FloatValue, false, false);
	iFinaleWave = 1;
	iTankCount = 0;
	
	ClearTankSpawnPosition();
}

void ClearTankSpawnPosition()
{
	TankSpawnPosition[0] = 0.0;
	TankSpawnPosition[1] = 0.0;
	TankSpawnPosition[2] = 0.0;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!mt_enable.BoolValue)
		return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	int tankHealth = IsFakeClient(client) ? 0 : RoundToNearest(z_tank_health.FloatValue * 1.5);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (tankHealth != 0)
			{
				if (GetClientTeam(i) == 3)
				{
					PrintToChat(i, "\x04%N\x05 took control of the Tank [\x03%i HP\x05]", client, tankHealth);
				}
				else
				{
					PrintToChat(i, "\x05New Tank Spawning [\x03%i HP\x05]", tankHealth);
				}
			}
		}
	}
	
	iTankCount++;
	iFrustration[client] = 0;
	
	if (iTankCount < iTanksCount)
	{
		CreateTimer(5.0, SpawnMoreTank);
	}
	else if (iTankCount > iTanksCount)
	{
		if (iFinaleWave == 1)
		{
			iTanksCount = mt_count_2ndwave.IntValue;
			z_tank_health.SetFloat(mt_health_2ndwave.FloatValue, false, false);
			iFinaleWave = 2;
			iTankCount = 0;
			
			ClearTankSpawnPosition();
		}
	}
	
	if (!IsFakeClient(client))
	{
		CreateTimer(0.1, CheckTankSpawnPosition, client, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(10.0, CheckFrustration, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnFinaleEscapeStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!mt_enable.BoolValue)
		return;
	
	iTanksCount = mt_count_escape.IntValue;
	z_tank_health.SetFloat(mt_health_escape.FloatValue, false, false);
	iTankCount = 0;
	
	ClearTankSpawnPosition();
}

public Action CheckFrustration(Handle timer, any client)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || (GetClientTeam(client) != 3) || (GetEntProp(client, Prop_Send, "m_zombieClass") != 8) || GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return Plugin_Stop;
	
	int iFrustrationProgress = GetEntProp(client, Prop_Send, "m_frustration");
	if (iFrustrationProgress >= 95)
	{
		if (!(GetEntityFlags(client) & FL_ONFIRE))
		{
			iFrustration[client]++;
			if (iFrustration[client] < 2)
			{
				PrintToChatTeam(3, "\x04%N\x05 lost first Tank control", client);
				SetEntProp(client, Prop_Send, "m_frustration", 0);
				CreateTimer(0.1, CheckFrustration, client);
			}
			else
			{
				PrintToChatTeam(3, "\x04%N\x05 lost control of the Tank", client);
				SDKCall(sdkReplaceBot, client, true);
				ForcePlayerSuicide(client);
				int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
				if (ragdoll > 0)
				{
					AcceptEntityInput(ragdoll, "Kill");
				}
				SetEntProp(client, Prop_Send, "m_zombieClass", 3);
				SDKCall(hStateTransition, client, 8);
			}
		}
		else
		{
			CreateTimer(0.1, CheckFrustration, client);
		}
	}
	else
	{
		CreateTimer(0.1 + (95 - iFrustrationProgress) * 0.1, CheckFrustration, client);
	}
	return Plugin_Stop;
}

public Action SpawnMoreTank(Handle timer)
{
	int newtank = GetTankTicketsLeader();
	if (newtank)
	{
		if (SpawnNewTank(newtank))
			return Plugin_Stop;
	}
	
	int client = GetAnyClient();
	
	if (client)
	{
		CheatCommand(client, "z_spawn_old", "tank auto");
	}
	
	return Plugin_Stop;
}

public Action CheckTankSpawnPosition(Handle timer, any client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
	{
		if (TankSpawnPosition[0] == 0.0 && TankSpawnPosition[1] == 0.0 && TankSpawnPosition[2] == 0.0)
		{
			GetClientAbsOrigin(client, TankSpawnPosition);
		}
		else
		{
			TeleportEntity(client, TankSpawnPosition, NULL_VECTOR, NULL_VECTOR);
		}
	}
	return Plugin_Stop;
}

stock bool SpawnNewTank(int client)
{
	bool resetGhostState[MAXPLAYERS+1];
	bool resetIsAlive[MAXPLAYERS+1];
	bool resetLifeState[MAXPLAYERS+1];
	
	for (int i = 1; i <= MaxClients; i++)
	{ 
		if (i == client) continue;
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i) != 3) continue;
		if (IsFakeClient(i)) continue;
		
		if (IsGhost(i))
		{
			resetGhostState[i] = true;
			SetPlayerGhostStatus(i, false);
			resetIsAlive[i] = true; 
			SetPlayerIsAlive(i, true);
		}
		else if (!IsPlayerAlive(i))
		{
			resetLifeState[i] = true;
			SetPlayerLifeState(i, false);
		}
	}
	
	CheatCommand(client, "z_spawn", "tank");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (resetGhostState[i]) SetPlayerGhostStatus(i, true);
		if (resetIsAlive[i]) SetPlayerIsAlive(i, false);
		if (resetLifeState[i]) SetPlayerLifeState(i, true);
	}
	
	return IsPlayerAlive(client);
}

stock int GetTankTicketsLeader()
{
	if (iTankTicketsOffset == -1)
		return 0;
	
	Address aEntity = Address_Null;
	int score, maxscore, client;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if ((GetClientTeam(i) == 3) && (GetEntProp(i, Prop_Send, "m_zombieClass") != 8))
			{
				aEntity = GetEntityAddress(i);
				if (aEntity == Address_Null) continue;
				
				score = LoadFromAddress(aEntity + view_as<Address>(iTankTicketsOffset), NumberType_Int32);
				
				if ((score > 0) && (maxscore < score))
				{
					maxscore = score;
					client = i;
				}
			}
		}
	}
	return client;
}

stock int GetAnyClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			return i;
		}
	}
	return 0;
}

stock void SetPlayerGhostStatus(int client, bool ghost)
{
	int offset = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
	if (ghost) SetEntData(client, offset, 1, 1);
	else SetEntData(client, offset, 0, 1);
}

stock void SetPlayerLifeState(int client, bool ready)
{
	int offset = FindSendPropInfo("CTerrorPlayer", "m_lifeState");
	if (ready) SetEntData(client, offset, 1, 1);
	else SetEntData(client, offset, 0, 1);
}

stock void SetPlayerIsAlive(int client, bool alive)
{
	int offset = FindSendPropInfo("CTransitioningPlayer", "m_isAlive");
	if (alive) SetEntData(client, offset, 1, 1, true);
	else SetEntData(client, offset, 0, 1, true);
}

stock void CheatCommand(int client, char[] command, char[] arguments = "")
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
}

stock void PrintToChatTeam(const int team, const char[] format, any ...)
{
	char buffer[192];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 3);
			PrintToChat(i, "%s", buffer);
		}
	}
}

bool IsFirstMap()
{
	char current_map[55];
	GetCurrentMap(current_map, sizeof(current_map));
	
	if (CharToLower(current_map[0]) == 'c' && StrContains(current_map, "m1_") != -1)
		return true;
	return false;
}

bool IsFinale()
{
	return (FindEntityByClassname(-1, "info_changelevel") == -1
				&& FindEntityByClassname(-1, "trigger_changelevel") == -1);
}

bool IsGhost(int client)
{
	int m_isGhost = GetEntProp(client, Prop_Send, "m_isGhost");

	if (m_isGhost > 0)
		return true;

	return false;
}