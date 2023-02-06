#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

ConVar hMeleeList;
Handle SDK_KV_SetString;

public Plugin myinfo =
{
	name = "[L4D2] Melee Unlock",
	author = "V10, Accelerator",
	description = "Unlocks melee weapons on every campaign.",
	version = "1.0",
	url = "https://github.com/accelerator74/sp-plugins"
}

public void OnPluginStart()
{
	hMeleeList = CreateConVar("l4d2_melee_weapons", "fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork", "Overrides map melee weapons list with this value, use ';' for delimiter.");
	
	Handle hGameData = LoadGameConfigFile("l4d2_meleeunlock");
	if(hGameData == null) 
		SetFailState("Failed to load \"l4d2_meleeunlock.txt\" gamedata.");
	
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString") == false )
		SetFailState("Could not load the \"KeyValues::SetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	SDK_KV_SetString = EndPrepSDKCall();
	if( SDK_KV_SetString == null )
		SetFailState("Could not prep the \"KeyValues::SetString\" function.");
	
	Handle hDetour;
	
	// Mission Info
	hDetour = DHookCreateFromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorGameRules::GetMissionInfo\" signature.");
	if( !DHookEnableDetour(hDetour, true, GetMissionInfo) )
		SetFailState("Failed to detour \"CTerrorGameRules::GetMissionInfo\".");
	delete hDetour;

	// Allow all Melee weapon types
	hDetour = DHookCreateFromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if( !hDetour )
		SetFailState("Failed to find \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\" signature.");
	if( !DHookEnableDetour(hDetour, true, MeleeWeaponAllowedToExist) )
		SetFailState("Failed to detour \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\".");
	delete hDetour;

	delete hGameData;
}

MRESReturn GetMissionInfo(Handle hReturn, Handle hParams)
{
	// Pointer
	int pThis = DHookGetReturn(hReturn);
	if( pThis == 0 ) return MRES_Ignored; // Some maps the mission file does not load (most likely due to gamemode not being supported).

	char value[512];
	hMeleeList.GetString(value, sizeof(value));
	SDKCall(SDK_KV_SetString, pThis, "meleeweapons", value);

	return MRES_Ignored;
}

MRESReturn MeleeWeaponAllowedToExist(Handle hReturn, Handle hParams)
{
	DHookSetReturn(hReturn, true);
	return MRES_Override;
}