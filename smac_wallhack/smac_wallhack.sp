/*
	SourceMod Anti-Cheat
	Copyright (C) 2011-2016 SMAC Development Team
	Copyright (C) 2007-2011 CodingDirect LLC

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

/* Globals */
#define SMAC_VERSION				"0.8.7.3"
#define SMAC_URL					"https://github.com/accelerator74/sp-plugins"
#define SMAC_AUTHOR					"SMAC Development Team & Accelerator"
#define MAX_EDICTS					2049
#define SOUNDS_CHECK
#define ESP_BLOCKING

// Macros
#define IS_CLIENT(%1)				(1 <= %1 <= MaxClients)
#define TIME_TO_TICK(%1)			(RoundToNearest((%1) / GetTickInterval()))
#define TICK_TO_TIME(%1)			((%1) * GetTickInterval())

// Hud Element hiding flags
#define HIDEHUD_WEAPONSELECTION		(1 << 0)	// Hide ammo count & weapon selection
#define HIDEHUD_FLASHLIGHT			(1 << 1)
#define HIDEHUD_ALL					(1 << 2)
#define HIDEHUD_HEALTH				(1 << 3)	// Hide health & armor / suit battery
#define HIDEHUD_PLAYERDEAD			(1 << 4)	// Hide when local player's dead
#define HIDEHUD_NEEDSUIT			(1 << 5)	// Hide when the local player doesn't have the HEV suit
#define HIDEHUD_MISCSTATUS			(1 << 6)	// Hide miscellaneous status elements (trains, pickup history, death notices, etc)
#define HIDEHUD_CHAT				(1 << 7)	// Hide all communication elements (saytext, voice icon, etc)
#define HIDEHUD_CROSSHAIR			(1 << 8)	// Hide crosshairs
#define HIDEHUD_VEHICLE_CROSSHAIR	(1 << 9)	// Hide vehicle crosshair
#define HIDEHUD_INVEHICLE			(1 << 10)
#define HIDEHUD_BONUS_PROGRESS		(1 << 11)	// Hide bonus progress display (for bonus map challenges)
#define HIDEHUD_BITCOUNT			12

// Spectator movement modes
enum {
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_ROAMING,	// free roaming
};

EngineVersion g_Game = Engine_Unknown;

#if defined ESP_BLOCKING
bool g_bEnabled, g_bFarEspEnabled;
#else
bool g_bEnabled;
#endif
int g_iMaxTraces;
float g_fMaxUnlag;

#if defined SOUNDS_CHECK
int m_vecAbsOrigin;
int g_iDownloadTable = INVALID_STRING_TABLE;
ArrayList g_hIgnoreSounds;
#endif

int g_iPVSCache[MAXPLAYERS+1][MAXPLAYERS+1];
#if defined SOUNDS_CHECK
int g_iPVSSoundCache[MAXPLAYERS+1][MAXPLAYERS+1];
#endif
bool g_bIsVisible[MAXPLAYERS+1][MAXPLAYERS+1];
bool g_bIsObserver[MAXPLAYERS+1];
bool g_bIsFake[MAXPLAYERS+1];
bool g_bProcess[MAXPLAYERS+1];
bool g_bIgnore[MAXPLAYERS+1];
bool g_bForceIgnore[MAXPLAYERS+1];

int g_iWeaponOwner[MAX_EDICTS];
int g_iTeam[MAXPLAYERS+1];
float g_vMins[MAXPLAYERS+1][3];
float g_vMaxs[MAXPLAYERS+1][3];
float g_vAbsCentre[MAXPLAYERS+1][3];
float g_vEyePos[MAXPLAYERS+1][3];
float g_vEyeAngles[MAXPLAYERS+1][3];
float g_fAbilityStart[MAXPLAYERS+1];

int g_iTotalThreads = 1, g_iCurrentThread = 1, g_iThread[MAXPLAYERS+1] = { 1, ... };
int g_iCacheTicks, g_iTraceCount;
int g_iTickCount, g_iCmdTickCount[MAXPLAYERS+1], g_iTickRate;

/* Offsets */
int m_fLerpTime = -1;
int m_iHideHUD = -1;
int m_hOwnerEntity = -1;
int m_isGhost = -1;
int m_iGlowType = -1;
int m_isIncapacitated = -1;
int m_vomitStart = -1;
int m_knockdownReason = -1;
int m_staggerDist = -1;
int m_pounceAttacker = -1;
int m_tongueOwner = -1;
int m_pounceVictim = -1;
int m_tongueVictim = -1;
int m_pummelAttacker = -1;
int m_carryAttacker = -1;
int m_jockeyAttacker = -1;
int m_pummelVictim = -1;
int m_carryVictim = -1;
int m_jockeyVictim = -1;

/* ConVars */
ConVar hVomitDurationInfectedBot, hVomitDurationInfectedPz;
float g_iVomitDurationBot, g_iVomitDurationPz;

