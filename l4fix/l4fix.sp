/* 
*    Fixes for gamebreaking bugs and stupid gameplay aspects
*    Copyright (C) 2019  LuxLuma		acceliacat@gmail.com
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma newdecls required

#define GAMEDATA "l4fix"
#define PLUGIN_VERSION	"1.1.0"

int g_iWitchHarasser[2049];
float g_fLastMeleeSwing[33];
float g_fNextAttack[33];

Address Collision_Address = 0;

Address OnMoveToFailure_1 = 0;
Address OnMoveToFailure_2 = 0;
Address GetVictim = 0;
Address OnStart = 0;
Address OnAnimationEvent = 0;
Address Update = 0;

int MoveFailureBytesStore_1[2];
int MoveFailureBytesStore_2[2];
int GetVictimBytesStore[2];
int OnStartBytesStore[6];
int OnAnimationEventBytesStore[2];
int UpdateBytesStore[6];

int g_iWaterLevel = -1;
int g_iActiveWeapon = -1;
int g_iWitchSequence = -1;
int g_iMaxFlames = -1;

#define IMPACT_SND_INTERVAL 0.1

enum struct ChargerCharge
{
	float m_NextImpactSND;
	bool m_MarkHit[33];
	
	void Reset()
	{
		this.m_NextImpactSND = 0.0;
		for (int i = 1; i <= MaxClients; i++)
		{
			this.m_MarkHit[i] = false;
		}
	}
}

ChargerCharge g_ChargerCharge[33];
Handle g_hSetAbsVelocity;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public Plugin myinfo =
{
	name = "Left 4 Fix",
	author = "Lux, Accelerator",
	description = "Fixes for gamebreaking bugs and stupid stuff valve did for left 4 dead 2",
	version = PLUGIN_VERSION,
	url = "forums.alliedmods.net/showthread.php?p=2647017"
};


public void OnPluginStart()
{
	g_iWaterLevel = FindSendPropInfo("CBasePlayer", "m_nWaterLevel");
	g_iActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	g_iWitchSequence = FindSendPropInfo("Witch", "m_nSequence");
	
	HookEvent("weapon_fire", eWeaponFire);
	HookEvent("witch_spawn", eWitchSpawn);
	HookEvent("witch_harasser_set", eWitchHarasser);
	HookEvent("spitter_killed", eSpitterKilled, EventHookMode_PostNoCopy);
	HookEvent("round_start", eRoundStart, EventHookMode_PostNoCopy);
	HookEvent("charger_charge_start", eClearMarkedSurvivors, EventHookMode_Pre);
	HookEvent("charger_charge_end", eClearMarkedSurvivors, EventHookMode_Pre);
	AddNormalSoundHook(ImpactSNDHook);
	
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if (hGamedata == null)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	g_iMaxFlames = GameConfGetOffset(hGamedata, "CInferno::m_maxFlames");
	if (g_iMaxFlames == -1)
		SetFailState("Invalid offset for 'CInferno::m_maxFlames'.");
	
	Address patch = GameConfGetAddress(hGamedata, "CCharge::HandleCustomCollision");
	if (!patch)
		SetFailState("Error finding the 'CCharge::HandleCustomCollision' signature.");
	
	int offset = GameConfGetOffset(hGamedata, "CCharge::HandleCustomCollision");
	if (offset == -1)
		SetFailState("Invalid offset for 'CCharge::HandleCustomCollision'.");
	
	int byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x01)
	{
		Handle hDetour = DHookCreateFromConf(hGamedata, "ThrowImpactedSurvivor");
		if (!hDetour)
		{
			SetFailState("Failed to find 'ThrowImpactedSurvivor' signature");
		}
		
		StartPrepSDKCall(SDKCall_Entity);
		if (!PrepSDKCall_SetFromConf(hGamedata, SDKConf_Signature, "CBaseEntity::SetAbsVelocity"))
		{
			SetFailState("Error finding the 'CBaseEntity::SetAbsVelocity' signature.");
		}
		
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
		g_hSetAbsVelocity = EndPrepSDKCall();
		if (g_hSetAbsVelocity == null)
		{
			SetFailState("Unable to prep SDKCall 'CBaseEntity::SetAbsVelocity'");
		}
		
		if (!DHookEnableDetour(hDetour, false, ThrowImpactedSurvivor))
		{
			SetFailState("Failed to detour 'ThrowImpactedSurvivor'");
		}
		
		Collision_Address = patch + offset;
		StoreToAddress(Collision_Address, 0x00, NumberType_Int8);
		PrintToServer("ChargerCollision patch applied 'CCharge::HandleCustomCollision'");
		
		delete hDetour;
	}
	else
	{
		LogError("Incorrect offset for 'CCharge::HandleCustomCollision'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnMoveToFailure");
	if (!patch)
		SetFailState("Error finding the 'WitchAttack::OnMoveToFailure' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnMoveToFailure_1");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::OnMoveToFailure_1'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x74 || byte == 0x75)
	{
		OnMoveToFailure_1 = patch + offset;
		MoveFailureBytesStore_1[0] = LoadFromAddress(OnMoveToFailure_1, NumberType_Int8);
		MoveFailureBytesStore_1[1] = LoadFromAddress(OnMoveToFailure_1 + 1, NumberType_Int8);
		
		if (byte == 0x74)
		{
			StoreToAddress(OnMoveToFailure_1, 0x90, NumberType_Int8);
			StoreToAddress(OnMoveToFailure_1 + 1, 0x90, NumberType_Int8);
		}
		else
		{
			StoreToAddress(OnMoveToFailure_1, 0xEB, NumberType_Int8);
		}
		PrintToServer("WitchPatch Preventloss patch applied 'WitchAttack::OnMoveToFailure_1'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnMoveToFailure_1'.");
	}
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnMoveToFailure_2");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::OnMoveToFailure_2'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x74 || byte == 0x75)
	{
		OnMoveToFailure_2 = patch + offset;
		MoveFailureBytesStore_2[0] = LoadFromAddress(OnMoveToFailure_2, NumberType_Int8);
		MoveFailureBytesStore_2[1] = LoadFromAddress(OnMoveToFailure_2 + 1, NumberType_Int8);
		
		StoreToAddress(OnMoveToFailure_2, 0x90, NumberType_Int8);
		StoreToAddress(OnMoveToFailure_2 + 1, 0x90, NumberType_Int8);
		PrintToServer("WitchPatch Preventloss patch applied 'WitchAttack::OnMoveToFailure_2'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnMoveToFailure_2'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::GetVictim");
	if (!patch)
		SetFailState("Error finding the 'WitchAttack::GetVictim' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::GetVictim");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::GetVictim'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x74)
	{
		GetVictim = patch + offset;
		
		GetVictimBytesStore[0] = LoadFromAddress(GetVictim, NumberType_Int8);
		GetVictimBytesStore[1] = LoadFromAddress(GetVictim + 1, NumberType_Int8);
		
		StoreToAddress(GetVictim, 0xEB, NumberType_Int8);
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
		
		return;
	}
	if (byte == 0x75)
	{
		GetVictim = patch + offset;
		
		GetVictimBytesStore[0] = LoadFromAddress(GetVictim, NumberType_Int8);
		GetVictimBytesStore[1] = LoadFromAddress(GetVictim + 1, NumberType_Int8);
		
		StoreToAddress(GetVictim, 0x90, NumberType_Int8);
		StoreToAddress(GetVictim + 1, 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::GetVictim'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnStart");
	if (!patch)
		SetFailState("Error finding the 'WitchAttack::OnStart' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnStart");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::OnStart'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x75)
	{
		OnStart = patch + offset;
		
		for (int i = 0; i <= 5; i++)
		{
			OnStartBytesStore[i] = LoadFromAddress(OnStart + i, NumberType_Int8);
		}
		
		StoreToAddress(OnStart, 0x90, NumberType_Int8);
		StoreToAddress(OnStart + 1, 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnStart'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnStart'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnAnimationEvent");
	if (!patch)
		SetFailState("Error finding the 'WitchAttack::OnAnimationEvent' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnAnimationEvent");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::OnAnimationEvent'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x75)
	{
		OnAnimationEvent = patch + offset;
		
		OnAnimationEventBytesStore[0] = LoadFromAddress(OnAnimationEvent, NumberType_Int8);
		OnAnimationEventBytesStore[1] = LoadFromAddress(OnAnimationEvent + 1, NumberType_Int8);
		
		StoreToAddress(OnAnimationEvent, 0x90, NumberType_Int8);
		StoreToAddress(OnAnimationEvent + 1, 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnAnimationEvent'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnAnimationEvent'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::Update");
	if (!patch)
		SetFailState("Error finding the 'WitchAttack::Update' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::Update");
	if (offset == -1)
		SetFailState("Invalid offset for 'WitchAttack::Update'.");
	
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if (byte == 0x75)
	{
		Update = patch + offset;
		
		for (int i = 0; i <= 5; i++)
		{
			UpdateBytesStore[i] = LoadFromAddress(Update + i, NumberType_Int8);
		}
		
		StoreToAddress(Update, 0x90, NumberType_Int8);
		StoreToAddress(Update + 1, 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::Update'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::Update'.");
	}
	
	delete hGamedata;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

void eWeaponFire(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client && !IsFakeClient(client))
	{
		char sBuffer[16];
		hEvent.GetString("weapon", sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "melee"))
		{
			g_fLastMeleeSwing[client] = GetGameTime();
		}
	}
}

void eWitchSpawn(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int witch = hEvent.GetInt("witchid");
	SDKHook(witch, SDKHook_Think, OnWitchThink);
	SDKHook(witch, SDKHook_OnTakeDamage, OnWitchDamage);
}

void eWitchHarasser(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if (client)
	{
		g_iWitchHarasser[hEvent.GetInt("witchid")] = client;
	}
}

void eSpitterKilled(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	CreateTimer(1.0, FindDeathSpit, _, TIMER_FLAG_NO_MAPCHANGE);
}

void eRoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_ChargerCharge[i].Reset();
	}
}

void eClearMarkedSurvivors(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iCharger = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!iCharger)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_ChargerCharge[iCharger].m_MarkHit[i] = false;
	}
}

void OnSpawnPost(int client)
{
	g_ChargerCharge[client].Reset();
	for (int i = 1; i <= MaxClients; i++)
	{
		g_ChargerCharge[i].m_MarkHit[client] = false;
	}
}

void OnWeaponSwitched(int client, int weapon)
{
	if (!IsFakeClient(client))
	{
		char sBuffer[32];
		GetEdictClassname(weapon, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "weapon_melee"))
		{
			float fShouldbeNextAttack = g_fLastMeleeSwing[client] + 1.25;
			float fByServerNextAttack = GetGameTime() + 0.55;
			g_fNextAttack[client] = fShouldbeNextAttack > fByServerNextAttack ? fShouldbeNextAttack : fByServerNextAttack;
		}
	}
}

void OnWitchThink(int iWitch)
{
	switch(GetEntData(iWitch, g_iWitchSequence))
	{
		case 4:
		{
			SDKUnhook(iWitch, SDKHook_Think, OnWitchThink);
		}
		case 30:
		{
			if (GetEntProp(iWitch, Prop_Data, "m_iHealth") > 0)
			{
				SetEntPropFloat(iWitch, Prop_Send, "m_flCycle", 1.0);
			}
		}
	}
}

Action OnWitchDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (weapon == -1 || attacker < 1 || attacker > MaxClients || g_iWitchHarasser[victim] != attacker)
		return Plugin_Continue;
	
	char sWeapon[32];
	GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
	
	if (StrEqual(sWeapon, "weapon_melee"))
	{
		float survPos[3], witchPos[3], fFinalPos[3], fFinalAng[3];
		GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", survPos);
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", witchPos);
		MakeVectorFromPoints(witchPos, survPos, fFinalPos);
		GetVectorAngles(fFinalPos, fFinalAng);
		fFinalAng[0] = 0.0;
		SetEntPropVector(victim, Prop_Send, "m_angRotation", fFinalAng);
	}
	
	return Plugin_Continue;
}

Action FindDeathSpit(Handle hTimer)
{
	int iEntity = -1, iMaxFlames = 0, iCurrentFlames = 0;
	Address pEntity = Address_Null;
	
	while ((iEntity = FindEntityByClassname(iEntity, "insect_swarm")) != -1) {
		pEntity = GetEntityAddress(iEntity);
		
		if (pEntity == Address_Null)
			continue;
		
		iMaxFlames = LoadFromAddress(pEntity + g_iMaxFlames, NumberType_Int32);
		iCurrentFlames = GetEntProp(iEntity, Prop_Send, "m_fireCount");
		
		if (iMaxFlames == 2 && iCurrentFlames == 2) {
			SetEntProp(iEntity, Prop_Send, "m_fireCount", 1);
			StoreToAddress(pEntity + g_iMaxFlames, 1, NumberType_Int32);
		}
	}

	return Plugin_Stop;
}

Action ImpactSNDHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &iCharger, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (iCharger < 1 || iCharger > MaxClients || !IsClientInGame(iCharger) ||
		GetClientTeam(iCharger) != 3 || !IsPlayerAlive(iCharger))
	{
		return Plugin_Continue;
	}
	
	int iAbility = GetEntPropEnt(iCharger, Prop_Send, "m_customAbility");
	if (iAbility == -1 || !HasEntProp(iAbility, Prop_Send, "m_isCharging"))
	{
		return Plugin_Continue;
	}
	
	if (!GetEntProp(iAbility, Prop_Send, "m_isCharging", 1))
		return Plugin_Continue;
	
	if (g_ChargerCharge[iCharger].m_NextImpactSND > GetGameTime())
	{
		if (StrContains(sample, "player/charger/hit/charger_smash_0", false) != -1)
			return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

MRESReturn ThrowImpactedSurvivor(Handle hReturn, Handle hParams)
{
	int iCharger = DHookGetParam(hParams, 1);
	int iVictim = DHookGetParam(hParams, 2);
	bool ShouldDamage = DHookGetParam(hParams, 4);
	
	if (!ShouldDamage)
		return MRES_Ignored;
	
	if (iCharger < 1 || iCharger > MaxClients || GetClientTeam(iCharger) != 3 || !IsPlayerAlive(iCharger))
	{
		return MRES_Ignored;
	}
	
	int iAbility = GetEntPropEnt(iCharger, Prop_Send, "m_customAbility");
	if (iAbility == -1 || !HasEntProp(iAbility, Prop_Send, "m_isCharging"))
	{
		return MRES_Ignored;
	}
	
	if (!GetEntProp(iAbility, Prop_Send, "m_isCharging", 1))
		return MRES_Ignored;
	
	int iCarryVictim = GetEntPropEnt(iCharger, Prop_Send, "m_carryVictim");
	if (iCarryVictim == -1)
	{
		DHookSetReturn(hReturn, 1);
		return MRES_Supercede;
	}
	
	if (iCarryVictim == iVictim)
	{
		g_ChargerCharge[iCharger].m_NextImpactSND = GetGameTime() + IMPACT_SND_INTERVAL;
		DHookSetReturn(hReturn, 1);
		return MRES_Supercede;
	}
	
	//Set velocity to 0 so impulse velocity does not account for current velocity
	static float vecNoVel[3] = {0.0, 0.0, 0.0};
	SDKCall(g_hSetAbsVelocity, iVictim, vecNoVel);
	
	g_ChargerCharge[iCharger].m_NextImpactSND = GetGameTime() + IMPACT_SND_INTERVAL;
	if (g_ChargerCharge[iCharger].m_MarkHit[iVictim])
	{
		DHookSetParam(hParams, 4, false);
		DHookSetReturn(hReturn, 1);
		return MRES_ChangedHandled;
	}
	
	g_ChargerCharge[iCharger].m_MarkHit[iVictim] = true;
	return MRES_Ignored;
}

public void OnClientPutInServer(int iClient)
{
	g_fLastMeleeSwing[iClient] = 0.0;	
	
	SDKHook(iClient, SDKHook_SpawnPost, OnSpawnPost);
	
	if (!IsFakeClient(iClient))
	{
		SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		if (GetEntData(client, g_iWaterLevel, 1) == 3)
		{
			SetEntProp(client, Prop_Data, "m_idrownrestored", GetEntProp(client, Prop_Data, "m_idrowndmg"));
		}
		if (buttons & IN_ATTACK)
		{
			int iWeapon = GetEntDataEnt2(client, g_iActiveWeapon);
			
			if (iWeapon != -1)
			{
				char sBuffer[32];
				GetEdictClassname(iWeapon, sBuffer, sizeof(sBuffer));
				if (StrEqual(sBuffer, "weapon_melee"))
				{
					if (g_fNextAttack[client] - GetGameTime() > 0.0)
						buttons &= ~IN_ATTACK;
				}
			}
		}
	}
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	if (Collision_Address != 0)
	{
		StoreToAddress(Collision_Address, 0x01, NumberType_Int8);
		PrintToServer("ChargerCollision patch restored 'CCharge::HandleCustomCollision'");
	}
	
	if (OnMoveToFailure_1 != 0)
	{
		StoreToAddress(OnMoveToFailure_1, MoveFailureBytesStore_1[0], NumberType_Int8);
		StoreToAddress(OnMoveToFailure_1 + 1, MoveFailureBytesStore_1[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnMoveToFailure_1'");
	}
	if (OnMoveToFailure_2 != 0)
	{
		StoreToAddress(OnMoveToFailure_2, MoveFailureBytesStore_2[0], NumberType_Int8);
		StoreToAddress(OnMoveToFailure_2 + 1, MoveFailureBytesStore_2[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnMoveToFailure_2'");
	}
	
	if (GetVictim != 0)
	{
		StoreToAddress(GetVictim, GetVictimBytesStore[0], NumberType_Int8);
		StoreToAddress(GetVictim + 1, GetVictimBytesStore[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::GetVictim'");
	}
	
	if (OnStart != 0)
	{
		for (int i = 0; i <= 5; i++)
		{
			StoreToAddress(OnStart + i, OnStartBytesStore[i], NumberType_Int8);
		}
		PrintToServer("WitchPatch restored 'WitchAttack::OnStart'");
	}
	
	if (OnAnimationEvent != 0)
	{
		StoreToAddress(OnAnimationEvent, OnAnimationEventBytesStore[0], NumberType_Int8);
		StoreToAddress(OnAnimationEvent + 1, OnAnimationEventBytesStore[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnAnimationEvent'");
	}
	
	if (Update != 0)
	{
		for (int i = 0; i <= 5; i++)
		{
			StoreToAddress(Update + i, UpdateBytesStore[i], NumberType_Int8);
		}
		PrintToServer("WitchPatch restored 'WitchAttack::Update'");
	}
}