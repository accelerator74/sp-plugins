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

#pragma newdecls required

#define GAMEDATA "l4fix"
#define PLUGIN_VERSION	"1.0.8"

static int g_iWitchHarasser[2049];
static float g_fPreventDamage[33][33];
static float g_fLastMeleeSwing[33];
static float g_fNextAttack[33];

Address Collision_Address = Address_Null;

Address OnMoveToFailure_1 = Address_Null;
Address OnMoveToFailure_2 = Address_Null;
Address GetVictim = Address_Null;
Address OnStart = Address_Null;
Address OnAnimationEvent = Address_Null;
Address Update = Address_Null;

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_Left4Dead2)
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
	
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if(hGamedata == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
	
	g_iMaxFlames = GameConfGetOffset(hGamedata, "CInferno::m_maxFlames");
	if( g_iMaxFlames == -1 ) 
		SetFailState("Invalid offset for 'CInferno::m_maxFlames'.");
	
	Address patch = GameConfGetAddress(hGamedata, "CCharge::HandleCustomCollision");
	if(!patch) 
		SetFailState("Error finding the 'CCharge::HandleCustomCollision' signature.");
	
	int offset = GameConfGetOffset(hGamedata, "CCharge::HandleCustomCollision");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'CCharge::HandleCustomCollision'.");
	
	int byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x01)
	{
		Collision_Address = patch + view_as<Address>(offset);
		StoreToAddress(Collision_Address, 0x00, NumberType_Int8);
		PrintToServer("ChargerCollision patch applied 'CCharge::HandleCustomCollision'");
		
		Handle hConvar = FindConVar("z_charge_max_force");
		SetConVarFloat(hConvar, GetConVarFloat(hConvar) * 0.25);
		HookConVarChange(hConvar, ScaleDownCvar);
		
		hConvar = FindConVar("z_charge_min_force");
		SetConVarFloat(hConvar, GetConVarFloat(hConvar) * 0.25);
		HookConVarChange(hConvar, ScaleDownCvar);
		HookEvent("charger_impact", eChargerImpact, EventHookMode_Pre);
	}
	else
	{
		LogError("Incorrect offset for 'CCharge::HandleCustomCollision'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnMoveToFailure");
	if(!patch) 
		SetFailState("Error finding the 'WitchAttack::OnMoveToFailure' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnMoveToFailure_1");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::OnMoveToFailure_1'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x74 || byte == 0x75)
	{
		OnMoveToFailure_1 = patch + view_as<Address>(offset);
		MoveFailureBytesStore_1[0] = LoadFromAddress(OnMoveToFailure_1, NumberType_Int8);
		MoveFailureBytesStore_1[1] = LoadFromAddress(OnMoveToFailure_1 + view_as<Address>(1), NumberType_Int8);
		
		if(byte == 0x74)
		{
			StoreToAddress(OnMoveToFailure_1, 0x90, NumberType_Int8);
			StoreToAddress(OnMoveToFailure_1 + view_as<Address>(1), 0x90, NumberType_Int8);
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
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::OnMoveToFailure_2'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x74 || byte == 0x75)
	{
		OnMoveToFailure_2 = patch + view_as<Address>(offset);
		MoveFailureBytesStore_2[0] = LoadFromAddress(OnMoveToFailure_2, NumberType_Int8);
		MoveFailureBytesStore_2[1] = LoadFromAddress(OnMoveToFailure_2 + view_as<Address>(1), NumberType_Int8);
		
		StoreToAddress(OnMoveToFailure_2, 0x90, NumberType_Int8);
		StoreToAddress(OnMoveToFailure_2 + view_as<Address>(1), 0x90, NumberType_Int8);
		PrintToServer("WitchPatch Preventloss patch applied 'WitchAttack::OnMoveToFailure_2'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnMoveToFailure_2'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::GetVictim");
	if(!patch) 
		SetFailState("Error finding the 'WitchAttack::GetVictim' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::GetVictim");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::GetVictim'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x74)
	{
		GetVictim = patch + view_as<Address>(offset);
		
		GetVictimBytesStore[0] = LoadFromAddress(GetVictim, NumberType_Int8);
		GetVictimBytesStore[1] = LoadFromAddress(GetVictim + view_as<Address>(1), NumberType_Int8);
		
		StoreToAddress(GetVictim, 0xEB, NumberType_Int8);
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
		
		return;
	}
	if(byte == 0x75)
	{
		GetVictim = patch + view_as<Address>(offset);
		
		GetVictimBytesStore[0] = LoadFromAddress(GetVictim, NumberType_Int8);
		GetVictimBytesStore[1] = LoadFromAddress(GetVictim + view_as<Address>(1), NumberType_Int8);
		
		StoreToAddress(GetVictim, 0x90, NumberType_Int8);
		StoreToAddress(GetVictim + view_as<Address>(1), 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::GetVictim'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::GetVictim'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnStart");
	if(!patch) 
		SetFailState("Error finding the 'WitchAttack::OnStart' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnStart");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::OnStart'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x75)
	{
		OnStart = patch + view_as<Address>(offset);
		
		for(int i = 0; i <= 5; i++)
		{
			OnStartBytesStore[i] = LoadFromAddress(OnStart + view_as<Address>(i), NumberType_Int8);
		}
		
		StoreToAddress(OnStart, 0x90, NumberType_Int8);
		StoreToAddress(OnStart + view_as<Address>(1), 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnStart'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnStart'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::OnAnimationEvent");
	if(!patch) 
		SetFailState("Error finding the 'WitchAttack::OnAnimationEvent' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::OnAnimationEvent");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::OnAnimationEvent'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x75)
	{
		OnAnimationEvent = patch + view_as<Address>(offset);
		
		OnAnimationEventBytesStore[0] = LoadFromAddress(OnAnimationEvent, NumberType_Int8);
		OnAnimationEventBytesStore[1] = LoadFromAddress(OnAnimationEvent + view_as<Address>(1), NumberType_Int8);
		
		StoreToAddress(OnAnimationEvent, 0x90, NumberType_Int8);
		StoreToAddress(OnAnimationEvent + view_as<Address>(1), 0x90, NumberType_Int8);
		
		PrintToServer("WitchPatch Targeting patch applied 'WitchAttack::OnAnimationEvent'");
	}
	else
	{
		LogError("Incorrect offset for 'WitchAttack::OnAnimationEvent'.");
	}
	
	patch = GameConfGetAddress(hGamedata, "WitchAttack::Update");
	if(!patch) 
		SetFailState("Error finding the 'WitchAttack::Update' signature.");
	
	offset = GameConfGetOffset(hGamedata, "WitchAttack::Update");
	if( offset == -1 ) 
		SetFailState("Invalid offset for 'WitchAttack::Update'.");
	
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if(byte == 0x75)
	{
		Update = patch + view_as<Address>(offset);
		
		for(int i = 0; i <= 5; i++)
		{
			UpdateBytesStore[i] = LoadFromAddress(Update + view_as<Address>(i), NumberType_Int8);
		}
		
		StoreToAddress(Update, 0x90, NumberType_Int8);
		StoreToAddress(Update + view_as<Address>(1), 0x90, NumberType_Int8);
		
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

void ScaleDownCvar(ConVar hConvar, const char[] sOldValue, const char[] sNewValue)
{
	static bool bIgnore = false;
	if(bIgnore)
		return;
	
	bIgnore = true;
	SetConVarFloat(hConvar, GetConVarFloat(hConvar) * 0.25);
	bIgnore = false;
}

void eChargerImpact(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iVictim = GetClientOfUserId(hEvent.GetInt("victim"));
	if(iVictim < 1 || !IsClientInGame(iVictim) || !IsPlayerAlive(iVictim))
		return;

	int iCharger = GetClientOfUserId(hEvent.GetInt("userid"));
	if(iCharger < 1 || !IsClientInGame(iCharger) || !IsPlayerAlive(iCharger))
		return;
	
	g_fPreventDamage[iCharger][iVictim] = GetEngineTime() + 0.5;
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

void OnWeaponSwitched(int client, int weapon)
{
	if (!IsFakeClient(client))
	{
		char sBuffer[32];
		GetEntityClassname(weapon, sBuffer, sizeof(sBuffer));
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
			if(GetEntProp(iWitch, Prop_Data, "m_iHealth") > 0)
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
	Address pEntity;
	
	while ((iEntity = FindEntityByClassname(iEntity, "insect_swarm")) != -1) {
		pEntity = GetEntityAddress(iEntity);
		
		if (pEntity == Address_Null)
			continue;
		
		iMaxFlames = LoadFromAddress(pEntity + view_as<Address>(g_iMaxFlames), NumberType_Int32);
		iCurrentFlames = GetEntProp(iEntity, Prop_Send, "m_fireCount");
		
		if (iMaxFlames == 2 && iCurrentFlames == 2) {
			SetEntProp(iEntity, Prop_Send, "m_fireCount", 1);
			StoreToAddress(pEntity + view_as<Address>(g_iMaxFlames), 1, NumberType_Int32);
		}
	}

	return Plugin_Stop;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(sClassname[0] != 's' || !StrEqual(sClassname, "survivor_bot"))
	 	return;

	SDKHook(iEntity, SDKHook_OnTakeDamage, BlockRecursiveDamage);
}

public void OnClientPutInServer(int iClient)
{
	g_fLastMeleeSwing[iClient] = 0.0;	
	
	if(!IsFakeClient(iClient))
	{
		SDKHook(iClient, SDKHook_OnTakeDamage, BlockRecursiveDamage);
		SDKHook(iClient, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
	}
}

Action BlockRecursiveDamage(int iVictim, int &iCharger, int &iInflictor, float &fDamage, int &iDamagetype)
{
	if(GetClientTeam(iVictim) != 2)
		return Plugin_Continue;
	
	if(iCharger < 1 || iCharger > MaxClients || 
		GetClientTeam(iCharger) != 3 || !IsPlayerAlive(iCharger) || 
		GetEntProp(iCharger, Prop_Send, "m_zombieClass", 1) != 6 )
		return Plugin_Continue;
	
	int iAbility = GetEntPropEnt(iCharger, Prop_Send, "m_customAbility");
	if(iAbility <= MaxClients || !HasEntProp(iAbility, Prop_Send, "m_isCharging"))
		return Plugin_Continue;
	
	if(GetEntProp(iAbility, Prop_Send, "m_isCharging", 1))
	{
		if(GetEntPropEnt(iVictim, Prop_Send, "m_carryAttacker") == iCharger &&
			GetEntPropEnt(iCharger, Prop_Send, "m_carryVictim") == iVictim)
			return Plugin_Continue;
			
		if(g_fPreventDamage[iCharger][iVictim] > GetEngineTime())
			return Plugin_Handled;
			
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		if (GetEntData(client, g_iWaterLevel) == 3)
		{
			SetEntProp(client, Prop_Data, "m_idrownrestored", GetEntProp(client, Prop_Data, "m_idrowndmg"));
		}
		if (buttons & IN_ATTACK)
		{
			int iWeapon = GetEntDataEnt2(client, g_iActiveWeapon);
			
			if (iWeapon != -1)
			{
				char sBuffer[32];
				GetEntityClassname(iWeapon, sBuffer, sizeof(sBuffer));
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
	if(Collision_Address != Address_Null)
	{
		StoreToAddress(Collision_Address, 0x01, NumberType_Int8);
		PrintToServer("ChargerCollision patch restored 'CCharge::HandleCustomCollision'");
		
		Handle hConvar = FindConVar("z_charge_max_force");
		UnhookConVarChange(hConvar, ScaleDownCvar);
		SetConVarFloat(hConvar, GetConVarFloat(hConvar) / 0.25);
		
		hConvar = FindConVar("z_charge_min_force");
		UnhookConVarChange(hConvar, ScaleDownCvar);
		SetConVarFloat(hConvar, GetConVarFloat(hConvar) / 0.25);
		
		PrintToServer("ChargerCollision restored 'z_charge_max_force/z_charge_min_force' convars'");
	}
	
	if(OnMoveToFailure_1 != Address_Null)
	{
		StoreToAddress(OnMoveToFailure_1, MoveFailureBytesStore_1[0], NumberType_Int8);
		StoreToAddress(OnMoveToFailure_1 + view_as<Address>(1), MoveFailureBytesStore_1[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnMoveToFailure_1'");
	}
	if(OnMoveToFailure_2 != Address_Null)
	{
		StoreToAddress(OnMoveToFailure_2, MoveFailureBytesStore_2[0], NumberType_Int8);
		StoreToAddress(OnMoveToFailure_2 + view_as<Address>(1), MoveFailureBytesStore_2[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnMoveToFailure_2'");
	}
	
	if(GetVictim != Address_Null)
	{
		StoreToAddress(GetVictim, GetVictimBytesStore[0], NumberType_Int8);
		StoreToAddress(GetVictim + view_as<Address>(1), GetVictimBytesStore[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::GetVictim'");
	}
	
	if(OnStart != Address_Null)
	{
		for(int i = 0; i <= 5; i++)
		{
			StoreToAddress(OnStart + view_as<Address>(i), OnStartBytesStore[i], NumberType_Int8);
		}
		PrintToServer("WitchPatch restored 'WitchAttack::OnStart'");
	}
	
	if(OnAnimationEvent != Address_Null)
	{
		StoreToAddress(OnAnimationEvent, OnAnimationEventBytesStore[0], NumberType_Int8);
		StoreToAddress(OnAnimationEvent + view_as<Address>(1), OnAnimationEventBytesStore[1], NumberType_Int8);
		PrintToServer("WitchPatch restored 'WitchAttack::OnAnimationEvent'");
	}
	
	if(Update != Address_Null)
	{
		for(int i = 0; i <= 5; i++)
		{
			StoreToAddress(Update + view_as<Address>(i), UpdateBytesStore[i], NumberType_Int8);
		}
		PrintToServer("WitchPatch restored 'WitchAttack::Update'");
	}
}