/* Plugin Info */
public Plugin myinfo =
{
	name = "SMAC Anti-Wallhack",
	author = SMAC_AUTHOR,
	description = "Prevents wallhack cheats from working",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_Game = GetEngineVersion();
	if (g_Game == Engine_CSGO)
	{
		strcopy(error, err_max, "This module is disabled for this game. Enable \"sv_occlude_players\" for the same feature.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Initialize.
#if defined SOUNDS_CHECK
	g_iDownloadTable = FindStringTable("downloadables");
#endif
	g_iCacheTicks = TIME_TO_TICK(0.75);

	for (int i = 0; i < sizeof(g_bIsVisible); i++)
	{
		for (int j = 0; j < sizeof(g_bIsVisible[]); j++)
		{
			g_bIsVisible[i][j] = true;
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			m_fLerpTime = FindDataMapInfo(i, "m_fLerpTime");
			break;
		}
	}
	m_iHideHUD = FindSendPropInfo("CBasePlayer", "m_iHideHUD");
	m_hOwnerEntity = FindSendPropInfo("CBaseEntity", "m_hOwnerEntity");
#if defined SOUNDS_CHECK
	// Default sounds to ignore in sound hook.
	g_hIgnoreSounds = new ArrayList(ByteCountToCells(256));
	g_hIgnoreSounds.PushString("buttons/button14.wav");
	g_hIgnoreSounds.PushString("buttons/combine_button7.wav");
#endif
	switch (g_Game)
	{
		case Engine_Left4Dead:
		{
			m_isGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
			m_isIncapacitated = FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated");
			m_vomitStart = FindSendPropInfo("CTerrorPlayer", "m_vomitStart");
			m_knockdownReason = FindSendPropInfo("CTerrorPlayer", "m_knockdownReason");
			m_staggerDist = FindSendPropInfo("CTerrorPlayer", "m_staggerDist");
			m_pounceAttacker = FindSendPropInfo("CTerrorPlayer", "m_pounceAttacker");
			m_tongueOwner = FindSendPropInfo("CTerrorPlayer", "m_tongueOwner");
			m_pounceVictim = FindSendPropInfo("CTerrorPlayer", "m_pounceVictim");
			m_tongueVictim = FindSendPropInfo("CTerrorPlayer", "m_tongueVictim");

			g_iVomitDurationBot = g_iVomitDurationPz = 20.0;
#if defined SOUNDS_CHECK
			g_hIgnoreSounds.PushString("UI/Pickup_GuitarRiff10.wav");
#endif
		}
		case Engine_Left4Dead2:
		{
			m_isGhost = FindSendPropInfo("CTerrorPlayer", "m_isGhost");
			m_iGlowType = FindSendPropInfo("CTerrorPlayer", "m_iGlowType");
			m_isIncapacitated = FindSendPropInfo("CTerrorPlayer", "m_isIncapacitated");
			m_vomitStart = FindSendPropInfo("CTerrorPlayer", "m_vomitStart");
			m_knockdownReason = FindSendPropInfo("CTerrorPlayer", "m_knockdownReason");
			m_staggerDist = FindSendPropInfo("CTerrorPlayer", "m_staggerDist");
			m_pounceAttacker = FindSendPropInfo("CTerrorPlayer", "m_pounceAttacker");
			m_tongueOwner = FindSendPropInfo("CTerrorPlayer", "m_tongueOwner");
			m_pounceVictim = FindSendPropInfo("CTerrorPlayer", "m_pounceVictim");
			m_tongueVictim = FindSendPropInfo("CTerrorPlayer", "m_tongueVictim");
			m_pummelAttacker = FindSendPropInfo("CTerrorPlayer", "m_pummelAttacker");
			m_carryAttacker = FindSendPropInfo("CTerrorPlayer", "m_carryAttacker");
			m_jockeyAttacker = FindSendPropInfo("CTerrorPlayer", "m_jockeyAttacker");
			m_pummelVictim = FindSendPropInfo("CTerrorPlayer", "m_pummelVictim");
			m_carryVictim = FindSendPropInfo("CTerrorPlayer", "m_carryVictim");
			m_jockeyVictim = FindSendPropInfo("CTerrorPlayer", "m_jockeyVictim");

			hVomitDurationInfectedBot = FindConVar("vomitjar_duration_infected_bot");
			hVomitDurationInfectedBot.AddChangeHook(OnVomitChanged);
			hVomitDurationInfectedPz = FindConVar("vomitjar_duration_infected_pz");
			hVomitDurationInfectedPz.AddChangeHook(OnVomitChanged);
			OnVomitChanged(null, "", "");
#if defined SOUNDS_CHECK
			g_hIgnoreSounds.PushString("UI/Pickup_GuitarRiff10.wav");
#endif
		}
	}

	// Convars.
	ConVar hCvar = null;

	hCvar = CreateConVar("smac_wallhack", "1", "Enable Anti-Wallhack. This will increase your server's CPU usage.", 0, true, 0.0, true, 1.0);
	OnSettingsChanged(hCvar, "", "");
	hCvar.AddChangeHook(OnSettingsChanged);

	hCvar = CreateConVar("smac_wallhack_maxtraces", "1280", "Max amount of traces that can be executed in one tick.", 0, true, 1.0);
	OnMaxTracesChanged(hCvar, "", "");
	hCvar.AddChangeHook(OnMaxTracesChanged);

	hCvar = FindConVar("sv_maxunlag");
	OnMaxUnlagChanged(hCvar, "", "");
	hCvar.AddChangeHook(OnMaxUnlagChanged);

	// Clients use these for prediction. Only change cvars if they aren't in the server's config.
	g_iTickRate = RoundToFloor(1.0 / GetTickInterval());

	if ((hCvar = FindConVar("sv_minupdaterate")) != INVALID_HANDLE && IsConVarDefault(hCvar))
	{
		SetConVarInt(hCvar, g_iTickRate);
	}
	if ((hCvar = FindConVar("sv_maxupdaterate")) != INVALID_HANDLE && IsConVarDefault(hCvar))
	{
		SetConVarInt(hCvar, g_iTickRate);
	}
	if ((hCvar = FindConVar("sv_client_min_interp_ratio")) != INVALID_HANDLE && IsConVarDefault(hCvar))
	{
		SetConVarInt(hCvar, 0);
	}
	if ((hCvar = FindConVar("sv_client_max_interp_ratio")) != INVALID_HANDLE && IsConVarDefault(hCvar))
	{
		SetConVarInt(hCvar, 1);
	}
}

public void OnMapStart()
{
#if defined SOUNDS_CHECK
	m_vecAbsOrigin = FindDataMapInfo(0, "m_vecAbsOrigin");
#endif
#if defined ESP_BLOCKING
	if (g_bEnabled && !g_bFarEspEnabled && g_Game == Engine_CSS)
	{
		FarESP_Enable();
	}
#endif
}
#if defined SOUNDS_CHECK
public void OnConfigsExecuted()
{
	// Ignore all sounds in the download table.
	if (g_iDownloadTable == INVALID_STRING_TABLE)
	{
		return;
	}

	char sBuffer[PLATFORM_MAX_PATH];
	int iMaxStrings = GetStringTableNumStrings(g_iDownloadTable);

	for (int i = 0; i < iMaxStrings; i++)
	{
		ReadStringTable(g_iDownloadTable, i, sBuffer, sizeof(sBuffer));

		if (strncmp(sBuffer, "sound", 5) == 0)
		{
			g_hIgnoreSounds.PushString(sBuffer[6]);
		}
	}
}
#endif
public void OnClientPutInServer(int client)
{
	if (m_fLerpTime == -1)
	{
		m_fLerpTime = FindDataMapInfo(client, "m_fLerpTime");
	}
	if (g_bEnabled)
	{
		Wallhack_Hook(client);
		Wallhack_UpdateClientCache(client);
	}
}

public void OnClientDisconnect(int client)
{
	// Stop checking clients right before they disconnect.
	g_bIsObserver[client] = false;
	g_bProcess[client] = false;
	g_bIgnore[client] = false;
	g_bForceIgnore[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	// Clear cache on post to ensure it's not updated again.
	for (int i = 0; i < sizeof(g_iPVSCache); i++)
	{
		g_iPVSCache[i][client] = 0;
#if defined SOUNDS_CHECK
		g_iPVSSoundCache[i][client] = 0;
#endif
		g_bIsVisible[i][client] = true;
	}
}

void Event_PlayerStateChanged(Event event, const char[] name, bool dontBroadcast)
{
	// Not all data has been updated at this time. Wait until the next tick to update cache.
	CreateTimer(0.001, Timer_PlayerStateChanged, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_PlayerStateChanged(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (IS_CLIENT(client) && IsClientInGame(client))
	{
		Wallhack_UpdateClientCache(client);
	}

	return Plugin_Stop;
}

void Wallhack_UpdateClientCache(int client)
{
	g_iTeam[client] = GetClientTeam(client);
	g_bIsObserver[client] = IsClientObserver(client);
	g_bIsFake[client] = IsFakeClient(client);
	g_bProcess[client] = IsPlayerAlive(client);

	// Clients that should not be tested for visibility.
	g_bIgnore[client] = g_bForceIgnore[client] || g_bIsFake[client] || ((g_Game == Engine_Left4Dead || g_Game == Engine_Left4Dead2) && g_iTeam[client] != 2);
}

void OnSettingsChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	bool bNewValue = convar.BoolValue;

	if (bNewValue && !g_bEnabled)
	{
		Wallhack_Enable();
	}
	else if (!bNewValue && g_bEnabled)
	{
		Wallhack_Disable();
	}
}

void OnMaxTracesChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_iMaxTraces = convar.IntValue;
}

void OnMaxUnlagChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_fMaxUnlag = convar.FloatValue;
}

void OnVomitChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_iVomitDurationBot = hVomitDurationInfectedBot.FloatValue;
	g_iVomitDurationPz = hVomitDurationInfectedPz.FloatValue;
}

void Wallhack_Enable()
{
	g_bEnabled = true;
#if defined SOUNDS_CHECK
	AddNormalSoundHook(Hook_NormalSound);
#endif
	HookEvent("player_spawn", Event_PlayerStateChanged, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerStateChanged, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerStateChanged, EventHookMode_Post);

	switch (g_Game)
	{
		case Engine_TF2:
		{
			HookEntityOutput("item_teamflag", "OnPickUp", TF2_Hook_FlagEquip);
			HookEntityOutput("item_teamflag", "OnDrop", TF2_Hook_FlagDrop);
			HookEntityOutput("item_teamflag", "OnReturn", TF2_Hook_FlagDrop);
			HookEvent("post_inventory_application", TF2_Event_Inventory, EventHookMode_Post);
		}
#if defined ESP_BLOCKING
		case Engine_CSS:
		{
			FarESP_Enable();
		}
#endif
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			HookEvent("player_first_spawn", Event_PlayerStateChanged, EventHookMode_Post);
			HookEvent("ghost_spawn_time", L4D_Event_GhostSpawnTime, EventHookMode_Post);
			HookEvent("ability_use", L4D_Event_AbilityUse, EventHookMode_Post);
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			Wallhack_Hook(i);
			Wallhack_UpdateClientCache(i);
		}
	}

	for (int i = MaxClients + 1; i < MAX_EDICTS; i++)
	{
		if (IsValidEdict(i))
		{
			int owner = GetEntDataEnt2(i, m_hOwnerEntity);

			if (IS_CLIENT(owner))
			{
				g_iWeaponOwner[i] = owner;
				SDKHook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
			}
		}
	}
}

