#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

public void OnPluginStart()
{
	GameData hGameConf = new GameData("srcds_crash_fix");
	if( hGameConf == null ) SetFailState("Failed to load gamedata/srcds_crash_fix.");

	Handle hDetour = DHookCreateFromConf(hGameConf, "CSoundControllerImp::SoundChangePitch");
	if( !hDetour )
		SetFailState("Failed to find \"CSoundControllerImp::SoundChangePitch\" signature.");
	if( !DHookEnableDetour(hDetour, false, SoundChangePitch) )
		SetFailState("Failed to detour \"CSoundControllerImp::SoundChangePitch\".");
	delete hDetour;

	int offset = hGameConf.GetOffset("LagCompensationOffset");
	Address patch = hGameConf.GetAddress("StartLagCompensation");
	if( !patch ) SetFailState("Error finding the 'StartLagCompensation' signature.");
	int byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if( byte == 0x0F )
	{
		StoreToAddress(patch + view_as<Address>(offset), 0x74, NumberType_Int8);
		StoreToAddress(patch + view_as<Address>(offset + 1), 0xA4, NumberType_Int8);
		StoreToAddress(patch + view_as<Address>(offset + 2), 0x90, NumberType_Int8);
		StoreToAddress(patch + view_as<Address>(offset + 3), 0x90, NumberType_Int8);
		StoreToAddress(patch + view_as<Address>(offset + 4), 0x90, NumberType_Int8);
		StoreToAddress(patch + view_as<Address>(offset + 5), 0x90, NumberType_Int8);
	}
	else
	{
		LogError("Failed to patch \"CLagCompensationManager::StartLagCompensation\" function.");
	}

	// Ladder crash fix (by Silvers)
	offset = hGameConf.GetOffset("Patch_ChaseVictim");
	patch = hGameConf.GetAddress("ChaseVictim::Update");
	if( !patch ) SetFailState("Error finding the 'ChaseVictim::Update' signature.");
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + view_as<Address>(offset + i), 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the \"Patch_ChaseVictim\" offset %d is incorrect.", offset);
	}
	offset = hGameConf.GetOffset("Patch_InfectedFlee");
	patch = hGameConf.GetAddress("InfectedFlee::Update");
	if( !patch ) SetFailState("Error finding the 'InfectedFlee::Update' signature.");
	byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + view_as<Address>(offset + i), 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the \"Patch_InfectedFlee\" offset %d is incorrect.", offset);
	}

	delete hGameConf;

	HookEvent("round_start_pre_entity", Event_round_start_pre_entity, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}

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

public void OnClientDisconnect(int client)
{
    if (client > 0 && IsClientInGame(client))
	{
		int viewEntity = GetEntPropEnt(client, Prop_Send, "m_hViewEntity");
		if (IsValidEdict(viewEntity))
		{
			char cls[64];
			GetEdictClassname(viewEntity, cls, sizeof(cls));
			if (strncmp(cls, "point_viewcontrol", 17) == 0)
			{
				// Matches CSurvivorCamera, CTriggerCamera
				if (strcmp(cls[17], "_survivor") == 0 || cls[17] == '\0')
				{
					AcceptEntityInput(viewEntity, "Disable");
				}

				// Matches CTriggerCameraMultiplayer
				if (strcmp(cls[17], "_multiplayer") == 0)
				{
					AcceptEntityInput(viewEntity, "RemovePlayer", client);
				}
			}
		}
	}
}

stock void Event_round_start_pre_entity(Event event, const char[] name, bool dontBroadcast)
{
    int entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, "point_viewcontrol*")) != INVALID_ENT_REFERENCE)
	{
        AcceptEntityInput(entity, "Disable");
    }
}

stock Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int target = GetClientOfUserId(event.GetInt("userid"));
	if (target >= 32 && GetEntProp(target, Prop_Send, "m_iTeamNum") == 2)
	{
		return Plugin_Handled;
	}
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
