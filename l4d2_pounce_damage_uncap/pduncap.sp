#include <sourcemod>
#include <sdkhooks>

#pragma newdecls required
#pragma semicolon 1

ConVar g_hMinRange;
ConVar g_hMaxRange;
ConVar g_hPounceDamage;

float g_flPounceStart[MAXPLAYERS + 1][3];
bool g_bPounceActive[MAXPLAYERS + 1];
bool g_bPouncePZMsg[MAXPLAYERS + 1];
int g_iPounceDamage[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Pounce Damage Uncap",
	author = "Accelerator",
	description = "Patch L4D2 to allow uncapping the pounce range limits",
	version = "2.1",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	g_hMinRange = CreateConVar("z_pounce_damage_range_min", "300.0", "Minimum range for a pounce to be worth bonus damage.", FCVAR_GAMEDLL|FCVAR_CHEAT, true, 0.0);
	g_hMaxRange = CreateConVar("z_pounce_damage_range_max", "1000.0", "Range at which a pounce is worth the maximum bonus damage.", FCVAR_GAMEDLL|FCVAR_CHEAT, true, 0.0);
	g_hPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");

	HookUserMessage(GetUserMessageId("PZDmgMsg"), OnPZDmgMsg, true);

	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("lunge_pounce", Event_LungePounce, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_bPounceActive[client] = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		OnClientDisconnect(i);
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	if (GetClientTeam(client) != 3)
		return;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return;

	char ability[16];
	event.GetString("ability", ability, sizeof(ability));

	if (StrEqual(ability, "ability_lunge", false))
	{
		GetClientAbsOrigin(client, g_flPounceStart[client]);

		g_bPounceActive[client] = true;
		g_bPouncePZMsg[client] = false;
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	g_bPounceActive[client] = false;
}

void Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client)
		return;

	event.SetInt("damage", g_iPounceDamage[client]);
	g_iPounceDamage[client] = 0;
}

void SendPounceMsg(int attacker, int victim, int damage)
{
	Handle msg = StartMessageAll("PZDmgMsg", USERMSG_RELIABLE);
	if (msg == null)
		return;

	BfWrite bf = UserMessageToBfWrite(msg);

	bf.WriteByte(12);
	bf.WriteShort(GetClientUserId(attacker));
	bf.WriteShort(GetClientUserId(victim));
	bf.WriteShort(0);
	bf.WriteShort(damage);

	EndMessage();
}

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (attacker < 1 || attacker > MaxClients)
		return Plugin_Continue;

	if (damagetype != DMG_CRUSH)
		return Plugin_Continue;

	if (!g_bPounceActive[attacker])
		return Plugin_Continue;

	g_bPounceActive[attacker] = false;

	if (GetClientTeam(victim) != 2 || GetClientTeam(attacker) != 3)
		return Plugin_Continue;

	if (GetEntProp(attacker, Prop_Send, "m_zombieClass") != 3)
		return Plugin_Continue;

	float currentPos[3];
	GetClientAbsOrigin(attacker, currentPos);

	float dist = GetVectorDistance(g_flPounceStart[attacker], currentPos);

	float minRange = g_hMinRange.FloatValue;
	float finalDamage = 1.0;

	if (dist > minRange)
	{
		float maxRange = g_hMaxRange.FloatValue;
		float maxBonus = g_hPounceDamage.FloatValue;

		if (dist >= maxRange)
		{
			finalDamage = 1.0 + maxBonus;
		}
		else
		{
			float fraction = (dist - minRange) / (maxRange - minRange);
			finalDamage = 1.0 + (maxBonus * fraction);
		}
	}

	damage = finalDamage;
	g_iPounceDamage[attacker] = RoundToNearest(finalDamage);

	if (finalDamage > 1.0)
	{
		g_bPouncePZMsg[attacker] = true;
		SendPounceMsg(attacker, victim, g_iPounceDamage[attacker]);
		g_bPouncePZMsg[attacker] = false;
	}

	return Plugin_Changed;
}

Action OnPZDmgMsg(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
	int iMsgType = bf.ReadByte();
	if (iMsgType != 12)
		return Plugin_Continue;

	int attacker = GetClientOfUserId(BfReadShort(bf));
	if (g_bPouncePZMsg[attacker])
		return Plugin_Continue;

	return Plugin_Handled;
}