void Wallhack_Disable()
{
	g_bEnabled = false;
#if defined SOUNDS_CHECK
	RemoveNormalSoundHook(Hook_NormalSound);
#endif
	UnhookEvent("player_spawn", Event_PlayerStateChanged, EventHookMode_Post);
	UnhookEvent("player_death", Event_PlayerStateChanged, EventHookMode_Post);
	UnhookEvent("player_team", Event_PlayerStateChanged, EventHookMode_Post);

	switch (g_Game)
	{
		case Engine_TF2:
		{
			UnhookEntityOutput("item_teamflag", "OnPickUp", TF2_Hook_FlagEquip);
			UnhookEntityOutput("item_teamflag", "OnDrop", TF2_Hook_FlagDrop);
			UnhookEntityOutput("item_teamflag", "OnReturn", TF2_Hook_FlagDrop);
			UnhookEvent("post_inventory_application", TF2_Event_Inventory, EventHookMode_Post);
		}
#if defined ESP_BLOCKING
		case Engine_CSS:
		{
			FarESP_Disable();
		}
#endif
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			UnhookEvent("player_first_spawn", Event_PlayerStateChanged, EventHookMode_Post);
			UnhookEvent("ghost_spawn_time", L4D_Event_GhostSpawnTime, EventHookMode_Post);
			UnhookEvent("ability_use", L4D_Event_AbilityUse, EventHookMode_Post);
		}
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			Wallhack_Unhook(i);
		}
	}

	for (int i = MaxClients + 1; i < MAX_EDICTS; i++)
	{
		if (g_iWeaponOwner[i])
		{
			g_iWeaponOwner[i] = 0;
			SDKUnhook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
		}
	}
}

/**
 * Hooks
 */
void Wallhack_Hook(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	SDKHook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost);
}

void Wallhack_Unhook(int client)
{
	SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	SDKUnhook(client, SDKHook_WeaponEquipPost, Hook_WeaponEquipPost);
	SDKUnhook(client, SDKHook_WeaponDropPost, Hook_WeaponDropPost);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > MaxClients && entity < MAX_EDICTS)
	{
		g_iWeaponOwner[entity] = 0;
	}
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients && entity < MAX_EDICTS)
	{
		g_iWeaponOwner[entity] = 0;
	}
}

