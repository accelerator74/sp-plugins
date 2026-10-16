#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

public void OnPluginStart()
{
	Handle hGameConf = LoadGameConfigFile("srcds_crash_fix");
	if( hGameConf == null ) SetFailState("Failed to load gamedata/srcds_crash_fix.");
/*
	Handle hDetour = DHookCreateFromConf(hGameConf, "CSoundPatch::ChangePitch");
	if( !hDetour )
		SetFailState("Failed to find \"CSoundPatch::ChangePitch\" signature.");
	if( !DHookEnableDetour(hDetour, false, ChangePitch) )
		SetFailState("Failed to detour \"CSoundPatch::ChangePitch\".");
	delete hDetour;
*/
	Handle hDetour = DHookCreateFromConf(hGameConf, "CSoundControllerImp::SoundChangePitch");
	if( !hDetour )
		SetFailState("Failed to find \"CSoundControllerImp::SoundChangePitch\" signature.");
	if( !DHookEnableDetour(hDetour, false, SoundChangePitch) )
		SetFailState("Failed to detour \"CSoundControllerImp::SoundChangePitch\".");
	delete hDetour;

	int offset = GameConfGetOffset(hGameConf, "LagCompensationOffset");
	Address patch = GameConfGetAddress(hGameConf, "StartLagCompensation");
	if( !patch ) SetFailState("Error finding the 'StartLagCompensation' signature.");
	int byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if( byte == 0x0F )
	{
		StoreToAddress(patch + offset, 0x74, NumberType_Int8);
		StoreToAddress(patch + offset + 1, 0xA4, NumberType_Int8);
		StoreToAddress(patch + offset + 2, 0x90, NumberType_Int8);
		StoreToAddress(patch + offset + 3, 0x90, NumberType_Int8);
		StoreToAddress(patch + offset + 4, 0x90, NumberType_Int8);
		StoreToAddress(patch + offset + 5, 0x90, NumberType_Int8);
	}
	else
	{
		LogError("Failed to patch \"CLagCompensationManager::StartLagCompensation\" function.");
	}

	// Ladder crash fix (by Silvers)
	offset = GameConfGetOffset(hGameConf, "Patch_ChaseVictim");
	patch = GameConfGetAddress(hGameConf, "ChaseVictim::Update");
	if( !patch ) SetFailState("Error finding the 'ChaseVictim::Update' signature.");
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + offset + i, 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the \"Patch_ChaseVictim\" offset %d is incorrect.", offset);
	}
	offset = GameConfGetOffset(hGameConf, "Patch_InfectedFlee");
	patch = GameConfGetAddress(hGameConf, "InfectedFlee::Update");
	if( !patch ) SetFailState("Error finding the 'InfectedFlee::Update' signature.");
	byte = LoadFromAddress(patch + offset, NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + offset + i, 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the \"Patch_InfectedFlee\" offset %d is incorrect.", offset);
	}

	delete hGameConf;

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}

// CChainsaw::ItemPostFrame() crash fix
/*
public MRESReturn ChangePitch(int pThis, Handle hReturn, Handle hParams)
{
	if(!pThis)
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
*/
MRESReturn SoundChangePitch(Handle hReturn, Handle hParams)
{
	int SoundPatch = DHookGetParam(hParams, 1);
	if(!SoundPatch)
	{
		DHookSetReturn(hReturn, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

// AwardTemplate crash fix
Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int target = GetClientOfUserId(event.GetInt("userid"));
	
	if (target >= 32 && GetEntProp(target, Prop_Send, "m_iTeamNum") == 2)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (client >= 32 && !IsFakeClient(client))
	{
		strcopy(rejectmsg, maxlen, "Server is full");
		return false;
	}
	return true;
}
