#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "[L4D2] Model Select",
	author = "Accelerator",
	description = "Select model Player",
	version = "1.5",
	url = "https://github.com/accelerator74/sp-plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_rochelle", Command_model);
	RegConsoleCmd("sm_coach", Command_model);
	RegConsoleCmd("sm_nick", Command_model);
	RegConsoleCmd("sm_ellis", Command_model);
	RegConsoleCmd("sm_zoey", Command_model);
	RegConsoleCmd("sm_francis", Command_model);
	RegConsoleCmd("sm_louis", Command_model);
	RegConsoleCmd("sm_bill", Command_model);
}

public void OnMapStart()
{
	CheckPrecacheModel("models/survivors/survivor_gambler.mdl");
	CheckPrecacheModel("models/survivors/survivor_manager.mdl");
	CheckPrecacheModel("models/survivors/survivor_coach.mdl");
	CheckPrecacheModel("models/survivors/survivor_producer.mdl");
	CheckPrecacheModel("models/survivors/survivor_teenangst.mdl");
	CheckPrecacheModel("models/survivors/survivor_biker.mdl");
	CheckPrecacheModel("models/survivors/survivor_namvet.mdl");
	CheckPrecacheModel("models/survivors/survivor_mechanic.mdl");
}

public Action Command_model(int client, int args)
{
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;

	char model[16];
	GetCmdArg(0, model, sizeof(model));
	
	ReplaceString(model, sizeof(model), "sm_", "", false);

	if (GetClientTeam(client) == 2)
	{
		if (L4D_Survivors(client) == 2)
		{
			if (StrEqual(model, "nick"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 0);
				SetEntityModel(client, "models/survivors/survivor_gambler.mdl");
			}
			else if (StrEqual(model, "rochelle"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 1);
				SetEntityModel(client, "models/survivors/survivor_producer.mdl");
			}
			else if (StrEqual(model, "coach"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 2);
				SetEntityModel(client, "models/survivors/survivor_coach.mdl");
			}
			else if (StrEqual(model, "ellis"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 3);
				SetEntityModel(client, "models/survivors/survivor_mechanic.mdl");
			}
			else
			{
				PrintToChat(client, "\x05Changing the skin \x04%s\x05 on this map disabled", model);
				return Plugin_Continue;
			}
		}
		else if (L4D_Survivors(client) == 1)
		{
			if (StrEqual(model, "bill"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 0);
				SetEntityModel(client, "models/survivors/survivor_namvet.mdl");
			}
			else if (StrEqual(model, "zoey"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 1);
				SetEntityModel(client, "models/survivors/survivor_teenangst.mdl");
			}
			else if (StrEqual(model, "louis"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 2);
				SetEntityModel(client, "models/survivors/survivor_manager.mdl");
			}
			else if (StrEqual(model, "francis"))
			{
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 3);
				SetEntityModel(client, "models/survivors/survivor_biker.mdl");
			}
			else
			{
				PrintToChat(client, "\x05Changing the skin \x04%s\x05 on this map disabled", model);
				return Plugin_Continue;
			}
		}
		else
		{
			PrintToChat(client, "\x05Changing the skin \x04%s\x05 on this map disabled", model);
			return Plugin_Continue;
		}
		
		PrintToChat(client, "\x05Current skin is replaced by the skin \x04%s", model);
	}
	return Plugin_Continue;
}

int L4D_Survivors(int client)
{
	char model[128];
	GetClientModel(client, model, sizeof(model));
	
	if ((StrContains(model, "survivor_namvet.mdl") != -1) || (StrContains(model, "survivor_teenangst.mdl") != -1) || (StrContains(model, "survivor_manager.mdl") != -1) || (StrContains(model, "survivor_biker.mdl") != -1)) 
		return 1;
		
	if ((StrContains(model, "survivor_gambler.mdl") != -1) || (StrContains(model, "survivor_producer.mdl") != -1) || (StrContains(model, "survivor_coach.mdl") != -1) || (StrContains(model, "survivor_mechanic.mdl") != -1))
		return 2;
	
	return 0;
}

public void CheckPrecacheModel(char[] Model)
{
	if (!IsModelPrecached(Model)) 
	{
		PrecacheModel(Model);
	}
}