void Hook_WeaponEquipPost(int client, int weapon)
{
	if (weapon > MaxClients && weapon < MAX_EDICTS)
	{
		g_iWeaponOwner[weapon] = client;
		SDKHook(weapon, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
	}
}

void Hook_WeaponDropPost(int client, int weapon)
{
	if (weapon > MaxClients && weapon < MAX_EDICTS)
	{
		g_iWeaponOwner[weapon] = 0;
		SDKUnhook(weapon, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
	}
}
#if defined SOUNDS_CHECK
Action Hook_NormalSound(int clients[MAXPLAYERS], int& numClients, char sample[PLATFORM_MAX_PATH], 
							int& entity, int& channel, float& volume, int& level, int& pitch, int& flags, 
							char soundEntry[PLATFORM_MAX_PATH], int& seed)
{
	/* Emit sounds to clients who aren't being transmitted the entity. */
	if (!entity || !IsValidEdict(entity) || g_hIgnoreSounds.FindString(sample) != -1)
	{
		return Plugin_Continue;
	}

	int iOwner = (entity > MaxClients) ? g_iWeaponOwner[entity] : entity;

	if (!IS_CLIENT(iOwner))
	{
		return Plugin_Continue;
	}

	int[] newClients = new int[MaxClients];
	bool[] bAddClient = new bool[view_as<int>(MaxClients+1)];
	int newTotal;

	// Check clients that get the sound by default.
	for (int i = 0; i < numClients; i++)
	{
		int client = clients[i];

		// SourceMod and game engine don't always agree.
		if (!IsClientInGame(client))
		{
			continue;
		}

		// These clients need the entity information for prediction.
		if (g_bIsFake[client] || client == iOwner)
		{
			newClients[newTotal++] = client;
			continue;
		}

		// Body sounds (footsteps, jumping, etc) will be kept strict to the PVS because they're quiet anyway.
		// Weapons can be heard from larger distances.
		if (channel == SNDCHAN_BODY)
		{
			bAddClient[client] = g_bIsVisible[iOwner][client];
		}
		else
		{
			bAddClient[client] = true;
		}
	}

	// Emit with entity information.
	if (newTotal)
	{
		EmitSound(newClients, newTotal, sample, entity, channel, level, flags, volume, pitch);
		newTotal = 0;
	}

	// Determine which clients still need this sound.
	for (int i = 1; i <= MaxClients; i++)
	{
		// A client in the PVS will be expected to predict the sound even if we're blocking transmit.
		if (bAddClient[i] || ((g_bProcess[i] || g_bIsObserver[i]) && !g_bIsVisible[iOwner][i] && g_iPVSSoundCache[iOwner][i] > g_iTickCount))
		{
			newClients[newTotal++] = i;
		}
	}

	// Emit without entity information.
	if (newTotal)
	{
		float vOrigin[3];
		GetEntDataVector(entity, m_vecAbsOrigin, vOrigin);
		EmitSound(newClients, newTotal, sample, SOUND_FROM_WORLD, channel, level, flags, volume, pitch, _, vOrigin);
	}

	return Plugin_Stop;
}
#endif
void TF2_Hook_FlagEquip(const char[] output, int caller, int activator, float delay)
{
	if (caller > MaxClients && caller < MAX_EDICTS && IS_CLIENT(activator) && IsClientConnected(activator))
	{
		g_iWeaponOwner[caller] = activator;
		SDKHook(caller, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
	}
}

void TF2_Hook_FlagDrop(const char[] output, int caller, int activator, float delay)
{
	if (caller > MaxClients && caller < MAX_EDICTS)
	{
		g_iWeaponOwner[caller] = 0;
		SDKUnhook(caller, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
	}
}

void TF2_Event_Inventory(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IS_CLIENT(client))
	{
		for (int i = MaxClients + 1; i < MAX_EDICTS; i++)
		{
			if (IsValidEdict(i) && GetEntDataEnt2(i, m_hOwnerEntity) == client)
			{
				g_iWeaponOwner[i] = client;
				SDKHook(i, SDKHook_SetTransmit, Hook_SetTransmitWeapon);
			}
		}
	}
}

void L4D_Event_GhostSpawnTime(Event event, const char[] name, bool dontBroadcast)
{
	// There is no event for observer -> ghost mode, so we must count it down ourselves.
	CreateTimer(event.GetInt("spawntime") + 0.5, Timer_PlayerStateChanged, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void L4D_Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	g_fAbilityStart[GetClientOfUserId(event.GetInt("userid"))] = GetGameTime();
}

/**
 * OnGameFrame
 */
public void OnGameFrame()
{
	if (!g_bEnabled)
	{
		return;
	}

	g_iTickCount = GetGameTickCount();

	// Increment to next thread.
	if (++g_iCurrentThread > g_iTotalThreads)
	{
		g_iCurrentThread = 1;

		// Reassign threads
		if (g_iTraceCount)
		{
			// Calculate total needed threads for the next pass.
			g_iTotalThreads = g_iTraceCount / g_iMaxTraces + 1;

			// Assign each client to a thread.
			int iThreadAssign = 1;

			for (int i = 1; i <= MaxClients; i++)
			{
				if (g_bProcess[i])
				{
					g_iThread[i] = iThreadAssign;

					if (++iThreadAssign > g_iTotalThreads)
					{
						iThreadAssign = 1;
					}
				}
			}

			g_iTraceCount = 0;
		}
	}
#if defined ESP_BLOCKING
	if (g_bFarEspEnabled)
	{
		FarESP_OnGameFrame();
	}
#endif
}

Action Hook_SetTransmit(int entity,int client)
{
	static int iLastChecked[MAXPLAYERS+1][MAXPLAYERS+1];
#if defined SOUNDS_CHECK
	// Cache PVS for sound hook.
	g_iPVSSoundCache[entity][client] = g_iTickCount + g_iCacheTicks;
#endif
	// Data is transmitted multiple times per tick. Only run calculations once.
	if (iLastChecked[entity][client] == g_iTickCount)
	{
		return g_bIsVisible[entity][client] ? Plugin_Continue : Plugin_Handled;
	}

	iLastChecked[entity][client] = g_iTickCount;

	if (g_bProcess[client])
	{
		if (g_bProcess[entity] && g_iTeam[client] != g_iTeam[entity] && !g_bIgnore[client])
		{
			if (g_iThread[client] == g_iCurrentThread)
			{
				// Grab client data before running traces.
				UpdateClientData(client);
				UpdateClientData(entity);

				if (IsAbleToSee(entity, client))
				{
					g_bIsVisible[entity][client] = true;
					g_iPVSCache[entity][client] = g_iTickCount + g_iCacheTicks;
				}
				else if (g_iTickCount > g_iPVSCache[entity][client])
				{
					g_bIsVisible[entity][client] = false;
				}
			}
		}
		else
		{
			g_bIsVisible[entity][client] = true;
		}
	}
	else if (!g_bIsFake[client] && g_bProcess[entity] && GetClientObserverMode(client) == OBS_MODE_IN_EYE)
	{
		// Observers in first-person will clone the visiblity of their target.
		int iTarget = GetClientObserverTarget(client);

		if (IS_CLIENT(iTarget))
		{
			g_bIsVisible[entity][client] = g_bIsVisible[entity][iTarget];
		}
		else
		{
			g_bIsVisible[entity][client] = true;
		}
	}
	else
	{
		g_bIsVisible[entity][client] = true;
	}

	return g_bIsVisible[entity][client] ? Plugin_Continue : Plugin_Handled;
}

Action Hook_SetTransmitWeapon(int entity,int client)
{
	return g_bIsVisible[g_iWeaponOwner[entity]][client] ? Plugin_Continue : Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!g_bEnabled || !g_bProcess[client])
	{
		return Plugin_Continue;
	}

	g_vEyeAngles[client] = angles;
	g_iCmdTickCount[client] = tickcount;

	return Plugin_Continue;
}

void UpdateClientData(int client)
{
	/* Only update client data once per tick. */
	static int iLastCached[MAXPLAYERS+1];

	if (iLastCached[client] == g_iTickCount)
	{
		return;
	}

	iLastCached[client] = g_iTickCount;

	GetClientMins(client, g_vMins[client]);
	GetClientMaxs(client, g_vMaxs[client]);
	GetClientAbsOrigin(client, g_vAbsCentre[client]);
	GetClientEyePosition(client, g_vEyePos[client]);

	// Adjust vectors relative to the model's absolute centre.
	g_vMaxs[client][2] /= 2.0;
	g_vMins[client][2] -= g_vMaxs[client][2];
	g_vAbsCentre[client][2] += g_vMaxs[client][2];

	// Adjust vectors based on the clients velocity.
	float vVelocity[3];
	GetClientAbsVelocity(client, vVelocity);

	if (!IsVectorZero(vVelocity))
	{
		// Lag compensation.
		int iTargetTick;

		if (g_bIsFake[client])
		{
			iTargetTick = g_iTickCount - 1;
		}
		else
		{
			// Based on CLagCompensationManager::StartLagCompensation.
			float fCorrect = GetClientLatency(client, NetFlow_Outgoing);
			int iLerpTicks = TIME_TO_TICK(GetEntDataFloat(client, m_fLerpTime));

			fCorrect += TICK_TO_TIME(iLerpTicks);
			fCorrect = ClampValue(fCorrect, 0.0, g_fMaxUnlag);

			iTargetTick = g_iCmdTickCount[client] - iLerpTicks;

			if (FloatAbs(fCorrect - TICK_TO_TIME(g_iTickCount - iTargetTick)) > 0.2)
			{
				// Difference between cmd time and latency is too big > 200ms.
				// Use time correction based on latency.
				iTargetTick = g_iTickCount - TIME_TO_TICK(fCorrect);
			}
		}

		// Use velocity before it's modified.
		float vTemp[3];
		vTemp[0] = FloatAbs(vVelocity[0]) * 0.01;
		vTemp[1] = FloatAbs(vVelocity[1]) * 0.01;
		vTemp[2] = FloatAbs(vVelocity[2]) * 0.01;

		// Calculate predicted positions for the next frame.
		float vPredicted[3];
		ScaleVector(vVelocity, TICK_TO_TIME((g_iTickCount - iTargetTick) * g_iTotalThreads));
		AddVectors(g_vAbsCentre[client], vVelocity, vPredicted);

		// Make sure the predicted position is still inside the world.
		TR_TraceHullFilter(vPredicted, vPredicted, view_as<float>({-5.0, -5.0, -5.0}), view_as<float>({5.0, 5.0, 5.0}), MASK_PLAYERSOLID_BRUSHONLY, Filter_WorldOnly);
		g_iTraceCount++;

		if (!TR_DidHit())
		{
			g_vAbsCentre[client] = vPredicted;
			AddVectors(g_vEyePos[client], vVelocity, g_vEyePos[client]);
		}

		// Expand the mins/maxs to help smooth during fast movement.
		if (vTemp[0] > 1.0)
		{
			g_vMins[client][0] *= vTemp[0];
			g_vMaxs[client][0] *= vTemp[0];
		}
		if (vTemp[1] > 1.0)
		{
			g_vMins[client][1] *= vTemp[1];
			g_vMaxs[client][1] *= vTemp[1];
		}
		if (vTemp[2] > 1.0)
		{
			g_vMins[client][2] *= vTemp[2];
			g_vMaxs[client][2] *= vTemp[2];
		}
	}
}

/**
 * Calculations
 */
bool IsAbleToSee(int entity,int client)
{
	// Game specific checks.
	switch (g_Game)
	{
		case Engine_Left4Dead2:
		{
			if (L4D_IsPlayerGhost(entity))
			{
				return false;
			}
			if (L4D2_IsInfectedBusy(entity) || L4D2_IsSurvivorBusy(client))
			{
				return true;
			}
		}
		case Engine_Left4Dead:
		{
			if (L4D_IsPlayerGhost(entity))
			{
				return false;
			}
			if (L4D_IsInfectedBusy(entity) || L4D_IsSurvivorBusy(client))
			{
				return true;
			}
		}
	}

	// Skip all traces if the player isn't within the field of view.
	if (IsInFieldOfView(g_vEyePos[client], g_vEyeAngles[client], g_vAbsCentre[entity]))
	{
		// Check if centre is visible.
		if (IsPointVisible(g_vEyePos[client], g_vAbsCentre[entity]))
		{
			return true;
		}

		// Check if weapon tip is visible.
		if (IsFwdVecVisible(g_vEyePos[client], g_vEyeAngles[entity], g_vEyePos[entity]))
		{
			return true;
		}

		// Check outer 4 corners of player.
		if (IsRectangleVisible(g_vEyePos[client], g_vAbsCentre[entity], g_vMins[entity], g_vMaxs[entity], 1.30))
		{
			return true;
		}

		// Check inner 4 corners of player.
		if (IsRectangleVisible(g_vEyePos[client], g_vAbsCentre[entity], g_vMins[entity], g_vMaxs[entity], 0.65))
		{
			return true;
		}
	}

	return false;
}

bool IsInFieldOfView(const float start[3], const float angles[3], const float end[3])
{
	float normal[3], plane[3];

	GetAngleVectors(angles, normal, NULL_VECTOR, NULL_VECTOR);
	SubtractVectors(end, start, plane);
	NormalizeVector(plane, plane);

	return GetVectorDotProduct(plane, normal) > 0.0; // Cosine(Deg2Rad(179.9 / 2.0))
}

bool Filter_WorldOnly(int entity,int mask)
{
	return false;
}

bool Filter_NoPlayers(int entity,int mask)
{
	return entity > MaxClients && !IS_CLIENT(GetEntDataEnt2(entity, m_hOwnerEntity));
}

bool IsPointVisible(const float start[3], const float end[3])
{
	// TF2's team-specific barriers don't have a suitable workaround.
	if (g_Game == Engine_TF2)
	{
		TR_TraceRayFilter(start, end, MASK_VISIBLE, RayType_EndPoint, Filter_WorldOnly);
	}
	else
	{
		TR_TraceRayFilter(start, end, MASK_VISIBLE, RayType_EndPoint, Filter_NoPlayers);
	}

	g_iTraceCount++;

	return TR_GetFraction() == 1.0;
}

bool IsFwdVecVisible(const float start[3], const float angles[3], const float end[3])
{
	float fwd[3];

	GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fwd, 50.0);
	AddVectors(end, fwd, fwd);

	return IsPointVisible(start, fwd);
}

bool IsRectangleVisible(const float start[3], const float end[3], const float mins[3], const float maxs[3], float scale=1.0)
{
	float ZpozOffset = maxs[2];
	float ZnegOffset = mins[2];
	float WideOffset = ((maxs[0] - mins[0]) + (maxs[1] - mins[1])) / 4.0;

	// This rectangle is just a point!
	if (ZpozOffset == 0.0 && ZnegOffset == 0.0 && WideOffset == 0.0)
	{
		return IsPointVisible(start, end);
	}

	// Adjust to scale.
	ZpozOffset *= scale;
	ZnegOffset *= scale;
	WideOffset *= scale;

	// Prepare rotation matrix.
	float angles[3], fwd[3], right[3];

	SubtractVectors(start, end, fwd);
	NormalizeVector(fwd, fwd);

	GetVectorAngles(fwd, angles);
	GetAngleVectors(angles, fwd, right, NULL_VECTOR);

	float vRectangle[4][3], vTemp[3];

	// If the player is on the same level as us, we can optimize by only rotating on the z-axis.
	if (FloatAbs(fwd[2]) <= 0.7071)
	{
		ScaleVector(right, WideOffset);

		// Corner 1, 2
		vTemp = end;
		vTemp[2] += ZpozOffset;
		AddVectors(vTemp, right, vRectangle[0]);
		SubtractVectors(vTemp, right, vRectangle[1]);

		// Corner 3, 4
		vTemp = end;
		vTemp[2] += ZnegOffset;
		AddVectors(vTemp, right, vRectangle[2]);
		SubtractVectors(vTemp, right, vRectangle[3]);

	}
	else if (fwd[2] > 0.0) // Player is below us.
	{
		fwd[2] = 0.0;
		NormalizeVector(fwd, fwd);

		ScaleVector(fwd, scale);
		ScaleVector(fwd, WideOffset);
		ScaleVector(right, WideOffset);

		// Corner 1
		vTemp = end;
		vTemp[2] += ZpozOffset;
		AddVectors(vTemp, right, vTemp);
		SubtractVectors(vTemp, fwd, vRectangle[0]);

		// Corner 2
		vTemp = end;
		vTemp[2] += ZpozOffset;
		SubtractVectors(vTemp, right, vTemp);
		SubtractVectors(vTemp, fwd, vRectangle[1]);

		// Corner 3
		vTemp = end;
		vTemp[2] += ZnegOffset;
		AddVectors(vTemp, right, vTemp);
		AddVectors(vTemp, fwd, vRectangle[2]);

		// Corner 4
		vTemp = end;
		vTemp[2] += ZnegOffset;
		SubtractVectors(vTemp, right, vTemp);
		AddVectors(vTemp, fwd, vRectangle[3]);
	}
	else // Player is above us.
	{
		fwd[2] = 0.0;
		NormalizeVector(fwd, fwd);

		ScaleVector(fwd, scale);
		ScaleVector(fwd, WideOffset);
		ScaleVector(right, WideOffset);

		// Corner 1
		vTemp = end;
		vTemp[2] += ZpozOffset;
		AddVectors(vTemp, right, vTemp);
		AddVectors(vTemp, fwd, vRectangle[0]);

		// Corner 2
		vTemp = end;
		vTemp[2] += ZpozOffset;
		SubtractVectors(vTemp, right, vTemp);
		AddVectors(vTemp, fwd, vRectangle[1]);

		// Corner 3
		vTemp = end;
		vTemp[2] += ZnegOffset;
		AddVectors(vTemp, right, vTemp);
		SubtractVectors(vTemp, fwd, vRectangle[2]);

		// Corner 4
		vTemp = end;
		vTemp[2] += ZnegOffset;
		SubtractVectors(vTemp, right, vTemp);
		SubtractVectors(vTemp, fwd, vRectangle[3]);
	}

	// Run traces on all corners.
	for (int i = 0; i < 4; i++)
	{
		if (IsPointVisible(start, vRectangle[i]))
		{
			return true;
		}
	}

	return false;
}
#if defined ESP_BLOCKING
/**
 * CS:S FarESP Blocking
 */
#define CS_TEAM_NONE		0	/**< No team yet. */
#define CS_TEAM_SPECTATOR	1	/**< Spectators. */
#define CS_TEAM_T			2	/**< Terrorists. */
#define CS_TEAM_CT			3	/**< Counter-Terrorists. */

#define MAX_RADAR_CLIENTS   36	// Max amount of client data we can include in one message.

UserMsg g_msgUpdateRadar = INVALID_MESSAGE_ID;
bool g_bPlayerSpotted[MAXPLAYERS+1];

int g_iSpottedCache[MAXPLAYERS+1];
int g_iUpdateFrequency;

int g_iPlayerManager = -1;
int g_iPlayerSpotted = -1;

ConVar g_hCvarForceCamera;
bool g_bForceCamera;

void FarESP_Enable()
{
	if ((g_iPlayerManager = GetPlayerResourceEntity()) == -1)
	{
		return;
	}

	g_iPlayerSpotted = FindSendPropInfo("CCSPlayerResource", "m_bPlayerSpotted"); //FindSendPropOffs("CCSPlayerResource", "m_bPlayerSpotted");
	SDKHook(g_iPlayerManager, SDKHook_ThinkPost, PlayerManager_ThinkPost);

	g_msgUpdateRadar = GetUserMessageId("UpdateRadar");
	HookUserMessage(g_msgUpdateRadar, Hook_UpdateRadar, true);

	HookEvent("player_death", FarESP_PlayerDeath, EventHookMode_Pre);

	g_hCvarForceCamera = FindConVar("mp_forcecamera");
	OnForceCameraChanged(g_hCvarForceCamera, "", "");
	//HookConVarChange(g_hCvarForceCamera, OnForceCameraChanged);
	g_hCvarForceCamera.AddChangeHook(OnForceCameraChanged);

	g_iUpdateFrequency = TIME_TO_TICK(2.0);

	g_bFarEspEnabled = true;
}

void FarESP_Disable()
{
	SDKUnhook(g_iPlayerManager, SDKHook_ThinkPost, PlayerManager_ThinkPost);

	for (int i = 0; i < sizeof(g_bPlayerSpotted); i++)
	{
		g_bPlayerSpotted[i] = false;
	}

	UnhookUserMessage(g_msgUpdateRadar, Hook_UpdateRadar, true);
	UnhookEvent("player_death", FarESP_PlayerDeath, EventHookMode_Pre);

	//UnhookConVarChange(g_hCvarForceCamera, OnForceCameraChanged);
	g_hCvarForceCamera.RemoveChangeHook(OnForceCameraChanged);

	g_bFarEspEnabled = false;
}

Action FarESP_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IS_CLIENT(client) && IsClientInGame(client))
	{
		SendRadarClient(client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	}

	return Plugin_Continue;
}

void OnForceCameraChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	g_bForceCamera = convar.BoolValue;
}

public void OnMapEnd()
{
	if (g_bFarEspEnabled)
	{
		FarESP_Disable();
	}
}

Action Hook_UpdateRadar(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	// We will send custom messages only.
	return Plugin_Handled;
}

void PlayerManager_ThinkPost(int entity)
{
	if (!g_bFarEspEnabled)
	{
		return;
	}

	// Keep track of which players have been spotted.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bProcess[i] && GetEntData(entity, g_iPlayerSpotted + i, 1))
		{
			// Immediately update this client's data.
			if (!g_bPlayerSpotted[i])
			{
				g_bPlayerSpotted[i] = true;
				SendRadarClient(i, USERMSG_BLOCKHOOKS);
			}

			g_iSpottedCache[i] = g_iTickCount + g_iUpdateFrequency;
		}
		else
		{
			g_bPlayerSpotted[i] = false;
		}
	}
}

void FarESP_OnGameFrame()
{
	// Send the messages once per second and on different ticks.
	switch (g_iTickCount % g_iTickRate)
	{
		case 0:
		{
			SendRadarSpotted();
		}
		case 1:
		{
			SendRadarTeam(CS_TEAM_T);
		}
		case 2:
		{
			SendRadarTeam(CS_TEAM_CT);
		}
		case 3:
		{
			SendRadarObservers();
		}
		case 4:
		{
			SendRadarFakeTeam(CS_TEAM_T);
		}
		case 5:
		{
			SendRadarFakeTeam(CS_TEAM_CT);
		}
	}
}

void SendRadarSpotted()
{
	// Send scrambled spotted data to all clients.
	int[] iClients = new int[MaxClients];
	int numClients, count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bProcess[i])
		{
			iClients[numClients++] = i;
		}
	}

	if (!numClients)
	{
		return;
	}

	float vOrigin[3], vAngles[3];
	Handle bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

	for (int i = 1; i <= MaxClients && count < MAX_RADAR_CLIENTS; i++)
	{
		if (g_bPlayerSpotted[i] && g_bProcess[i])
		{
			GetClientAbsOrigin(i, vOrigin);
			GetClientAbsAngles(i, vAngles);

			BfWriteByte(bf, i);
			BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] - MT_GetRandomFloat(500.0, 1000.0)) / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
			count++;
		}
	}

	BfWriteByte(bf, 0);
	EndMessage();
}

void SendRadarTeam(int team)
{
	// Send proper team data to all teammates.
	int[] iClients = new int[view_as<int>(MaxClients)];
	int numClients;

	for (int i = 1; i <= MaxClients; i++)
	{
		// Include dead players observering their teammates.
		if ((g_bProcess[i] || (g_bForceCamera && g_bIsObserver[i])) && g_iTeam[i] == team)
		{
			iClients[numClients++] = i;
		}
	}

	if (!numClients)
	{
		return;
	}

	float vOrigin[3], vAngles[3];
	int client;
	Handle bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

	// Limit payload early.
	if (numClients >= MAX_RADAR_CLIENTS)
	{
		numClients = MAX_RADAR_CLIENTS - 1;
	}

	for (int i = 0; i < numClients; i++)
	{
		client = iClients[i];

		GetClientAbsOrigin(client, vOrigin);
		GetClientAbsAngles(client, vAngles);

		BfWriteByte(bf, client);
		BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest(vOrigin[2] / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
	}

	BfWriteByte(bf, 0);
	EndMessage();
}

void SendRadarFakeTeam(int team)
{
	// Send fake data to team.
	int[] iReceivers = new int[view_as<int>(MaxClients)];
	int[] iSenders = new int[view_as<int>(MaxClients)];
	int numReceivers, numSenders, iReceiver;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bProcess[i])
		{
			if (g_iTeam[i] == team)
			{
				iReceivers[numReceivers++] = i;
			}
			else if (g_iSpottedCache[i] < g_iTickCount)
			{
				iSenders[numSenders++] = i;
			}
		}
	}

	if (!numReceivers || !numSenders)
	{
		return;
	}

	float vOrigin[3];
	Handle bf = StartMessageEx(g_msgUpdateRadar, iReceivers, numReceivers, USERMSG_BLOCKHOOKS);

	// Randomize so that every client is ensured fake data.
	SortIntegers(iReceivers, numReceivers, Sort_Random);

	// Randomize the payload before limiting.
	if (numSenders >= MAX_RADAR_CLIENTS)
	{
		SortIntegers(iSenders, numSenders, Sort_Random);
		numSenders = MAX_RADAR_CLIENTS - 1;
	}

	for (int i = 0; i < numSenders; i++)
	{
		GetClientAbsOrigin(iReceivers[iReceiver++], vOrigin);

		BfWriteByte(bf, iSenders[i]);
		BfWriteSBitLong(bf, RoundToNearest((vOrigin[0] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest((vOrigin[1] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] + MT_GetRandomFloat(-1000.0, 1000.0)) / 4.0), 13);
		BfWriteSBitLong(bf, RoundToNearest(MT_GetRandomFloat(-180.0, 180.0)), 9);

		if (iReceiver >= numReceivers)
		{
			iReceiver = 0;
		}
	}

	BfWriteByte(bf, 0);
	EndMessage();
}

void SendRadarClient(int client,int flags)
{
	// A player was spotted and needs to be sent out to all clients.
	int[] iClients = new int[view_as<int>(MaxClients)];
	int numClients, iTeam = g_iTeam[client];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_bProcess[i] && g_iTeam[i] != iTeam)
		{
			iClients[numClients++] = i;
		}
	}

	if (!numClients)
	{
		return;
	}

	float vOrigin[3], vAngles[3];
	Handle bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, flags);

	GetClientAbsOrigin(client, vOrigin);
	GetClientAbsAngles(client, vAngles);

	BfWriteByte(bf, client);
	BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
	BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
	BfWriteSBitLong(bf, RoundToNearest((vOrigin[2] - MT_GetRandomFloat(500.0, 1000.0)) / 4.0), 13);
	BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);

	BfWriteByte(bf, 0);
	EndMessage();
}

void SendRadarObservers()
{
	// Send all player data to all observers.
	int[] iClients = new int[MaxClients];
	int numClients, count;

	for (int i = 1; i <= MaxClients; i++)
	{
		// Include teammate-observers if forcecamera is disabled.
		if (g_bIsObserver[i] && (!g_bForceCamera || g_iTeam[i] <= CS_TEAM_SPECTATOR))
		{
			iClients[numClients++] = i;
		}
	}

	if (!numClients)
	{
		return;
	}

	float vOrigin[3], vAngles[3];
	Handle bf = StartMessageEx(g_msgUpdateRadar, iClients, numClients, USERMSG_BLOCKHOOKS);

	for (int i = 1; i <= MaxClients && count < MAX_RADAR_CLIENTS; i++)
	{
		if (g_bProcess[i])
		{
			GetClientAbsOrigin(i, vOrigin);
			GetClientAbsAngles(i, vAngles);

			BfWriteByte(bf, i);
			BfWriteSBitLong(bf, RoundToNearest(vOrigin[0] / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest(vOrigin[1] / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest(vOrigin[2] / 4.0), 13);
			BfWriteSBitLong(bf, RoundToNearest(vAngles[1]), 9);
			count++;
		}
	}

	BfWriteByte(bf, 0);
	EndMessage();
}

float MT_GetRandomFloat(float min, float max)
{
	return GetURandomFloat() * (max - min) + min;
}

void BfWriteSBitLong(Handle bf,int data,int numBits)
{
	for (int i = 0; i < numBits; i++)
	{
		BfWriteBool(bf, !!(data & (1 << i)));
	}
}
#endif
/* Stocks */
bool L4D_IsPlayerGhost(int client)
{
	return view_as<bool>(GetEntData(client, m_isGhost, 1));
}

// "Busy" implies that the client is not in their typical first-person state.
bool L4D_IsSurvivorBusy(int client)
{
	return GetEntityFlags(client) & FL_FROZEN || 
		GetClientHudFlags(client) & ~HIDEHUD_BONUS_PROGRESS || 
		GetEntData(client, m_isIncapacitated) > 0 || 
		GetEntData(client, m_knockdownReason) > 0 || 
		GetEntDataFloat(client, m_staggerDist) > 0.0 || 
		GetEntDataEnt2(client, m_pounceAttacker) > 0 || 
		GetEntDataEnt2(client, m_tongueOwner) > 0;
}

bool L4D_IsInfectedBusy(int client)
{
	float gt = GetGameTime();
	return (GetEntDataFloat(client, m_vomitStart) + g_iVomitDurationPz + 0.1) > gt || 
		g_fAbilityStart[client] + 5.0 > gt || 
		GetEntDataEnt2(client, m_pounceVictim) > 0 || 
		GetEntDataEnt2(client, m_tongueVictim) > 0;
}

bool L4D2_IsSurvivorBusy(int client)
{
	return GetEntityFlags(client) & FL_FROZEN || 
		GetClientHudFlags(client) & ~HIDEHUD_BONUS_PROGRESS || 
		GetEntData(client, m_isIncapacitated) > 0 || 
		GetEntData(client, m_knockdownReason) > 0 || 
		GetEntDataFloat(client, m_staggerDist) > 0.0 || 
		GetEntDataEnt2(client, m_pummelAttacker) > 0 || 
		GetEntDataEnt2(client, m_carryAttacker) > 0 || 
		GetEntDataEnt2(client, m_pounceAttacker) > 0 || 
		GetEntDataEnt2(client, m_jockeyAttacker) > 0 || 
		GetEntDataEnt2(client, m_tongueOwner) > 0;
}

bool L4D2_IsInfectedBusy(int client)
{
	float gt = GetGameTime();
	return GetEntData(client, m_iGlowType) == 3 || 
		(GetEntDataFloat(client, m_vomitStart) + (IsFakeClient(client) ? g_iVomitDurationBot : g_iVomitDurationPz) + 0.1) > gt || 
		g_fAbilityStart[client] + 5.0 > gt || 
		GetEntDataEnt2(client, m_pummelVictim) > 0 || 
		GetEntDataEnt2(client, m_carryVictim) > 0 || 
		GetEntDataEnt2(client, m_pounceVictim) > 0 || 
		GetEntDataEnt2(client, m_jockeyVictim) > 0 || 
		GetEntDataEnt2(client, m_tongueVictim) > 0;
}

bool IsConVarDefault(ConVar convar)
{
	char sDefaultVal[16], sCurrentVal[16];
	GetConVarDefault(convar, sDefaultVal, sizeof(sDefaultVal));
	GetConVarString(convar, sCurrentVal, sizeof(sCurrentVal));

	return StrEqual(sDefaultVal, sCurrentVal);
}

bool IsVectorZero(const float vec[3])
{
	return vec[0] == 0.0 && vec[1] == 0.0 && vec[2] == 0.0;
}

int GetClientObserverMode(int client)
{
	static int offset = -1;

	if (offset == -1 && (offset = FindSendPropInfo("CBasePlayer", "m_iObserverMode")) == -1) //FindSendPropOffs("CBasePlayer", "m_iObserverMode")) == -1)
	{
		return OBS_MODE_NONE;
	}

	return GetEntData(client, offset);
}

int GetClientObserverTarget(int client)
{
	static int offset = -1;

	if (offset == -1 && (offset = FindSendPropInfo("CBasePlayer", "m_hObserverTarget")) == -1)
	{
		return -1;
	}

	return GetEntDataEnt2(client, offset);
}

int GetClientHudFlags(int client)
{
	return GetEntData(client, m_iHideHUD);
}

bool GetClientAbsVelocity(int client, float velocity[3])
{
	static int offset = -1;

	if (offset == -1 && (offset = FindDataMapInfo(client, "m_vecAbsVelocity")) == -1) // FindDataMapOffs(client, "m_vecAbsVelocity")) == -1)
	{
		ZeroVector(velocity);
		return false;
	}

	GetEntDataVector(client, offset, velocity);
	return true;
}

void ZeroVector(float vec[3])
{
	vec[0] = vec[1] = vec[2] = 0.0;
}

any MinValue(any value, any min)
{
	return (value < min) ? min : value;
}

any MaxValue(any value, any max)
{
	return (value > max) ? max : value;
}

any ClampValue(any value, any min, any max)
{
	value = MinValue(value, min);
	value = MaxValue(value, max);

	return value;
}